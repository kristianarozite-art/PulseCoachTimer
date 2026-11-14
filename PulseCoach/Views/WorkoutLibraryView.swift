import SwiftUI

private struct EditorSheetContext: Identifiable {
    let id = UUID()
    let workout: Workout
    let isNew: Bool
}

public struct WorkoutLibraryView: View {
    @State private var store = WorkoutStore()
    @State private var activeWorkout: Workout?
    @State private var editorContext: EditorSheetContext?
    @State private var workoutPendingDelete: Workout?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.06)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if store.workouts.isEmpty {
                            emptyStateView
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(store.workouts) { workout in
                                    WorkoutRowView(
                                        workout: workout,
                                        onStart: {
                                            activeWorkout = workout
                                        },
                                        onEdit: {
                                            editorContext = EditorSheetContext(workout: workout, isNew: false)
                                        },
                                        onDuplicate: {
                                            let duplicateCopy = store.duplicate(workout)
                                            editorContext = EditorSheetContext(workout: duplicateCopy, isNew: false)
                                        },
                                        onDelete: {
                                            workoutPendingDelete = workout
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("PulseCoach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let newDraft = store.makeNewDraftWorkout()
                        editorContext = EditorSheetContext(workout: newDraft, isNew: true)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("New Workout")
                }
            }
            .sheet(item: $editorContext) { context in
                WorkoutEditorView(
                    workout: context.workout,
                    isNew: context.isNew
                ) { savedWorkout in
                    if context.isNew {
                        store.add(savedWorkout)
                    } else {
                        store.update(savedWorkout)
                    }
                }
            }
            .fullScreenCover(item: $activeWorkout) { workout in
                ActiveTimerView(workout: workout)
            }
            .alert(
                "Delete Workout?",
                isPresented: Binding(
                    get: { workoutPendingDelete != nil },
                    set: { if !$0 { workoutPendingDelete = nil } }
                ),
                presenting: workoutPendingDelete
            ) { workout in
                Button("Delete \"\(workout.name)\"", role: .destructive) {
                    store.delete(workout)
                    workoutPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    workoutPendingDelete = nil
                }
            } message: { workout in
                Text("Are you sure you want to delete \"\(workout.name)\"? This action cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.highintensity.intervaltraining")
                .font(.system(size: 46))
                .foregroundStyle(.white.opacity(0.4))

            Text("No Saved Workouts")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(.white)

            Text("Tap the \"+\" button in the top-right corner to create your first custom interval timer.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
