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
                    VStack(alignment: .leading, spacing: 16) {
                        headerBanner

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
                    .padding(.bottom, 100)
                }

                // Bottom Floating "+ New Workout" Button
                VStack {
                    Spacer()
                    Button {
                        let newDraft = store.makeNewDraftWorkout()
                        editorContext = EditorSheetContext(workout: newDraft, isNew: true)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .bold))
                            Text("New Workout")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.84, blue: 0.15))
                                .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("PulseCoach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let newDraft = store.makeNewDraftWorkout()
                        editorContext = EditorSheetContext(workout: newDraft, isNew: true)
                    } label: {
                        Label("New Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                    }
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

    private var headerBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.23, blue: 0.19).opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.19))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Trainer Interval Presets")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Spotify-friendly cues • Background lock-screen ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.highintensity.intervaltraining")
                .font(.system(size: 46))
                .foregroundStyle(.white.opacity(0.4))

            Text("No Saved Workouts")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Tap \"+ New Workout\" below to create your first custom interval timer.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
