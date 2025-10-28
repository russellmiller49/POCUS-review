import SwiftUI

struct MessagesHubView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List {
            Section("Recent Threads") {
                ForEach(appState.messageThreads) { thread in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(Text(initials(for: thread)).font(.headline))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(thread.participants.joined(separator: ", "))
                                .font(.headline)
                            Text(thread.lastMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(relativeDate(for: thread.updatedAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Messages")
    }
    
    private func initials(for thread: MessageThread) -> String {
        let names = thread.participants.prefix(2)
        let initials = names.compactMap { $0.split(separator: " ").first?.first }
        return initials.map { String($0) }.joined()
    }
    
    private func relativeDate(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
