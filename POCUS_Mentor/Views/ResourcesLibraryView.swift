import SwiftUI

struct ResourcesLibraryView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List {
            Section("Curated Guides") {
                ForEach(appState.resourceLinks) { resource in
                    ResourceLinkRow(resource: resource)
                }
            }
            
            Section("Video Tutorials") {
                Label("Apical view optimization", systemImage: "play.circle")
                Label("Doppler measurement refresher", systemImage: "play.circle")
                Label("Rapid lung ultrasound protocol", systemImage: "play.circle")
            }
            
            Section("Help & Support") {
                Label("FAQ", systemImage: "questionmark.circle")
                Label("Chat with support", systemImage: "message")
                Label("Report an issue", systemImage: "exclamationmark.bubble")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Resource Library")
    }
}

private struct ResourceLinkRow: View {
    let resource: ResourceLink
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(resource.title)
                .font(.headline)
            Text(resource.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(resource.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 8)
    }
}
