import SwiftUI

struct EchoMediaUploadView: View {
    @Binding var media: [CaseMedia]
    @State private var selectedCategory: String = "Parasternal Long Axis"
    @State private var showAllViews = false

    private let categories = ["Parasternal Long Axis", "Parasternal Short Axis", "Apical", "Subcostal", "Suprasternal"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Echo Views")
                    .font(.headline)
                Spacer()
                Text("\(media.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Category Picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.segmented)

            // Media Drop Zones
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewsForSelectedCategory, id: \.id) { echoView in
                        MediaDropZone(echoView: echoView, media: $media)
                    }
                }
            }

            // Summary Footer
            if !media.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    HStack {
                        Label("\(imageCount) images", systemImage: "photo")
                            .font(.caption)
                        Spacer()
                        Label("\(videoCount) videos", systemImage: "video")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var viewsForSelectedCategory: [EchoView] {
        EchoView.allCases.filter { $0.category == selectedCategory }
    }

    private var imageCount: Int {
        media.filter { $0.type == .image }.count
    }

    private var videoCount: Int {
        media.filter { $0.type == .video }.count
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var media: [CaseMedia] = [
            .init(id: UUID(), title: "Test", type: .image, thumbnailName: "photo", description: "", echoView: .apical4Chamber, fileURL: nil)
        ]

        var body: some View {
            EchoMediaUploadView(media: $media)
                .padding()
        }
    }

    return PreviewWrapper()
}
