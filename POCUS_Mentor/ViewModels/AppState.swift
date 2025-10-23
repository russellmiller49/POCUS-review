import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedRole: UserRole? = nil
    @Published var selectedFellow: Fellow? = SampleData.fellows.first
    @Published var selectedAttending: Attending? = SampleData.attendings.first
    @Published var selectedCase: POCUSCase? = nil
    @Published var cases: [POCUSCase] = SampleData.cases()
    @Published var selectedAnalyticsSnapshot: AnalyticsSnapshot = SampleData.analyticsSnapshots.first ?? AnalyticsSnapshot(periodLabel: "N/A", totalCases: 0, acceptanceRate: 0, averageReviewTimeHours: 0, topFeedbackThemes: [], skillTrends: [])
    @Published var notifications: [NotificationItem] = SampleData.notifications
    @Published var showCreateCaseFlow: Bool = false
    @Published var showFeedbackComposer: Bool = false
    @Published var searchText: String = ""
    
    var fellows: [Fellow] { SampleData.fellows }
    var attendings: [Attending] { SampleData.attendings }
    var programMetrics: [ProgramMetric] { SampleData.programMetrics }
    var administratorReports: [AdministratorReportSection] { SampleData.administratorReports }
    var messageThreads: [MessageThread] { SampleData.messageThreads }
    var resourceLinks: [ResourceLink] { SampleData.resourceLinks }
    
    var filteredCases: [POCUSCase] {
        var baseCases = cases
        if let role = selectedRole {
            switch role {
            case .fellow:
                if let fellow = selectedFellow {
                    baseCases = baseCases.filter { $0.fellow.id == fellow.id }
                }
            case .attending:
                if let attending = selectedAttending {
                    baseCases = baseCases.filter { $0.assignedAttending.id == attending.id }
                }
            case .administrator:
                break
            }
        }
        guard !searchText.isEmpty else { return baseCases }
        return baseCases.filter { caseData in
            caseData.title.localizedCaseInsensitiveContains(searchText) ||
            caseData.studyType.localizedCaseInsensitiveContains(searchText) ||
            caseData.fellow.name.localizedCaseInsensitiveContains(searchText) ||
            caseData.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }
    
    var reviewQueue: [POCUSCase] {
        casesForSelectedAttending.filter { [.submitted, .needsRevision].contains($0.status) }
    }
    
    var completedReviews: [POCUSCase] {
        casesForSelectedAttending.filter { $0.feedback != nil }
    }
    
    var awaitingFeedback: [POCUSCase] {
        cases.filter { $0.feedback == nil && $0.status != .draft }
    }
    
    private var casesForSelectedAttending: [POCUSCase] {
        guard let attending = selectedAttending else { return [] }
        return cases.filter { $0.assignedAttending.id == attending.id }
    }
    
    func addCase(_ newCase: POCUSCase) {
        cases.append(newCase)

        // Add notification for attending
        let notification = NotificationItem(
            title: "New case assigned",
            message: "\(newCase.fellow.name) submitted '\(newCase.title)' for your review",
            date: Date(),
            role: .attending,
            isRead: false,
            actionLabel: "Review Case"
        )
        notifications.insert(notification, at: 0)
    }

    func applyFeedback(_ feedback: CaseFeedback, to caseID: UUID, newStatus: CaseStatus) {
        cases = cases.map { caseItem in
            guard caseItem.id == caseID else { return caseItem }
            var updated = caseItem
            updated.feedback = feedback
            updated.status = newStatus
            return updated
        }

        // Update portfolio progress if case is accepted
        if newStatus == .accepted, let acceptedCase = cases.first(where: { $0.id == caseID }) {
            updatePortfolioProgress(for: acceptedCase)
        }
    }

    private func updatePortfolioProgress(for case: POCUSCase) {
        // Update fellow's portfolio progress
        if let fellowIndex = fellows.firstIndex(where: { $0.id == `case`.fellow.id }) {
            var updatedFellow = fellows[fellowIndex]

            if let progressIndex = updatedFellow.portfolioProgress.firstIndex(where: { $0.module == `case`.ultrasoundModule }) {
                let requiredMediaCount = `case`.requiredMedia.count
                updatedFellow.portfolioProgress[progressIndex].acceptedCount += requiredMediaCount
            }

            // Update in sample data (in a real app, this would persist)
            if let selectedIndex = fellows.firstIndex(where: { $0.id == selectedFellow?.id }) {
                var selected = fellows[selectedIndex]
                if let progressIndex = selected.portfolioProgress.firstIndex(where: { $0.module == `case`.ultrasoundModule }) {
                    selected.portfolioProgress[progressIndex].acceptedCount += `case`.requiredMedia.count
                }
                selectedFellow = selected
            }
        }
    }

    func markNotificationAsRead(_ notification: NotificationItem) {
        notifications = notifications.map { item in
            guard item.id == notification.id else { return item }
            var updated = item
            updated.isRead = true
            return updated
        }
    }
    
    func resetState() {
        selectedRole = nil
        selectedCase = nil
        searchText = ""
        selectedFellow = fellows.first
        selectedAttending = attendings.first
    }
}
