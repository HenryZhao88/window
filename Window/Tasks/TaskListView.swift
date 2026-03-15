import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WindowTask.deadline) private var tasks: [WindowTask]
    @State private var showingAdd = false

    private var pending: [WindowTask] { tasks.filter { !$0.isCompleted } }
    private var completed: [WindowTask] { tasks.filter { $0.isCompleted } }

    var body: some View {
        NavigationStack {
            List {
                if pending.isEmpty && completed.isEmpty {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "checklist",
                        description: Text("Tap + to add something to work on.")
                    )
                    .listRowBackground(Color.clear)
                }

                if !pending.isEmpty {
                    Section("Pending") {
                        ForEach(pending) { task in
                            TaskRow(task: task)
                        }
                        .onDelete { offsets in deleteTasks(pending, at: offsets) }
                    }
                }

                if !completed.isEmpty {
                    Section("Completed") {
                        ForEach(completed) { task in
                            TaskRow(task: task)
                        }
                        .onDelete { offsets in deleteTasks(completed, at: offsets) }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddTaskView()
            }
        }
    }

    private func deleteTasks(_ list: [WindowTask], at offsets: IndexSet) {
        for i in offsets { modelContext.delete(list[i]) }
    }
}

struct TaskRow: View {
    let task: WindowTask

    var body: some View {
        HStack(spacing: 12) {
            Button { toggleComplete() } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 10) {
                    Label("\(task.estimatedMinutes)m", systemImage: "clock")
                    Label(task.deadline.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(difficultyColor)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 2)
    }

    private func toggleComplete() {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
    }

    private var difficultyColor: Color {
        switch task.difficulty {
        case ..<0.4: return .green
        case 0.4..<0.7: return .yellow
        default: return .red
        }
    }
}
