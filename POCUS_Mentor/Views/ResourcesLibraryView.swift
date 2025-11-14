import SwiftUI

struct ResourcesLibraryView: View {
    private let curatedResources = ResourceLink.curatedExamples
    
    var body: some View {
        List {
            Section("Curated Guides") {
                ForEach(curatedResources) { resource in
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

extension ResourceLink {
    static let curatedExamples: [ResourceLink] = [
        ResourceLink(
            title: "ASE Echocardiography Guide",
            description: "Acquisition standards and interpretation pearls.",
            url: URL(string: "https://www.asecho.org")!
        ),
        ResourceLink(
            title: "POCUS Teaching Checklist",
            description: "Self-review checklist before submitting a case.",
            url: URL(string: "https://example.com/pocus-checklist")!
        ),
        ResourceLink(
            title: "Rapid Clip Optimization",
            description: "Video walkthrough covering gain, depth, and sweep tips.",
            url: URL(string: "https://example.com/clip-optimization")!
        )
    ]
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
