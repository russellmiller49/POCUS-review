import SwiftUI

struct FeedbackComposer: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedStatus: FeedbackStatus = .accepted
    @State private var rating: Int = 4
    @State private var summary: String = ""
    @State private var comments: [String] = ["", "", ""]
    @State private var teachingPoints: [String] = ["", ""]
    @State private var includeResourceLink: Bool = false
    @State private var resourceURLString: String = "https://www.asecho.org/guidelines"
    @State private var annotationHighlights: [FeedbackAnnotation] = [
        .init(id: UUID(), title: "Optimize window", description: "Rotate probe clockwise to align LV axis.", color: .orange, mediaID: nil, timestamp: nil, points: [], annotatedImage: nil),
        .init(id: UUID(), title: "Measure TR jet", description: "Capture Doppler sweep for RVSP estimation.", color: .blue, mediaID: nil, timestamp: nil, points: [], annotatedImage: nil)
    ]
    @State private var showConfirmation = false
    
    private var targetCase: POCUSCase? {
        appState.selectedCase ?? appState.reviewQueue.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if let caseData = targetCase {
                    Section("Reviewing") {
                        Text(caseData.title)
                        Text("Fellow: \(caseData.fellow.name)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Decision") {
                    Picker("Status", selection: $selectedStatus) {
                        Text("Accept").tag(FeedbackStatus.accepted)
                        Text("Request revisions").tag(FeedbackStatus.revisionsRequested)
                        Text("Reject").tag(FeedbackStatus.rejected)
                    }
                    .pickerStyle(.segmented)
                    Stepper(value: $rating, in: 1...5) {
                        Label("Quality rating", systemImage: "star.fill")
                        Text("\(rating) / 5")
                    }
                }
                
                Section("Summary") {
                    TextField("Headline feedback", text: $summary, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Detailed comments") {
                    ForEach(comments.indices, id: \.self) { index in
                        TextField("Comment #\(index + 1)", text: $comments[index])
                    }
                    Button("Add comment") {
                        comments.append("")
                    }
                }
                
                Section("Teaching points") {
                    ForEach(teachingPoints.indices, id: \.self) { index in
                        TextField("Point #\(index + 1)", text: $teachingPoints[index])
                    }
                    Button("Add teaching point") {
                        teachingPoints.append("")
                    }
                }
                
                Section("Resources & annotations") {
                    Toggle("Attach quick reference link", isOn: $includeResourceLink.animation())
                    if includeResourceLink {
                        TextField("Resource URL", text: $resourceURLString)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Annotation highlights")
                            .font(.subheadline.weight(.semibold))
                        ForEach(annotationHighlights) { annotation in
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(annotation.color)
                                    .frame(width: 14, height: 14)
                                Text(annotation.title)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Compose Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissComposer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { submitFeedback() }
                        .disabled(targetCase == nil || summary.isEmpty)
                }
            }
            .alert("Feedback sent", isPresented: $showConfirmation) {
                Button("Done") { dismissComposer() }
            } message: {
                Text("The fellow will receive your comments and annotations immediately.")
            }
        }
    }
    
    private func submitFeedback() {
        guard let caseData = targetCase, let attending = appState.selectedAttending else { return }
        let filteredComments = comments.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let filteredTeachingPoints = teachingPoints.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let resources: [URL] = includeResourceLink ? [URL(string: resourceURLString)].compactMap { $0 } : []
        let feedback = CaseFeedback(
            id: UUID(),
            attending: attending,
            status: selectedStatus,
            qualityRating: rating,
            summary: summary,
            detailedComments: filteredComments,
            annotations: annotationHighlights,
            teachingPoints: filteredTeachingPoints,
            recommendedResources: resources,
            createdAt: Date()
        )
        appState.applyFeedback(feedback, to: caseData.id, newStatus: mappedCaseStatus())
        showConfirmation = true
    }
    
    private func mappedCaseStatus() -> CaseStatus {
        switch selectedStatus {
        case .accepted:
            return .accepted
        case .revisionsRequested:
            return .needsRevision
        case .rejected:
            return .reviewed
        }
    }
    
    private func dismissComposer() {
        appState.showFeedbackComposer = false
        dismiss()
    }
}
