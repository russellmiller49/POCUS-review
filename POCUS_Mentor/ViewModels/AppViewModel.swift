import Foundation
import Combine
import Supabase

@MainActor
final class AppViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case login
        case signup
        case codeEntry(email: String)
        case reviewerLogin
        case selectingInstitution
        case selectingRole(InstitutionRoleGroup)
        case dashboard
        case pendingApproval
    }

    enum StudyFilter: Hashable, CaseIterable {
        case drafts        // Fellow-owned drafts
        case queue         // Waiting for attending review
        case returned      // Needs revision / not accepted
        case completed     // Approved or signed off
        case all

        var title: String {
            switch self {
            case .drafts: return "Drafts"
            case .queue: return "Submitted"
            case .returned: return "Returned"
            case .completed: return "Completed"
            case .all: return "All"
            }
        }
    }

    struct BannerMessage: Identifiable {
        let id = UUID()
        let text: String
    }

    struct ActiveSession {
        let profile: SupabaseUserProfile
        let session: Session
        let membership: MembershipWithInstitution

        var role: MembershipRole { membership.membership.membershipRole }

        var institutionName: String { membership.institution.name }
    }

struct StudyDetailState: Identifiable {
        var id: UUID { study.id }
        var study: Study
        var metadata: StudyMetadata
        var media: [Media]
        var feedback: [Feedback]
        var signoff: Signoff?

        var isSubmitted: Bool {
            switch study.status {
            case .draft:
                return false
            default:
                return true
            }
        }
}

struct InstitutionRoleGroup: Identifiable, Equatable {
        let institution: Institution
        let memberships: [MembershipWithInstitution]

        var id: UUID { institution.id }
        static func == (lhs: InstitutionRoleGroup, rhs: InstitutionRoleGroup) -> Bool {
            lhs.institution.id == rhs.institution.id && lhs.memberships.map(\.id).sorted() == rhs.memberships.map(\.id).sorted()
        }
    }

    struct PortfolioStats {
        struct ExamStat: Identifiable {
            let examType: String
            let count: Int
            var id: String { examType }
        }

        let totalCases: Int
        let drafts: Int
        let submitted: Int
        let returned: Int
        let completed: Int
        let acceptanceRate: Double
        let examBreakdown: [ExamStat]
    }

    struct PortfolioSummary {
        let totalAccepted: Int
        let totalRequired: Int
        let perModule: [PortfolioProgress]

        var overallProgress: Double {
            guard totalRequired > 0 else { return 0 }
            return min(Double(totalAccepted) / Double(totalRequired), 1.0)
        }
    }

    struct ProgramAnalytics {
        struct ExamStat: Identifiable {
            let examType: String
            let count: Int
            var id: String { examType }
        }

        struct FellowSummary: Identifiable {
            let id: UUID
            let name: String
            let email: String
            let drafts: Int
            let submitted: Int
            let returned: Int
            let completed: Int

            var totalCases: Int { drafts + submitted + returned + completed }
        }

        let totalCases: Int
        let drafts: Int
        let submitted: Int
        let returned: Int
        let completed: Int
        let acceptanceRate: Double
        let examBreakdown: [ExamStat]
        let fellowSummaries: [FellowSummary]
    }

    @Published private(set) var phase: Phase = .loading
    @Published var email: String = ""
    @Published var otpCode: String = ""
    @Published var reviewerPassword: String = ""
    @Published private(set) var memberships: [MembershipWithInstitution] = []
    @Published private(set) var selectedMembership: MembershipWithInstitution?
    @Published private(set) var roleSelectionGroup: InstitutionRoleGroup?
    @Published private(set) var studies: [Study] = []
    @Published private(set) var studyDetail: StudyDetailState?
    @Published private(set) var feedbackByStudy: [UUID: [Feedback]] = [:]
    @Published var filter: StudyFilter = .queue
    @Published private(set) var banner: BannerMessage?
    @Published private(set) var uploadStatuses: [UUID: TUSUploadService.UploadStatus] = [:]
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var institutions: [Institution] = []
    @Published private(set) var currentProfile: UserProfileSummary?
    @Published private(set) var attendingDirectory: [UserProfileSummary] = []
    @Published private(set) var fellowDirectory: [UserProfileSummary] = []
    @Published private(set) var signoffs: [UUID: Signoff] = [:]
    @Published private(set) var mediaURLs: [UUID: URL] = [:]

    let uploadService: TUSUploadService

    private let authService: AuthServicing
    private let institutionService: InstitutionServicing
    private let studyService: StudyServicing
    private let storageService: StorageServicing
    private var authSession: AuthSession?
    private var activeSession: ActiveSession?
    private var cancellables = Set<AnyCancellable>()
    private var previousUploadStatuses: [UUID: TUSUploadService.UploadStatus] = [:]
    private let defaults: UserDefaults
    private let institutionDefaultsKey = "pocus.selectedInstitution"

    var institutionRoleGroups: [InstitutionRoleGroup] {
        let grouped = Dictionary(grouping: memberships, by: { $0.institution.id })
        return grouped.values.compactMap { memberships in
            guard let representative = memberships.first else { return nil }
            return InstitutionRoleGroup(institution: representative.institution, memberships: memberships)
        }
        .sorted { $0.institution.name < $1.institution.name }
    }

    init(
        authService: AuthServicing? = nil,
        institutionService: InstitutionServicing? = nil,
        studyService: StudyServicing? = nil,
        storageService: StorageServicing? = nil,
        uploadService: TUSUploadService? = nil,
        defaults: UserDefaults = .standard
    ) {
        let clientProvider = SupabaseClientManager.shared

        self.authService = authService ?? SupabaseAuthService(clientProvider: clientProvider)
        self.institutionService = institutionService ?? SupabaseInstitutionService(clientProvider: clientProvider)
        self.studyService = studyService ?? SupabaseStudyService(clientProvider: clientProvider)
        self.storageService = storageService ?? SupabaseStorageService(clientProvider: clientProvider)
        self.defaults = defaults
        self.uploadService = uploadService ?? TUSUploadService(configuration: AppConfig.shared)

        self.uploadService.$uploads
            .receive(on: RunLoop.main)
            .sink { [weak self] newStatuses in
                self?.handleUploadStateChange(newStatuses)
            }
            .store(in: &cancellables)

        Task {
            await bootstrap()
        }
    }

    var canSubmitStudy: Bool {
        guard let detail = studyDetail else { return false }
        return detail.study.status == .draft || detail.study.status == .needsRevision
    }

    var filteredStudies: [Study] {
        guard let session = activeSession else { return studies }
        let base = studies.sorted(by: { $0.createdAt > $1.createdAt })
        let myUserId = session.profile.id
        let isFellow = session.role.normalized == .fellow

        return base.filter { study in
            switch filter {
            case .drafts:
                return study.status == .draft && study.createdBy == myUserId
            case .queue:
                let reviewStatuses: [StudyStatus] = [.submitted, .reviewable]
                if isFellow {
                    return study.createdBy == myUserId && reviewStatuses.contains(study.status)
                }
                return reviewStatuses.contains(study.status)
            case .returned:
                if isFellow {
                    return study.createdBy == myUserId && study.status == .needsRevision
                }
                return study.status == .needsRevision
            case .completed:
                let matchesStatus = study.status == .approved || study.status == .signedOff
                if isFellow {
                    return study.createdBy == myUserId && matchesStatus
                }
                return matchesStatus
            case .all:
                return isFellow ? (study.createdBy == myUserId) : true
            }
        }
    }

    var myStudies: [Study] {
        guard let session = activeSession else { return [] }
        return studies.filter { $0.createdBy == session.profile.id }
    }

    var portfolioStats: PortfolioStats {
        makePortfolioStats(for: myStudies)
    }

    var fellowPortfolio: PortfolioSummary? {
        guard let session = activeSession else { return nil }
        let accepted = studies.filter {
            $0.createdBy == session.profile.id && ($0.status == .approved || $0.status == .signedOff)
        }

        let grouped = Dictionary(grouping: accepted) { study -> UltrasoundModule in
            module(forExamType: study.examType)
        }

        let perModule = UltrasoundModule.allCases.map { module -> PortfolioProgress in
            let count = grouped[module]?.count ?? 0
            return PortfolioProgress(
                module: module,
                acceptedCount: count,
                requiredCount: module.requiredImages
            )
        }

        let totalAccepted = perModule.reduce(0) { $0 + $1.acceptedCount }
        let totalRequired = perModule.reduce(0) { $0 + $1.requiredCount }

        return PortfolioSummary(
            totalAccepted: totalAccepted,
            totalRequired: totalRequired,
            perModule: perModule
        )
    }

    var programAnalytics: ProgramAnalytics {
        makeProgramAnalytics()
    }

    func feedback(for study: Study) -> [Feedback] {
        if let detail = studyDetail, detail.study.id == study.id {
            return detail.feedback
        }
        return feedbackByStudy[study.id] ?? []
    }

    var reviewQueue: [Study] {
        guard activeSession != nil else { return [] }
        return studies
            .filter { study in
                let statuses: [StudyStatus] = [.submitted, .reviewable]
                return statuses.contains(study.status)
            }
            .sorted(by: { $0.submittedAt ?? $0.createdAt > $1.submittedAt ?? $1.createdAt })
    }

    var returnedReviews: [Study] {
        guard activeSession != nil else { return [] }
        return studies
            .filter { $0.status == .needsRevision }
            .sorted(by: { $0.submittedAt ?? $0.createdAt > $1.submittedAt ?? $1.createdAt })
    }

    var acceptedReviews: [Study] {
        guard activeSession != nil else { return [] }
        return studies
            .filter { study in
                study.status == .approved || study.status == .signedOff
            }
            .sorted(by: { $0.submittedAt ?? $0.createdAt > $1.submittedAt ?? $1.createdAt })
    }

    var currentSession: ActiveSession? {
        activeSession
    }

    // MARK: - Auth flow

    func sendOTP() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@") else {
            banner = BannerMessage(text: "Enter a valid email address.")
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            try await authService.sendLoginOTP(to: trimmed)
            phase = .codeEntry(email: trimmed)
        } catch {
            banner = BannerMessage(text: "Failed to send code: \(error.localizedDescription)")
        }
    }
    
    func loadInstitutions() async {
        do {
            institutions = try await institutionService.fetchAllInstitutions()
        } catch {
            banner = BannerMessage(text: "Failed to load institutions: \(error.localizedDescription)")
        }
    }
    
    /// Presents the signup flow by loading institutions and moving to the signup phase.
    func presentSignup() async {
        await loadInstitutions()
        phase = .signup
    }
    
    /// Presents the login screen.
    func presentLogin() {
        phase = .login
    }
    
    /// Presents the reviewer login screen for TestFlight.
    func presentReviewerLogin() {
        phase = .reviewerLogin
    }
    
    /// Signs in as a reviewer using password authentication.
    func signInAsReviewer(role: String) async {
        isBusy = true
        defer { isBusy = false }
        
        // TestFlight reviewer accounts
        let reviewerAccounts: [String: (email: String, password: String)] = [
            "fellow": ("reviewer.fellow@testflight.app", "TestFlight2024!"),
            "attending": ("reviewer.attending@testflight.app", "TestFlight2024!"),
            "admin": ("reviewer.admin@testflight.app", "TestFlight2024!")
        ]
        
        guard let account = reviewerAccounts[role.lowercased()] else {
            banner = BannerMessage(text: "Invalid reviewer role.")
            return
        }
        
        do {
            let session = try await authService.signInWithPassword(
                email: account.email,
                password: account.password
            )
            authSession = session
            phase = .loading
            try await loadMemberships()
        } catch {
            banner = BannerMessage(text: "Reviewer login failed: \(error.localizedDescription)")
        }
    }
    
    func signup(name: String, institution: Institution?, role: MembershipRole, pgyYear: String?) async {
        guard let institution = institution else {
            banner = BannerMessage(text: "Please select an institution.")
            return
        }
        
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@") else {
            banner = BannerMessage(text: "Enter a valid email address.")
            return
        }
        
        isBusy = true
        defer { isBusy = false }
        
        do {
            // Send signup OTP
            try await authService.sendSignupOTP(to: trimmed)
            phase = .codeEntry(email: trimmed)
            
            // Store signup data temporarily (we'll use it after OTP verification)
            signupData = SignupData(
                name: name,
                institution: institution,
                role: role,
                pgyYear: pgyYear
            )
        } catch {
            banner = BannerMessage(text: "Failed to send signup code: \(error.localizedDescription)")
        }
    }
    
    private struct SignupData {
        let name: String
        let institution: Institution
        let role: MembershipRole
        let pgyYear: String?
    }
    private var signupData: SignupData?

    func verifyOTP() async {
        guard case let .codeEntry(email) = phase else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let session = try await authService.verifyOTP(email: email, code: otpCode)
            otpCode = ""
            authSession = session
            
            // If this was a signup, create profile and membership
            if let signupData = signupData {
                try await institutionService.createProfile(
                    userId: session.profile.id,
                    email: email,
                    fullName: signupData.name
                )
                
                let roleString = signupData.role == .administrator ? "admin" : signupData.role.rawValue
                try await institutionService.createMembershipRequest(
                    userId: session.profile.id,
                    institutionId: signupData.institution.id,
                    role: roleString,
                    pgyYear: signupData.pgyYear
                )
                
                self.signupData = nil
                
                // Check if role needs approval
                let needsApproval = signupData.role == .attending || signupData.role == .administrator
                if needsApproval {
                    phase = .pendingApproval
                    return
                }
            }
            
            phase = .loading
            try await loadMemberships()
        } catch {
            banner = BannerMessage(text: "Verification failed: \(error.localizedDescription)")
        }
    }

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            // ignore sign out error, just reset state
        }
        email = ""
        otpCode = ""
        memberships = []
        selectedMembership = nil
        roleSelectionGroup = nil
        studies = []
        studyDetail = nil
        authSession = nil
        activeSession = nil
        attendingDirectory = []
        fellowDirectory = []
        currentProfile = nil
        signoffs = [:]
        mediaURLs = [:]
        feedbackByStudy = [:]
        defaults.removeObject(forKey: institutionDefaultsKey)
        phase = .login
    }

    // MARK: - Memberships

    func selectMembership(_ membership: MembershipWithInstitution) async {
        guard let authSession else { return }
        selectedMembership = membership
        defaults.set(membership.membership.institutionId.uuidString, forKey: institutionDefaultsKey)

        activeSession = ActiveSession(
            profile: authSession.profile,
            session: authSession.session,
            membership: membership
        )
        roleSelectionGroup = nil
        phase = .dashboard
        await refreshStudies()
        await loadAttendingDirectory()
        await loadFellowDirectoryIfNeeded()
    }

    func handleInstitutionSelection(_ group: InstitutionRoleGroup) async {
        if group.memberships.count == 1, let membership = group.memberships.first {
            await selectMembership(membership)
        } else {
            roleSelectionGroup = group
            phase = .selectingRole(group)
        }
    }

    func presentInstitutionSelection() {
        roleSelectionGroup = nil
        phase = .selectingInstitution
    }

    func loadAttendingDirectory() async {
        guard let session = activeSession else { return }
        do {
            attendingDirectory = try await institutionService.fetchMembers(
                institutionId: session.membership.membership.institutionId,
                roles: [.attending]
            )
        } catch {
            banner = BannerMessage(text: "Unable to load attendings: \(error.localizedDescription)")
        }
    }

    func loadFellowDirectoryIfNeeded() async {
        guard let session = activeSession else { return }
        do {
            fellowDirectory = try await institutionService.fetchMembers(
                institutionId: session.membership.membership.institutionId,
                roles: [.fellow]
            )
        } catch {
            banner = BannerMessage(text: "Unable to load fellows: \(error.localizedDescription)")
        }
    }

    // MARK: - Studies

    func refreshStudies() async {
        guard let session = activeSession else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let results = try await studyService.fetchStudies(
                institutionId: session.membership.membership.institutionId,
                statuses: nil
            )
            studies = results
            if let detail = studyDetail,
               let updated = results.first(where: { $0.id == detail.study.id }) {
                await loadStudyDetail(for: updated)
            }
            await refreshSignoffs(for: results)
            if session.role.normalized == .fellow {
                await preloadFeedbackForMyStudies()
            }
            await loadFellowDirectoryIfNeeded()
        } catch {
            banner = BannerMessage(text: "Unable to load studies: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func createDraftStudy(input: DraftStudyInput) async -> Study? {
        guard let session = activeSession else { return nil }
        isBusy = true
        defer { isBusy = false }

        var metadata = StudyMetadata()
        metadata.caseTitle = input.title
        metadata.module = input.module
        metadata.clinicalContext = input.clinicalContext
        metadata.patientAge = input.patientAge
        metadata.patientGender = input.patientGender
        metadata.preliminaryFindings = input.preliminaryFindings
        metadata.measurements = input.module == .cardiac ? input.measurements : nil
        metadata.attendingContact = input.attendingContact

        let payload = NewStudyRequest(
            institutionId: session.membership.membership.institutionId,
            createdBy: session.profile.id,
            examType: input.module.rawValue,
            status: .draft,
            notes: metadata.encode(),
            assignedAttendingId: input.attendingId
        )

        do {
            let study = try await studyService.createStudy(payload)
            studies.append(study)
            return study
        } catch {
            banner = BannerMessage(text: "Unable to create study: \(error.localizedDescription)")
            return nil
        }
    }

    func submitStudy(study targetStudy: Study? = nil) async {
        let targetId: UUID
        if let study = targetStudy {
            targetId = study.id
        } else if let detail = studyDetail {
            targetId = detail.study.id
        } else {
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            let updated = try await studyService.updateStudyStatus(
                studyId: targetId,
                status: .submitted,
                submittedAt: Date()
            )
            studies = studies.map { $0.id == updated.id ? updated : $0 }
            banner = BannerMessage(text: "Case submitted for review.")
            if let detail = studyDetail, detail.study.id == updated.id {
                studyDetail = nil
            }
        } catch {
            banner = BannerMessage(text: "Failed to submit study: \(error.localizedDescription)")
        }
    }

    func submitReview(
        for study: Study,
        rating: Int?,
        summary: String,
        detailedComments: [String],
        teachingPoints: [String],
        annotations: [ReviewAnnotationPayload],
        signoffStatus: SignoffStatus
    ) async {
        guard let session = activeSession else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let payload = ReviewFeedbackPayload(
                summary: summary,
                detailedComments: detailedComments,
                teachingPoints: teachingPoints,
                annotations: annotations
            )
            let commentsString = payload.jsonString ?? summary

            let feedbackRequest = NewFeedbackRequest(
                studyId: study.id,
                reviewerId: session.profile.id,
                rating: rating,
                comments: commentsString
            )
            _ = try await studyService.insertFeedback(feedbackRequest)

            let signoffRequest = UpsertSignoffRequest(
                studyId: study.id,
                attendingId: session.profile.id,
                status: signoffStatus,
                signedAt: Date()
            )
            _ = try await studyService.upsertSignoff(signoffRequest)

            let newStatus: StudyStatus = signoffStatus == .approved ? .approved : .needsRevision
            let updated = try await studyService.updateStudyStatus(
                studyId: study.id,
                status: newStatus,
                submittedAt: study.submittedAt
            )

            studies = studies.map { $0.id == updated.id ? updated : $0 }

            if let currentDetail = studyDetail, currentDetail.study.id == updated.id {
                await loadStudyDetail(for: updated)
            }

            banner = BannerMessage(text: "Review saved.")
        } catch {
            banner = BannerMessage(text: "Unable to submit review: \(error.localizedDescription)")
        }
    }

    func addMediaComment(for media: Media, rating: Int? = nil, comment: String) async {
        guard let session = activeSession else { return }
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            banner = BannerMessage(text: "Enter a comment before saving.")
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let request = NewFeedbackRequest(
                studyId: media.studyId,
                reviewerId: session.profile.id,
                rating: rating,
                comments: trimmed,
                mediaId: media.id
            )
            _ = try await studyService.insertFeedback(request)
            if let detail = studyDetail, detail.study.id == media.studyId {
                await loadStudyDetail(for: detail.study)
            } else {
                await refreshFeedback(for: media.studyId)
            }
            banner = BannerMessage(text: "Comment saved.")
        } catch {
            banner = BannerMessage(text: "Unable to save comment: \(error.localizedDescription)")
        }
    }

    func updateMetadata(_ metadata: StudyMetadata, successMessage: String = "Details saved.") async {
        guard let detail = studyDetail else { return }
        await persistMetadata(metadata, for: detail.study.id, successMessage: successMessage)
    }

    func loadStudyDetail(for study: Study) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let detail = try await makeStudyDetail(for: study)
            feedbackByStudy[study.id] = detail.feedback
            studyDetail = detail
        } catch {
            banner = BannerMessage(text: "Unable to load study detail: \(error.localizedDescription)")
        }
    }

    func fetchStudyDetail(for study: Study) async -> StudyDetailState? {
        do {
            return try await makeStudyDetail(for: study)
        } catch {
            banner = BannerMessage(text: "Unable to load study detail: \(error.localizedDescription)")
            return nil
        }
    }

    private func makeStudyDetail(for study: Study) async throws -> StudyDetailState {
        let metadata = StudyMetadata.decode(from: study.notes)
        async let media = studyService.fetchMedia(for: study.id)
        async let feedback = studyService.fetchFeedback(for: study.id)
        async let signoff = studyService.fetchSignoff(for: study.id)

        return StudyDetailState(
            study: study,
            metadata: metadata,
            media: try await media,
            feedback: try await feedback,
            signoff: try await signoff
        )
    }

    private func updateMetadata(
        for studyId: UUID,
        showBanner: Bool = false,
        mutate: (inout StudyMetadata) -> Void
    ) async {
        guard let study = studies.first(where: { $0.id == studyId }) else { return }
        var metadata = StudyMetadata.decode(from: study.notes)
        mutate(&metadata)
        await persistMetadata(metadata, for: studyId, successMessage: showBanner ? "Details saved." : nil)
    }

    private func persistMetadata(_ metadata: StudyMetadata, for studyId: UUID, successMessage: String?) async {
        do {
            let updated = try await studyService.updateStudyNotes(
                studyId: studyId,
                notes: metadata.encode()
            )
            if var detail = studyDetail, detail.study.id == studyId {
                detail.metadata = metadata
                studyDetail = detail
            }
            studies = studies.map { $0.id == updated.id ? updated : $0 }
            if let message = successMessage {
                banner = BannerMessage(text: message)
            }
        } catch {
            banner = BannerMessage(text: "Unable to save details: \(error.localizedDescription)")
        }
    }

    private func assignMediaLabel(_ label: String, to media: Media) async {
        await updateMetadata(for: media.studyId, showBanner: false) { metadata in
            metadata.setMediaLabel(label, for: media.id)
        }
    }

    @discardableResult
    func enqueueUpload(fileURL: URL, contentType: String, study: Study, label: String? = nil) -> UUID? {
        guard let session = activeSession else { return nil }
        do {
            let handle = try uploadService.enqueueUpload(
                fileURL: fileURL,
                studyId: study.id,
                institutionId: session.membership.membership.institutionId,
                contentType: contentType,
                accessToken: session.session.accessToken,
                label: label
            )
            uploadStatuses[handle.id] = .queued
            return handle.id
        } catch {
            banner = BannerMessage(text: "Failed to start upload: \(error.localizedDescription)")
            return nil
        }
    }

    func uploads(for studyId: UUID) -> [(TUSUploadService.UploadContext, TUSUploadService.UploadStatus)] {
        uploadService.contexts
            .compactMap { key, context -> (TUSUploadService.UploadContext, TUSUploadService.UploadStatus)? in
                guard context.studyId == studyId, let status = uploadStatuses[key] else { return nil }
                return (context, status)
            }
    }

    func dismissBanner() {
        banner = nil
    }

    func dismissStudyDetail() {
        studyDetail = nil
    }

    func presentBanner(_ text: String) {
        banner = BannerMessage(text: text)
    }

    func signedMediaURL(for path: String) async -> URL? {
        do {
            return try await storageService.signedURL(for: path, expiresIn: 60 * 60)
        } catch {
            presentBanner("Unable to load media: \(error.localizedDescription)")
            return nil
        }
    }

    private func module(forExamType examType: String) -> UltrasoundModule {
        if let exact = UltrasoundModule(rawValue: examType) {
            return exact
        }
        if let match = UltrasoundModule.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(examType) == .orderedSame
        }) {
            return match
        }
        return .cardiac
    }

    private func makePortfolioStats(for studies: [Study]) -> PortfolioStats {
        let drafts = studies.filter { $0.status == .draft }.count
        let submitted = studies.filter { [.submitted, .reviewable].contains($0.status) }.count
        let returned = studies.filter { $0.status == .needsRevision }.count
        let completed = studies.filter { [.approved, .signedOff].contains($0.status) }.count
        let total = studies.count
        let totalSubmitted = max(total - drafts, 0)
        let acceptance = totalSubmitted > 0 ? Double(completed) / Double(totalSubmitted) : 0
        let breakdown = Dictionary(grouping: studies, by: { $0.examType })
            .map { PortfolioStats.ExamStat(examType: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        return PortfolioStats(
            totalCases: total,
            drafts: drafts,
            submitted: submitted,
            returned: returned,
            completed: completed,
            acceptanceRate: acceptance,
            examBreakdown: breakdown
        )
    }

    private func makeProgramAnalytics() -> ProgramAnalytics {
        let drafts = studies.filter { $0.status == .draft }.count
        let submitted = studies.filter { [.submitted, .reviewable].contains($0.status) }.count
        let returned = studies.filter { $0.status == .needsRevision }.count
        let completed = studies.filter { [.approved, .signedOff].contains($0.status) }.count
        let total = studies.count
        let totalSubmitted = max(total - drafts, 0)
        let acceptance = totalSubmitted > 0 ? Double(completed) / Double(totalSubmitted) : 0

        let breakdown = Dictionary(grouping: studies, by: { $0.examType })
            .map { ProgramAnalytics.ExamStat(examType: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        let grouped = Dictionary(grouping: studies, by: { $0.createdBy })
        let summaries = grouped.map { entry -> ProgramAnalytics.FellowSummary in
            let (userId, cases) = entry
            let drafts = cases.filter { $0.status == .draft }.count
            let submitted = cases.filter { [.submitted, .reviewable].contains($0.status) }.count
            let returned = cases.filter { $0.status == .needsRevision }.count
            let completed = cases.filter { [.approved, .signedOff].contains($0.status) }.count
            let label = fellowInfo(for: userId)
            return ProgramAnalytics.FellowSummary(
                id: userId,
                name: label.name,
                email: label.email,
                drafts: drafts,
                submitted: submitted,
                returned: returned,
                completed: completed
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalCases == rhs.totalCases {
                return lhs.name < rhs.name
            }
            return lhs.totalCases > rhs.totalCases
        }

        return ProgramAnalytics(
            totalCases: total,
            drafts: drafts,
            submitted: submitted,
            returned: returned,
            completed: completed,
            acceptanceRate: acceptance,
            examBreakdown: breakdown,
            fellowSummaries: summaries
        )
    }

    func fellowInfo(for userId: UUID) -> (name: String, email: String) {
        if let match = fellowDirectory.first(where: { $0.id == userId }) {
            let preferredName = match.fullName?.isEmpty == false ? match.fullName! : match.email
            return (preferredName, match.email)
        }
        if let current = currentProfile, current.id == userId {
            let preferredName = current.fullName?.isEmpty == false ? current.fullName! : current.email
            return (preferredName, current.email)
        }
        return ("Fellow \(userId.uuidString.prefix(4))", "")
    }

    // MARK: - Private helpers

    private func bootstrap() async {
        // Load institutions for signup flow
        await loadInstitutions()
        
        do {
            if let session = try await authService.currentSession(),
               let profile = try await authService.currentUser() {
                authSession = AuthSession(profile: profile, session: session)
                try await loadMemberships()
            } else {
                phase = .login
            }
        } catch {
            phase = .login
        }
    }

    private func loadMemberships() async throws {
        guard let authSession else {
            phase = .login
            return
        }

        if let profile = try? await institutionService.fetchProfile(userId: authSession.profile.id) {
            currentProfile = profile
        } else {
            currentProfile = UserProfileSummary(
                id: authSession.profile.id,
                fullName: nil,
                email: authSession.profile.email
            )
        }

        do {
            let results = try await institutionService.fetchMemberships(for: authSession.profile.id)
            if results.isEmpty {
                let fallback = makeFallbackMembership(for: authSession.profile.id)
                memberships = [fallback]
                await selectMembership(fallback)
                return
            }

            memberships = results

            if let saved = defaults.string(forKey: institutionDefaultsKey),
               let group = institutionRoleGroups.first(where: { $0.institution.id.uuidString == saved }) {
                if group.memberships.count == 1, let membership = group.memberships.first {
                    await selectMembership(membership)
                } else {
                    roleSelectionGroup = group
                    phase = .selectingRole(group)
                }
            } else if let firstGroup = institutionRoleGroups.first {
                if firstGroup.memberships.count == 1, let membership = firstGroup.memberships.first {
                    await selectMembership(membership)
                } else if institutionRoleGroups.count == 1 {
                    roleSelectionGroup = firstGroup
                    phase = .selectingRole(firstGroup)
                } else {
                    roleSelectionGroup = nil
                    phase = .selectingInstitution
                }
            } else {
                roleSelectionGroup = nil
                phase = .selectingInstitution
            }
        } catch {
            let fallback = makeFallbackMembership(for: authSession.profile.id)
            memberships = [fallback]
            await selectMembership(fallback)
        }
    }

    private func handleUploadStateChange(_ newStatuses: [UUID: TUSUploadService.UploadStatus]) {
        uploadStatuses = newStatuses
        for (id, status) in newStatuses {
            switch status {
            case .completed:
                let previous = previousUploadStatuses[id]
                if previous == nil || !(previous!.isCompleted) {
                    Task {
                        await handleUploadCompletion(id: id)
                    }
                }
            case .failed(let message):
                if previousUploadStatuses[id]?.isFailed != true {
                    banner = BannerMessage(text: "Upload failed: \(message)")
                }
            default:
                break
            }
        }
        previousUploadStatuses = newStatuses
    }

    private func handleUploadCompletion(id: UUID) async {
        guard let context = uploadService.contexts[id] else { return }

        let kind = mediaKind(for: context.contentType)
        let payload = NewMediaRequest(
            studyId: context.studyId,
            kind: kind,
            storagePath: context.objectName,
            contentType: context.contentType,
            status: .clean
        )

        do {
            let media = try await studyService.insertMedia(payload)
            if var detail = studyDetail, detail.study.id == context.studyId {
                detail.media.insert(media, at: 0)
                studyDetail = detail
            }
            if let label = context.label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
                await assignMediaLabel(label, to: media)
            }
            await refreshStudies()
        } catch {
            banner = BannerMessage(text: "Unable to persist media: \(error.localizedDescription)")
        }
    }

    private func mediaKind(for contentType: String) -> MediaKind {
        if contentType.lowercased().starts(with: "video/") {
            return .video
        }
        if contentType.lowercased().starts(with: "image/") {
            return .image
        }
        return .other
    }

    private func makeFallbackMembership(for userId: UUID) -> MembershipWithInstitution {
        let institution = Institution(
            id: UUID(),
            slug: "default",
            name: "Default Institution",
            settings: .null
        )
        let membership = Membership(
            userId: userId,
            institutionId: institution.id,
            role: MembershipRole.fellow.rawValue
        )
        return MembershipWithInstitution(membership: membership, institution: institution)
    }

    private func refreshSignoffs(for studies: [Study]) async {
        guard let userId = activeSession?.profile.id else {
            signoffs = [:]
            return
        }
        let myStudyIds = studies
            .filter { $0.createdBy == userId }
            .map(\.id)
        guard !myStudyIds.isEmpty else {
            signoffs = [:]
            return
        }

        do {
            let fetched = try await studyService.fetchSignoffs(for: myStudyIds)
            var map: [UUID: Signoff] = [:]
            for item in fetched {
                map[item.studyId] = item
            }
            signoffs = map
        } catch {
            // best-effort: metrics view can tolerate missing signoffs
        }
    }

    func preloadFeedbackForMyStudies() async {
        guard let session = activeSession else { return }
        let ids = studies
            .filter { $0.createdBy == session.profile.id }
            .map(\.id)
        guard !ids.isEmpty else { return }

        do {
            let feedback = try await studyService.fetchFeedback(for: ids)
            let grouped = Dictionary(grouping: feedback, by: \.studyId)
            var updated = feedbackByStudy
            for id in ids {
                updated[id] = grouped[id] ?? []
            }
            feedbackByStudy = updated
        } catch {
            banner = BannerMessage(text: "Unable to load feedback: \(error.localizedDescription)")
        }
    }

    func refreshFeedback(for studyId: UUID) async {
        do {
            let feedback = try await studyService.fetchFeedback(for: studyId)
            feedbackByStudy[studyId] = feedback
        } catch {
            banner = BannerMessage(text: "Unable to load feedback: \(error.localizedDescription)")
        }
    }

    func signedURL(for media: Media, cachePolicy: CachePolicy = .useCache) async -> URL? {
        if cachePolicy == .useCache, let cached = mediaURLs[media.id] {
            return cached
        }

        do {
            let url = try await storageService.signedURL(
                for: media.storagePath,
                expiresIn: 1800
            )
            mediaURLs[media.id] = url
            return url
        } catch {
            banner = BannerMessage(text: "Unable to load media: \(error.localizedDescription)")
            return nil
        }
    }

    enum CachePolicy {
        case useCache
        case refresh
    }
}

private extension TUSUploadService.UploadStatus {
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
