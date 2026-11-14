import SwiftUI

public struct WorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Workout
    public let isNew: Bool
    public let onSave: (Workout) -> Void

    public init(
        workout: Workout,
        isNew: Bool,
        onSave: @escaping (Workout) -> Void
    ) {
        self._draft = State(initialValue: workout)
        self.isNew = isNew
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Live Summary Header Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated Workout Time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(draft.formattedTotalDuration)
                                .font(.system(size: 30, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(draft.exerciseCount) Exercises × \(draft.repsPerExercise) Reps")
                                .font(.subheadline.weight(.semibold))
                            Text("\(draft.exerciseCount * draft.repsPerExercise) total work sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Workout Identity
                Section("Workout Name") {
                    TextField("e.g. Full Body 45/15", text: $draft.name)
                        .font(.headline)
                        .submitLabel(.done)
                }

                // Structure: Exercises & Reps
                Section("Structure") {
                    counterControlRow(
                        title: "Number of Exercises",
                        value: $draft.exerciseCount,
                        range: 1...50,
                        unit: ""
                    )

                    counterControlRow(
                        title: "Reps / Sets per Exercise",
                        value: $draft.repsPerExercise,
                        range: 1...30,
                        unit: ""
                    )
                }

                // Phase Durations
                Section("Phase Durations") {
                    durationControlRow(
                        title: "Get Ready",
                        subtitle: "Initial countdown before Exercise 1",
                        color: Color(red: 1.0, green: 0.84, blue: 0.15),
                        value: $draft.getReadyDuration,
                        range: 0...120
                    )

                    durationControlRow(
                        title: "Work",
                        subtitle: "Active effort interval",
                        color: Color(red: 1.0, green: 0.23, blue: 0.19),
                        value: $draft.workDuration,
                        range: 5...600
                    )

                    durationControlRow(
                        title: "Standard Rest",
                        subtitle: "Rest between reps of the same exercise",
                        color: Color(red: 0.19, green: 0.82, blue: 0.35),
                        value: $draft.restDuration,
                        range: 0...300
                    )
                }

                // Custom Transition / Long Rest
                Section {
                    Toggle(isOn: $draft.enableTransitionRest.animation(.easeInOut(duration: 0.2))) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Long Rest Between Exercises")
                                .font(.body.weight(.medium))
                            Text("Replaces standard rest after final rep of each exercise")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if draft.enableTransitionRest {
                        durationControlRow(
                            title: "Transition Rest",
                            subtitle: "Single continuous rest before next exercise",
                            color: Color(red: 0.04, green: 0.52, blue: 1.0),
                            value: $draft.transitionRestDuration,
                            range: 5...600
                        )
                    }
                } header: {
                    Text("Transition / Long Rest")
                } footer: {
                    Text("When enabled, after the final rep of an exercise (e.g. Rep \(draft.repsPerExercise) of \(draft.repsPerExercise)), standard rest is replaced by one continuous Transition Rest. After the final rep of Exercise \(draft.exerciseCount), the workout finishes immediately with no rest.")
                }

                // Audio & Spotify Settings
                Section("Audio Cues & Spotify") {
                    Picker("Cue Type", selection: $draft.cueType) {
                        ForEach(CueType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if draft.cueType == .soundEffects {
                        Picker("Sound Effect Style", selection: $draft.soundEffectStyle) {
                            ForEach(SoundEffectStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                    }

                    Picker("Countdown Mode", selection: $draft.countdownMode) {
                        ForEach(CountdownMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Picker("Spotify Audio Behavior", selection: $draft.spotifyBehavior) {
                        ForEach(SpotifyAudioBehavior.allCases) { behavior in
                            Text(behavior.rawValue).tag(behavior)
                        }
                    }

                    Text(draft.spotifyBehavior.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Cue Volume", systemImage: "speaker.wave.3.fill")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(Int(round(draft.cueVolume * 100)))%")
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $draft.cueVolume, in: 0.1...1.0, step: 0.05)
                    }
                    .padding(.vertical, 4)

                    Button {
                        AudioEngine.shared.previewCue(for: draft)
                    } label: {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                            Text("Test Audio Cue")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var cleaned = draft
                        let trimmed = cleaned.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            cleaned.name = "Untitled Workout"
                        } else {
                            cleaned.name = trimmed
                        }
                        onSave(cleaned)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helper Subviews

    private func counterControlRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            HStack(spacing: 12) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value.wrappedValue > range.lowerBound ? .white : .gray.opacity(0.4))
                }
                .buttonStyle(.plain)

                Text("\(value.wrappedValue)\(unit)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .frame(minWidth: 38, alignment: .center)

                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(value.wrappedValue < range.upperBound ? .white : .gray.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private func durationControlRow(
        title: String,
        subtitle: String,
        color: Color,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(value.wrappedValue)s")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            HStack(spacing: 10) {
                quickStepButton(label: "-10s", delta: -10, value: value, range: range)
                quickStepButton(label: "-5s", delta: -5, value: value, range: range)
                Spacer()
                quickStepButton(label: "+5s", delta: 5, value: value, range: range)
                quickStepButton(label: "+10s", delta: 10, value: value, range: range)
            }
        }
        .padding(.vertical, 4)
    }

    private func quickStepButton(
        label: String,
        delta: Int,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        Button {
            let updated = value.wrappedValue + delta
            value.wrappedValue = min(range.upperBound, max(range.lowerBound, updated))
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 52)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
