import SwiftUI

struct NotificationBellView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showNotifications = false
    
    private var unreadCount: Int {
        appState.notifications.filter { !$0.isRead }.count
    }
    
    var body: some View {
        Button {
            showNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .semibold))
                
                if unreadCount > 0 {
                    Text("\(min(unreadCount, 9))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(.red))
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unreadCount > 0 ? "\(unreadCount) unread notifications" : "No unread notifications")
        .sheet(isPresented: $showNotifications) {
            NotificationCenterView()
        }
    }
}

private struct NotificationCenterView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.notifications) { notification in
                    NotificationRow(notification: notification)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}

private struct NotificationRow: View {
    @EnvironmentObject private var appState: AppState
    let notification: NotificationItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(notification.title)
                    .font(.headline)
                Spacer()
                Text(timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(notification.message)
                .font(.subheadline)
            if let actionLabel = notification.actionLabel {
                Text(actionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(roleColor)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.markNotificationAsRead(notification)
        }
        .overlay(alignment: .leading) {
            if !notification.isRead {
                Capsule()
                    .fill(roleColor)
                    .frame(width: 4)
            }
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.date, relativeTo: Date())
    }
    
    private var roleColor: Color {
        notification.role.accentColor
    }
}

struct RoleSwitcherButton: View {
    let selectedRole: UserRole
    let action: () -> Void
    
    var body: some View {
        Menu {
            Button(role: .destructive) {
                action()
            } label: {
                Label("Switch Role", systemImage: "arrow.left")
            }
        } label: {
            Label(selectedRole.displayName, systemImage: selectedRole.systemImage)
                .labelStyle(.titleAndIcon)
        }
    }
}
