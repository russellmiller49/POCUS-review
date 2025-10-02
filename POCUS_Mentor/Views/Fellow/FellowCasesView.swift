import SwiftUI

struct FellowCasesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var statusFilter: CaseStatus? = nil
    
    private var filteredCases: [POCUSCase] {
        guard let statusFilter else { return appState.filteredCases }
        return appState.filteredCases.filter { $0.status == statusFilter }
    }
    
    var body: some View {
        List {
            Section {
                Picker("Status", selection: statusBinding) {
                    Text("All statuses").tag(CaseStatus?.none)
                    ForEach(CaseStatus.allCases) { status in
                        Text(status.displayName).tag(CaseStatus?.some(status))
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("My Cases") {
                if filteredCases.isEmpty {
                    EmptyPlaceholderView(title: "No cases found", message: "Adjust filters or upload a new study to see it here.", systemImage: "magnifyingglass")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredCases) { caseData in
                        NavigationLink {
                            CaseDetailView(caseData: caseData)
                        } label: {
                            CaseRow(caseData: caseData)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $appState.searchText, prompt: "Search cases")
    }
    
    private var statusBinding: Binding<CaseStatus?> {
        Binding {
            statusFilter
        } set: { newValue in
            withAnimation { statusFilter = newValue }
        }
    }
}

private struct CaseRow: View {
    let caseData: POCUSCase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(caseData.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(caseData.urgency.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(caseData.urgency.color.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(caseData.clinicalIndication)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Label("\(caseData.media.count) media", systemImage: "photo.on.rectangle")
                    .font(.caption)
                Spacer()
                Text(caseData.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(caseData.status.badgeColor)
            }
        }
        .padding(.vertical, 6)
    }
}
