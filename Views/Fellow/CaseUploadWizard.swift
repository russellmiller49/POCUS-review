import SwiftUI

struct CaseUploadWizard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var caseTitle: String = ""
    @State private var clinicalContext: String = ""
    @State private var urgency: CaseUrgency = .routine
    @State private var patientAge: Int = 60
    @State private var patientGender: String = "Female"
    @State private var preliminaryFindings: String = ""
    @State private var measurements: [ClinicalDetail] = [
        .init(label: "EF %", value: ""),
        .init(label: "LVIDd", value: ""),
        .init(label: "TR Vmax", value: "")
    ]
    @State private var uploadedMedia: [CaseMedia] = []
    @State private var selectedAttending: Attending?
    @State private var selectedModule: UltrasoundModule = .cardiac
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Case Overview") {
                    TextField("Case Title", text: $caseTitle)

                    Picker("Ultrasound Module", selection: $selectedModule) {
                        ForEach(UltrasoundModule.allCases) { module in
                            HStack {
                                Circle()
                                    .fill(module.color)
                                    .frame(width: 12, height: 12)
                                Text(module.rawValue)
                            }
                            .tag(module)
                        }
                    }

                    Picker("Urgency", selection: $urgency) {
                        ForEach(CaseUrgency.allCases) { urgency in
                            Text(urgency.displayName).tag(urgency)
                        }
                    }

                    Picker("Fellow", selection: selectedFellowBinding) {
                        ForEach(appState.fellows) { fellow in
                            Text(fellow.name).tag(fellow as Fellow?)
                        }
                    }

                    Picker("Assign to Attending", selection: $selectedAttending) {
                        Text("Select Attending").tag(nil as Attending?)
                        ForEach(appState.attendings) { attending in
                            Text(attending.name).tag(attending as Attending?)
                        }
                    }
                }
                
                Section("Patient Details") {
                    Stepper(value: $patientAge, in: 1...110) {
                        Text("Age: \(patientAge) years")
                    }
                    TextField("Gender", text: $patientGender)
                    TextField("Clinical Context", text: $clinicalContext, axis: .vertical)
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
                        measurements.append(.init(label: "", value: ""))
                    }
                }
                
                Section {
                    ModuleMediaUploadView(module: selectedModule, media: $uploadedMedia)
                } header: {
                    HStack {
                        Text("\(selectedModule.rawValue) - Required Views")
                        Spacer()
                        Text("\(uploadedMedia.filter { $0.isRequired }.count)/\(selectedModule.requiredViews.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Upload Guidelines") {
                    Label("Capture high quality images for each view", systemImage: "photo")
                    Label("Include Doppler sweeps where relevant", systemImage: "waveform")
                    Label("Attach video loops for dynamic findings", systemImage: "play.rectangle")
                    Label("Organize media by standard echo views", systemImage: "square.grid.2x2")
                }
            }
            .navigationTitle("New Case Submission")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        submitCase()
                    }
                    .disabled(caseTitle.isEmpty || selectedAttending == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Case submitted", isPresented: $showConfirmation) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your case has been assigned to \(selectedAttending?.name ?? "an attending") for review. You'll be notified when feedback is available.")
            }
        }
    }
    
    private var selectedFellowBinding: Binding<Fellow?> {
        Binding {
            appState.selectedFellow
        } set: { newValue in
            appState.selectedFellow = newValue
        }
    }

    private func submitCase() {
        guard let fellow = appState.selectedFellow,
              let attending = selectedAttending else { return }

        let newCase = POCUSCase(
            id: UUID(),
            title: caseTitle,
            studyType: selectedModule.rawValue,
            ultrasoundModule: selectedModule,
            patientAge: patientAge,
            patientGender: patientGender,
            clinicalIndication: clinicalContext,
            urgency: urgency,
            submittedAt: Date(),
            status: .submitted,
            fellow: fellow,
            assignedAttending: attending,
            preliminaryFindings: preliminaryFindings,
            measurements: measurements.filter { !$0.label.isEmpty || !$0.value.isEmpty },
            media: uploadedMedia,
            feedback: nil,
            timeline: [
                .init(date: Date(), actorName: fellow.name, action: "Submitted case", icon: "square.and.arrow.up")
            ],
            qualityChecklist: [],
            tags: [selectedModule.rawValue, "Critical Care Ultrasound"]
        )

        appState.addCase(newCase)
        showConfirmation = true
    }
}

#Preview {
    CaseUploadWizard()
        .environmentObject(AppState())
}
