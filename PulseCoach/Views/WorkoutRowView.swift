import SwiftUI

public struct WorkoutRowView: View {
    public let workout: Workout
    public let onStart: () -> Void
    public let onEdit: () -> Void
    public let onDuplicate: () -> Void
    public let onDelete: () -> Void

    public init(
        workout: Workout,
        onStart: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.workout = workout
        self.onStart = onStart
        self.onEdit = onEdit
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Name + Total Time
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(workout.exerciseCount) Exercises • \(workout.repsPerExercise) Reps each")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.68))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    Text(workout.formattedTotalDuration)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08), in: Capsule())
            }

            // Interval Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    intervalTag(
                        label: "Work \(workout.workDuration)s",
                        color: Color(red: 1.0, green: 0.23, blue: 0.19)
                    )
                    intervalTag(
                        label: "Rest \(workout.restDuration)s",
                        color: Color(red: 0.19, green: 0.82, blue: 0.35)
                    )
                    if workout.enableTransitionRest && workout.transitionRestDuration > 0 {
                        intervalTag(
                            label: "Transition \(workout.transitionRestDuration)s",
                            color: Color(red: 0.04, green: 0.52, blue: 1.0)
                        )
                    }
                    if workout.getReadyDuration > 0 {
                        intervalTag(
                            label: "Prep \(workout.getReadyDuration)s",
                            color: Color(red: 1.0, green: 0.84, blue: 0.15)
                        )
                    }
                    intervalTag(
                        label: workout.cueType == .studioVoice ? "Voice" : workout.soundEffectStyle.rawValue,
                        color: Color.white.opacity(0.75)
                    )
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.1))

            // Action Bar: Start, Edit, Duplicate, Delete
            HStack(spacing: 10) {
                Button(action: onStart) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Start")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.19, green: 0.82, blue: 0.35), in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                actionIconButton(icon: "pencil", label: "Edit", tint: .white, action: onEdit)
                actionIconButton(icon: "plus.square.on.square", label: "Duplicate", tint: Color(red: 0.04, green: 0.52, blue: 1.0), action: onDuplicate)
                actionIconButton(icon: "trash", label: "Delete", tint: Color(red: 1.0, green: 0.27, blue: 0.23), action: onDelete)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func intervalTag(label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private func actionIconButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
