import SwiftUI

struct StudyHomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showNewStudySheet = false
    @State private var studyFormToken = UUID()

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
        .sheet(isPresented: $showNewStudySheet, onDismiss: { studyFormToken = UUID() }) {
            StudyDraftFormView(formID: studyFormToken) {
                showNewStudySheet = false
            }
            .environmentObject(viewModel)
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
    private var metadata: StudyMetadata {
        StudyMetadata.decode(from: study.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text((metadata.caseTitle?.isEmpty ?? true) ? study.examType : (metadata.caseTitle ?? study.examType))
                    .font(.headline)
                Spacer()
                StatusBadge(status: study.status)
            }
            if let urgency = metadata.urgency {
                Label(urgency.displayName, systemImage: "bolt.heart")
                    .font(.caption)
                    .padding(6)
                    .background(urgency.color.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(study.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let context = metadata.clinicalContext, !context.isEmpty {
                Text(context)
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

private struct StudyDraftFormView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let formID: UUID
    let onComplete: () -> Void

    @State private var title: String = ""
    @State private var module: UltrasoundModule = .cardiac
    @State private var urgency: CaseUrgency = .routine
    @State private var clinicalContext: String = ""
    @State private var patientAge: Int = 60
    @State private var patientGender: String = ""
    @State private var preliminaryFindings: String = ""
    @State private var attendingContact: String = ""
    @State private var measurements: [ClinicalDetail] = [
        ClinicalDetail(label: "EF %", value: ""),
        ClinicalDetail(label: "LVIDd", value: ""),
        ClinicalDetail(label: "TR Vmax", value: "")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Case Overview") {
                    TextField("Case Title", text: $title)
                    Picker("Ultrasound Module", selection: $module) {
                        ForEach(UltrasoundModule.allCases) { module in
                            Text(module.rawValue).tag(module)
                        }
                    }
                    Picker("Urgency", selection: $urgency) {
                        ForEach(CaseUrgency.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                Section("Patient Details") {
                    Stepper(value: $patientAge, in: 1...110) {
                        Text("Age: \(patientAge) years")
                    }
                    TextField("Gender", text: $patientGender)
                }

                Section("Clinical Context") {
                    TextEditor(text: $clinicalContext)
                        .frame(minHeight: 100)
                }

                Section("Preliminary Interpretation") {
                    TextEditor(text: $preliminaryFindings)
                        .frame(minHeight: 120)
                }

                Section("Measurements") {
                    ForEach(measurements.indices, id: \.self) { index in
                        HStack {
                            TextField("Label", text: $measurements[index].label)
                            Divider()
                            TextField("Value", text: $measurements[index].value)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Button("Add Measurement") {
                        measurements.append(ClinicalDetail(label: "", value: ""))
                    }
                }

                Section("Attending Contact") {
                    TextField("Assign to Attending (Email or Name)", text: $attendingContact)
                }
            }
            .navigationTitle("New Study")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let input = DraftStudyInput(
                                title: title,
                                module: module,
                                urgency: urgency,
                                clinicalContext: clinicalContext,
                                patientAge: patientAge,
                                patientGender: patientGender,
                                preliminaryFindings: preliminaryFindings,
                                measurements: measurements.filter { !$0.label.isEmpty || !$0.value.isEmpty },
                                attendingContact: attendingContact,
                                attendingId: nil
                            )
                            _ = await viewModel.createDraftStudy(input: input)
                            onComplete()
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
                }
            }
        }
        .id(formID)
    }
}

#Preview {
    StudyHomeView()
        .environmentObject(AppViewModel())
}
