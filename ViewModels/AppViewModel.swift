import Foundation
import Combine
import Supabase

@MainActor
final class AppViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case login
        case codeEntry(email: String)
        case selectingInstitution
        case dashboard
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

    @Published private(set) var phase: Phase = .loading
    @Published var email: String = ""
    @Published var otpCode: String = ""
    @Published private(set) var memberships: [MembershipWithInstitution] = []
    @Published private(set) var selectedMembership: MembershipWithInstitution?
    @Published private(set) var studies: [Study] = []
    @Published private(set) var studyDetail: StudyDetailState?
    @Published var filter: StudyFilter = .queue
    @Published private(set) var banner: BannerMessage?
    @Published private(set) var uploadStatuses: [UUID: TUSUploadService.UploadStatus] = [:]
    @Published private(set) var isBusy: Bool = false

    let uploadService: TUSUploadService

    private let authService: AuthServicing
    private let institutionService: InstitutionServicing
    private let studyService: StudyServicing
    private var authSession: AuthSession?
    private var activeSession: ActiveSession?
    private var cancellables = Set<AnyCancellable>()
    private var previousUploadStatuses: [UUID: TUSUploadService.UploadStatus] = [:]
    private let defaults: UserDefaults
    private let institutionDefaultsKey = "pocus.selectedInstitution"

    init(
        authService: AuthServicing = SupabaseAuthService(),
        institutionService: InstitutionServicing = SupabaseInstitutionService(),
        studyService: StudyServicing = SupabaseStudyService(),
        uploadService: TUSUploadService? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.authService = authService
        self.institutionService = institutionService
        self.studyService = studyService
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

    func verifyOTP() async {
        guard case let .codeEntry(email) = phase else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let session = try await authService.verifyOTP(email: email, code: otpCode)
            otpCode = ""
            authSession = session
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
        phase = .dashboard
        await refreshStudies()
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
        } catch {
            banner = BannerMessage(text: "Unable to load studies: \(error.localizedDescription)")
        }
    }

    func createDraftStudy(examType: String, notes: String?) async {
        guard let session = activeSession else { return }
        isBusy = true
        defer { isBusy = false }

        let payload = NewStudyRequest(
            institutionId: session.membership.membership.institutionId,
            createdBy: session.profile.id,
            examType: examType,
            status: .draft,
            notes: notes
        )

        do {
            let study = try await studyService.createStudy(payload)
            studies.append(study)
            studyDetail = StudyDetailState(study: study, media: [], feedback: [], signoff: nil)
        } catch {
            banner = BannerMessage(text: "Unable to create study: \(error.localizedDescription)")
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

    func submitReview(for study: Study, rating: Int?, comments: String?, signoffStatus: SignoffStatus) async {
        guard let session = activeSession else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let feedbackRequest = NewFeedbackRequest(
                studyId: study.id,
                reviewerId: session.profile.id,
                rating: rating,
                comments: comments
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

    func saveNotes(_ notes: String?) async {
        guard let detail = studyDetail else { return }
        do {
            let updated = try await studyService.updateStudyNotes(
                studyId: detail.study.id,
                notes: notes
            )
            await loadStudyDetail(for: updated)
            studies = studies.map { $0.id == updated.id ? updated : $0 }
        } catch {
            banner = BannerMessage(text: "Unable to save notes: \(error.localizedDescription)")
        }
    }

    func loadStudyDetail(for study: Study) async {
        isBusy = true
        defer { isBusy = false }

        do {
            async let media = studyService.fetchMedia(for: study.id)
            async let feedback = studyService.fetchFeedback(for: study.id)
            async let signoff = studyService.fetchSignoff(for: study.id)

            let detail = StudyDetailState(
                study: study,
                media: try await media,
                feedback: try await feedback,
                signoff: try await signoff
            )
            studyDetail = detail
        } catch {
            banner = BannerMessage(text: "Unable to load study detail: \(error.localizedDescription)")
        }
    }

    func enqueueUpload(fileURL: URL, contentType: String, study: Study) {
        guard let session = activeSession else { return }
        do {
            let handle = try uploadService.enqueueUpload(
                fileURL: fileURL,
                studyId: study.id,
                institutionId: session.membership.membership.institutionId,
                contentType: contentType,
                accessToken: session.session.accessToken
            )
            uploadStatuses[handle.id] = .queued
        } catch {
            banner = BannerMessage(text: "Failed to start upload: \(error.localizedDescription)")
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

    // MARK: - Private helpers

    private func bootstrap() async {
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

        let results = try await institutionService.fetchMemberships(for: authSession.profile.id)
        memberships = results

        if let saved = defaults.string(forKey: institutionDefaultsKey),
           let restored = results.first(where: { $0.membership.institutionId.uuidString == saved }) {
            await selectMembership(restored)
        } else if let first = results.first {
            if results.count == 1 {
                await selectMembership(first)
            } else {
                phase = .selectingInstitution
            }
        } else {
            banner = BannerMessage(text: "No institution memberships found.")
            phase = .login
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
