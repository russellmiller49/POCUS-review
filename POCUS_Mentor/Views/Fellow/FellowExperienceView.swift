import SwiftUI

struct FellowExperienceView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var myStudies: [Study] {
        guard let userId = viewModel.currentSession?.profile.id else { return [] }
        return viewModel.filteredStudies
            .filter { $0.createdBy == userId }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private var returnedStudies: [Study] {
        guard let userId = viewModel.currentSession?.profile.id else { return [] }
        return viewModel.studies
            .filter { $0.createdBy == userId && $0.status == .needsRevision }
            .sorted(by: { ($0.submittedAt ?? $0.createdAt) > ($1.submittedAt ?? $1.createdAt) })
    }

    private var stats: AppViewModel.PortfolioStats {
        viewModel.portfolioStats
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dashboardHeader
                    PortfolioSummaryGrid(stats: stats)
                    filterControl
                    caseListSection
                    portfolioBreakdown
                    returnedCasesSection
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .refreshable {
                await viewModel.refreshStudies()
            }
            .navigationTitle("Fellow Dashboard")
        }
        .task {
            if viewModel.studies.isEmpty {
                await viewModel.refreshStudies()
            }
        }
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Your learning progress at a glance")
                .font(.title.bold())
            if let institution = viewModel.currentSession?.institutionName {
                Text(institution)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        if let name = viewModel.currentProfile?.fullName, !name.isEmpty {
            return "Welcome back, \(name.split(separator: " ").first ?? Substring(name))"
        }
        return "Welcome back"
    }

    private var filterControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Cases")
                    .font(.title3.bold())
                Spacer()
                RefreshButton(isBusy: viewModel.isBusy) {
                    Task { await viewModel.refreshStudies() }
                }
            }
            Picker("Filter", selection: $viewModel.filter) {
                ForEach(AppViewModel.StudyFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var caseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if myStudies.isEmpty {
                ContentUnavailableView(
                    "No cases yet",
                    systemImage: "tray",
                    description: Text("Start logging your studies from the Studies tab.")
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(myStudies) { study in
                        Button {
                            Task { await viewModel.loadStudyDetail(for: study) }
                        } label: {
                            FellowStudyRow(study: study)
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    }
                }
            }
        }
    }

    private var portfolioBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolio breakdown")
                .font(.title3.bold())
            if stats.examBreakdown.isEmpty {
                Text("No submissions yet by module.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stats.examBreakdown) { stat in
                    HStack {
                        Text(stat.examType)
                        Spacer()
                        Text("\(stat.count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.gray.opacity(0.15)))
    }

    private var returnedCasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Needs revision")
                .font(.title3.bold())
            if returnedStudies.isEmpty {
                Text("You're all caught up.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(returnedStudies) { study in
                    Button {
                        Task { await viewModel.loadStudyDetail(for: study) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(study.examType)
                                        .font(.headline)
                                    Text(study.createdAt, format: .dateTime.month().day().year())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            if let preview = feedbackPreview(for: study), !preview.isEmpty {
                                Text(preview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            } else {
                                Text("Awaiting attending comments.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func feedbackPreview(for study: Study) -> String? {
        guard let feedback = viewModel.feedback(for: study).first else { return nil }
        if let payload = ReviewFeedbackPayload.decode(from: feedback.comments),
           !payload.summary.isEmpty {
            return payload.summary
        }
        return feedback.comments
    }
}

private struct FellowStudyRow: View {
    let study: Study

    private var metadata: StudyMetadata {
        StudyMetadata.decode(from: study.notes)
    }

    private var statusDescription: String {
        study.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(metadata.caseTitle?.isEmpty == false ? metadata.caseTitle! : study.examType)
                    .font(.headline)
                Spacer()
                StatusBadge(status: study.status)
            }
            Text(study.createdAt, format: .dateTime.month().day().year())
                .font(.caption)
                .foregroundStyle(.secondary)
            if let context = metadata.clinicalContext, !context.isEmpty {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(statusDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusBadge: View {
    let status: StudyStatus

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }

    private var label: String {
        status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var color: Color {
        switch status {
        case .draft: return .gray
        case .submitted: return .blue
        case .reviewable: return .orange
        case .needsRevision: return .pink
        case .approved: return .green
        case .signedOff: return .teal
        }
    }
}

private struct PortfolioSummaryGrid: View {
    let stats: AppViewModel.PortfolioStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            PortfolioSummaryCard(title: "Submitted", value: stats.submitted)
            PortfolioSummaryCard(title: "Returned", value: stats.returned)
            PortfolioSummaryCard(title: "Completed", value: stats.completed)
            PortfolioSummaryCard(title: "Acceptance", value: Int((stats.acceptanceRate * 100).rounded()), suffix: "%")
        }
    }
}

private struct PortfolioSummaryCard: View {
    let title: String
    let value: Int
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)\(suffix)")
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}
