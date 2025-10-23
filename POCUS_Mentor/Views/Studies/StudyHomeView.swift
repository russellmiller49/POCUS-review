import SwiftUI

struct StudyHomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showNewStudySheet = false
    @State private var newExamType = ""
    @State private var newNotes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Studies")
                    .font(.largeTitle.bold())
                Spacer()
                Button(action: { showNewStudySheet = true }) {
                    Label("New Study", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Picker("Filter", selection: $viewModel.filter) {
                ForEach(AppViewModel.StudyFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.isBusy && viewModel.filteredStudies.isEmpty {
                ProgressView("Loading studies…")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.filteredStudies.isEmpty {
                ContentUnavailableView(
                    "No studies",
                    systemImage: "tray",
                    description: Text("Create a new study to begin uploading de-identified media.")
                )
            } else {
                List(viewModel.filteredStudies, id: \.id) { study in
                    Button {
                        Task {
                            await viewModel.loadStudyDetail(for: study)
                        }
                    } label: {
                        StudyRow(study: study)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.vertical)
        .sheet(item: Binding(
            get: { viewModel.studyDetail },
            set: { newValue in
                if newValue == nil { viewModel.dismissStudyDetail() }
            })
        ) { detail in
            StudyDetailView(detail: detail)
        }
        .sheet(isPresented: $showNewStudySheet) {
            NavigationStack {
                Form {
                    Section("Exam Type") {
                        TextField("e.g. Focused Cardiac", text: $newExamType)
                    }
                    Section("Notes") {
                        TextEditor(text: $newNotes)
                            .frame(height: 120)
                    }
                }
                .navigationTitle("New Study")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showNewStudySheet = false
                            newExamType = ""
                            newNotes = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            Task {
                                await viewModel.createDraftStudy(examType: newExamType, notes: newNotes)
                                newExamType = ""
                                newNotes = ""
                                showNewStudySheet = false
                            }
                        }
                        .disabled(newExamType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            if viewModel.filteredStudies.isEmpty {
                await viewModel.refreshStudies()
            }
        }
    }
}

private struct StudyRow: View {
    let study: Study

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(study.examType)
                    .font(.headline)
                Spacer()
                StatusBadge(status: study.status)
            }
            Text(study.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let notes = study.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct StatusBadge: View {
    let status: StudyStatus

    var body: some View {
        Text(status.rawValue.capitalized.replacingOccurrences(of: "_", with: " "))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .draft: return .gray
        case .submitted: return .blue
        case .reviewable: return .orange
        case .needsRevision: return .pink
        case .approved: return .green
        case .signedOff: return .teal
        }
    }
}

#Preview {
    StudyHomeView()
        .environmentObject(AppViewModel())
}
