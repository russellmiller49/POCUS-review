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
        case selectingInstitution
        case selectingRole(InstitutionRoleGroup)
        case dashboard
        case pendingApproval
    }

    enum StudyFilter: Hashable, CaseIterable {
        case drafts
        case queue
        case reviewable
        case completed
        case all

        var title: String {
            switch self {
            case .drafts: return "Drafts"
            case .queue: return "Submitted"
            case .reviewable: return "Review"
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

    @Published private(set) var phase: Phase = .loading
    @Published var email: String = ""
    @Published var otpCode: String = ""
    @Published private(set) var memberships: [MembershipWithInstitution] = []
    @Published private(set) var selectedMembership: MembershipWithInstitution?
    @Published private(set) var roleSelectionGroup: InstitutionRoleGroup?
    @Published private(set) var studies: [Study] = []
    @Published private(set) var studyDetail: StudyDetailState?
    @Published var filter: StudyFilter = .queue
    @Published private(set) var banner: BannerMessage?
    @Published private(set) var uploadStatuses: [UUID: TUSUploadService.UploadStatus] = [:]
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var institutions: [Institution] = []
    @Published private(set) var currentProfile: UserProfileSummary?
    @Published private(set) var attendingDirectory: [UserProfileSummary] = []
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
        return detail.study.status == .draft || detail.study.status == .reviewable || detail.study.status == .needsRevision
    }

    var filteredStudies: [Study] {
        guard let session = activeSession else { return studies }
        let base = studies.sorted(by: { $0.createdAt > $1.createdAt })

        return base.filter { study in
            switch filter {
            case .drafts:
                return study.status == .draft && study.createdBy == session.profile.id
            case .queue:
                return study.status == .submitted || study.status == .needsRevision
            case .reviewable:
                return study.status == .reviewable
            case .completed:
                return study.status == .approved || study.status == .signedOff
            case .all:
                return true
            }
        }
    }

    var reviewQueue: [Study] {
        guard let session = activeSession else { return [] }
        return studies
            .filter { study in
                let statuses: [StudyStatus] = [.submitted, .reviewable, .needsRevision]
                return statuses.contains(study.status)
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
        studies = []
        studyDetail = nil
        authSession = nil
        activeSession = nil
        attendingDirectory = []
        currentProfile = nil
        signoffs = [:]
        mediaURLs = [:]
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
        metadata.urgency = input.urgency
        metadata.patientAge = input.patientAge
        metadata.patientGender = input.patientGender
        metadata.preliminaryFindings = input.preliminaryFindings
        metadata.measurements = input.measurements
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
            studyDetail = StudyDetailState(
                study: study,
                metadata: metadata,
                media: [],
                feedback: [],
                signoff: nil
            )
            return study
        } catch {
            banner = BannerMessage(text: "Unable to create study: \(error.localizedDescription)")
            return nil
        }
    }

    func submitStudy() async {
        guard let detail = studyDetail else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let updated = try await studyService.updateStudyStatus(
                studyId: detail.study.id,
                status: .submitted,
                submittedAt: Date()
            )
            await loadStudyDetail(for: updated)
            studies = studies.map { $0.id == updated.id ? updated : $0 }
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
            let signoff = try await studyService.upsertSignoff(signoffRequest)

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

    func updateMetadata(_ metadata: StudyMetadata) async {
        guard let detail = studyDetail else { return }
        do {
            let updated = try await studyService.updateStudyNotes(
                studyId: detail.study.id,
                notes: metadata.encode()
            )
            await loadStudyDetail(for: updated)
            studies = studies.map { $0.id == updated.id ? updated : $0 }
        } catch {
            banner = BannerMessage(text: "Unable to save details: \(error.localizedDescription)")
        }
    }

    func loadStudyDetail(for study: Study) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let metadata = StudyMetadata.decode(from: study.notes)
            async let media = studyService.fetchMedia(for: study.id)
            async let feedback = studyService.fetchFeedback(for: study.id)
            async let signoff = studyService.fetchSignoff(for: study.id)

            let detail = StudyDetailState(
                study: study,
                metadata: metadata,
                media: try await media,
                feedback: try await feedback,
                signoff: try await signoff
            )
            studyDetail = detail
        } catch {
            banner = BannerMessage(text: "Unable to load study detail: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func enqueueUpload(fileURL: URL, contentType: String, study: Study) -> UUID? {
        guard let session = activeSession else { return nil }
        do {
            let handle = try uploadService.enqueueUpload(
                fileURL: fileURL,
                studyId: study.id,
                institutionId: session.membership.membership.institutionId,
                contentType: contentType,
                accessToken: session.session.accessToken
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
        guard
            let context = uploadService.contexts[id],
            let session = activeSession
        else { return }

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
