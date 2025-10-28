import SwiftUI

struct AttendingExperienceView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        TabView {
            ReviewQueueView()
                .tabItem { Label("Queue", systemImage: "tray.full.fill") }
            AttendingCaseHistoryView()
                .tabItem { Label("Completed", systemImage: "checkmark.circle") }
            AttendingAnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }
            MessagesHubView()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(appState.attendings) { attending in
                        Button(attending.name) {
                            appState.selectedAttending = attending
                        }
                    }
                } label: {
                    Label(appState.selectedAttending?.name ?? "Select Attending", systemImage: "person.crop.rectangle")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton(systemImage: "pencil.and.outline", title: "Feedback") {
                appState.showFeedbackComposer = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 40)
            .sheet(isPresented: $appState.showFeedbackComposer) {
                FeedbackComposer()
            }
        }
    }
}
