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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(workout.exerciseCount) Exercises • \(workout.repsPerExercise) Reps each")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    Text(workout.formattedTotalDuration)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08), in: Capsule())
            }

            // Middle Horizontally Scrollable Metadata Pills
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

            // Single-Line Action Bar: Start, Edit, Copy, Delete
            HStack(spacing: 8) {
                Button(action: onStart) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start")
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color(red: 0.19, green: 0.82, blue: 0.35), in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                actionPillButton(
                    icon: "pencil",
                    label: "Edit",
                    tint: .white,
                    action: onEdit
                )

                actionPillButton(
                    icon: "doc.on.doc",
                    label: "Copy",
                    tint: Color(red: 0.04, green: 0.52, blue: 1.0),
                    action: onDuplicate
                )

                actionPillButton(
                    icon: "trash",
                    label: "Delete",
                    tint: Color(red: 1.0, green: 0.27, blue: 0.23),
                    action: onDelete
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private func actionPillButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
