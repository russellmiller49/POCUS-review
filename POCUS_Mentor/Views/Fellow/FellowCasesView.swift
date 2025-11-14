import SwiftUI

struct FellowCasesView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var filter: AppViewModel.StudyFilter = .all
    
    private var cases: [Study] {
        viewModel.myStudies.filter { study in
            switch filter {
            case .drafts:
                return study.status == .draft
            case .queue:
                return [.submitted, .reviewable].contains(study.status)
            case .returned:
                return study.status == .needsRevision
            case .completed:
                return [.approved, .signedOff].contains(study.status)
            case .all:
                return true
            }
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Filter")
                            .font(.subheadline.bold())
                        Spacer()
                        RefreshButton(isBusy: viewModel.isBusy) {
                            Task { await viewModel.refreshStudies() }
                        }
                    }
                    Picker("Filter", selection: $filter) {
                        ForEach(AppViewModel.StudyFilter.allCases, id: \.self) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
            }
            
            Section("My Cases") {
                if cases.isEmpty {
                    EmptyPlaceholderView(
                        title: "No cases",
                        message: "Draft or submit a case from the Studies tab.",
                        systemImage: "tray"
                    )
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(cases, id: \.id) { study in
                        Button {
                            Task { await viewModel.loadStudyDetail(for: study) }
                        } label: {
                            FellowCaseRow(study: study)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.refreshStudies()
        }
        .task {
            if viewModel.studies.isEmpty {
                await viewModel.refreshStudies()
            }
        }
    }
}

private struct FellowCaseRow: View {
    let study: Study
    private var metadata: StudyMetadata { StudyMetadata.decode(from: study.notes) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metadata.caseTitle?.isEmpty == false ? metadata.caseTitle! : study.examType)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                StatusChip(status: study.status)
            }
            Text(study.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let context = metadata.clinicalContext, !context.isEmpty {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}
