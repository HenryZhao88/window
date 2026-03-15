import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var difficulty: Double = 0.5
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var estimatedMinutes = 30

    var body: some View {
        NavigationStack {
            Form {
                Section("Task name") {
                    TextField("e.g. Study for Calc exam", text: $name)
                        .autocorrectionDisabled()
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Difficulty")
                            Spacer()
                            Text(difficultyLabel)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $difficulty, in: 0...1)
                            .tint(difficultyColor)
                    }

                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)

                    Stepper(
                        "Est. time: \(estimatedMinutes < 60 ? "\(estimatedMinutes) min" : "\(estimatedMinutes / 60)h \(estimatedMinutes % 60 > 0 ? "\(estimatedMinutes % 60)m" : "")")",
                        value: $estimatedMinutes,
                        in: 5...480,
                        step: 5
                    )
                } header: {
                    Text("Details")
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { saveTask() }
                        .bold()
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var difficultyLabel: String {
        switch difficulty {
        case ..<0.33: return "Easy"
        case 0.33..<0.66: return "Medium"
        default: return "Hard"
        }
    }

    private var difficultyColor: Color {
        switch difficulty {
        case ..<0.33: return .green
        case 0.33..<0.66: return .yellow
        default: return .red
        }
    }

    private func saveTask() {
        let task = WindowTask(
            name: name.trimmingCharacters(in: .whitespaces),
            difficulty: difficulty,
            deadline: deadline,
            estimatedMinutes: estimatedMinutes
        )
        modelContext.insert(task)
        dismiss()
    }
}
