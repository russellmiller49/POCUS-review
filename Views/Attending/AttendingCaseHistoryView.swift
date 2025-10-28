import SwiftUI

struct AttendingCaseHistoryView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List {
            Section("Completed Reviews") {
                if appState.completedReviews.isEmpty {
                    EmptyPlaceholderView(title: "No completed cases", message: "Once you finalize feedback it will appear here with a quick summary.", systemImage: "clock")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(appState.completedReviews) { caseData in
                        NavigationLink {
                            CaseDetailView(caseData: caseData)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(caseData.title)
                                    .font(.headline)
                                if let summary = caseData.feedback?.summary {
                                    Text(summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                HStack {
                                    Label(caseData.fellow.name, systemImage: "person")
                                        .font(.caption)
                                    Spacer()
                                    if let feedback = caseData.feedback {
                                        Label("\(feedback.qualityRating)★", systemImage: "star.fill")
                                            .font(.caption)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
