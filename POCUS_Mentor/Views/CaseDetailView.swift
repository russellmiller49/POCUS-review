import SwiftUI
import AVKit

struct CaseDetailView: View {
    let caseData: POCUSCase
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                overviewSection
                timelineSection
                mediaSection
                qualityChecklistSection
                measurementsSection
                feedbackSection
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(caseData.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Clinical Summary", subtitle: "Study context and preliminary interpretation.")
            Label(caseData.studyType, systemImage: "stethoscope")
                .font(.subheadline)
            LabeledContent("Fellow") {
                Text(caseData.fellow.name)
            }
            LabeledContent("Attending") {
                Text(caseData.assignedAttending.name)
            }
            LabeledContent("Urgency") {
                Text(caseData.urgency.displayName)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(caseData.urgency.color.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text("Clinical Indication")
                .font(.headline)
            Text(caseData.clinicalIndication)
                .font(.subheadline)
            Text("Preliminary Findings")
                .font(.headline)
            Text(caseData.preliminaryFindings)
                .font(.subheadline)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Case Timeline", subtitle: "Key events from submission to feedback.")
            ForEach(caseData.timeline) { entry in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: entry.icon)
                        .font(.callout)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.action)
                            .font(.subheadline.weight(.semibold))
                        Text(entry.actorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(dateFormatter.string(from: entry.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 2)
                        .offset(x: -18)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
    
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Image & Video Review", subtitle: "Annotated media submitted with the case.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(caseData.media) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        PlaceholderMediaView(media: item)
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text(item.title)
                            .font(.headline)
                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                    )
                }
            }
        }
    }
    
    private var qualityChecklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quality Checklist", subtitle: "Acquisition standards required for acceptance.")
            ForEach(caseData.qualityChecklist) { item in
                HStack {
                    Image(systemName: item.isMet ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(item.isMet ? .green : .orange)
                    Text(item.title)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
    
    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Measurements & Documentation")
            ForEach(caseData.measurements) { measurement in
                LabeledContent(measurement.label) {
                    Text(measurement.value)
                        .font(.body.monospacedDigit())
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
    
    private var feedbackSection: some View {
        Group {
            if let feedback = caseData.feedback {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Attending Feedback", subtitle: "Structured response with annotations and teaching pearls.")
                    FeedbackSummaryCard(caseData: caseData)
                    FeedbackDetailView(feedback: feedback)
                }
            } else {
                EmptyPlaceholderView(title: "Awaiting Feedback", message: "Attendings will add annotations, quality rating, and acceptance decision here once review is complete.", systemImage: "hourglass")
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

private struct PlaceholderMediaView: View {
    let media: CaseMedia
    @State private var showFullScreen = false

    var body: some View {
        Group {
            if media.type == .video, let url = media.fileURL {
                VideoPlayerView(url: url)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFullScreen = true
                    }
            } else {
                // Placeholder for images or videos without URLs
                ZStack {
                    LinearGradient(colors: [.black.opacity(0.8), .gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 10) {
                        Image(systemName: media.type == .image ? "photo" : "play.circle")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                        Text(media.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let url = media.fileURL {
                NavigationStack {
                    VideoPlayer(player: AVPlayer(url: url))
                        .navigationTitle(media.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showFullScreen = false
                                }
                            }
                        }
                        .ignoresSafeArea()
                }
            }
        }
    }
}

private struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                ZStack {
                    Color.black
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
