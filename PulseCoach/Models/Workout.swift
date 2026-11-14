import Foundation

public enum CueType: String, Codable, CaseIterable, Identifiable, Sendable {
    case studioVoice = "Studio Voice"
    case soundEffects = "Sound Effects"

    public var id: String { rawValue }
}

public enum SoundEffectStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case beep = "Beep"
    case whistle = "Whistle"
    case ring = "Ring"
    case gong = "Gong"
    case chime = "Calm Chime"

    public var id: String { rawValue }

    public var workSoundResourceName: String {
        switch self {
        case .beep: return "sfx_beep_work"
        case .whistle: return "sfx_whistle_work"
        case .ring: return "sfx_ring_work"
        case .gong: return "sfx_gong_work"
        case .chime: return "sfx_chime_work"
        }
    }

    public var restSoundResourceName: String {
        switch self {
        case .beep: return "sfx_beep_rest"
        case .whistle: return "sfx_whistle_rest"
        case .ring: return "sfx_ring_rest"
        case .gong: return "sfx_gong_rest"
        case .chime: return "sfx_chime_rest"
        }
    }
}

public enum CountdownMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case startOnly = "Start of phase only"
    case threeTwoOne = "3-2-1 Countdown + Start"

    public var id: String { rawValue }
}

public enum SpotifyAudioBehavior: String, Codable, CaseIterable, Identifiable, Sendable {
    case mix = "Mix with Spotify"
    case duck = "Duck Spotify"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .mix:
            return "Music continues at normal volume alongside cues"
        case .duck:
            return "Temporarily lowers Spotify volume during cues"
        }
    }
}

public struct Workout: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var getReadyDuration: Int
    public var workDuration: Int
    public var restDuration: Int
    public var exerciseCount: Int
    public var repsPerExercise: Int
    public var enableTransitionRest: Bool
    public var transitionRestDuration: Int

    // Audio & Spotify Settings
    public var cueType: CueType
    public var soundEffectStyle: SoundEffectStyle
    public var countdownMode: CountdownMode
    public var spotifyBehavior: SpotifyAudioBehavior
    public var cueVolume: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        getReadyDuration: Int = 10,
        workDuration: Int = 45,
        restDuration: Int = 15,
        exerciseCount: Int = 5,
        repsPerExercise: Int = 3,
        enableTransitionRest: Bool = true,
        transitionRestDuration: Int = 30,
        cueType: CueType = .studioVoice,
        soundEffectStyle: SoundEffectStyle = .beep,
        countdownMode: CountdownMode = .threeTwoOne,
        spotifyBehavior: SpotifyAudioBehavior = .mix,
        cueVolume: Double = 0.85,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.getReadyDuration = max(0, getReadyDuration)
        self.workDuration = max(1, workDuration)
        self.restDuration = max(0, restDuration)
        self.exerciseCount = max(1, exerciseCount)
        self.repsPerExercise = max(1, repsPerExercise)
        self.enableTransitionRest = enableTransitionRest
        self.transitionRestDuration = max(0, transitionRestDuration)
        self.cueType = cueType
        self.soundEffectStyle = soundEffectStyle
        self.countdownMode = countdownMode
        self.spotifyBehavior = spotifyBehavior
        self.cueVolume = min(1.0, max(0.1, cueVolume))
        self.createdAt = createdAt
    }

    public func buildPhases() -> [WorkoutPhaseStep] {
        var phases: [WorkoutPhaseStep] = []

        let totalEx = max(1, exerciseCount)
        let totalReps = max(1, repsPerExercise)

        if getReadyDuration > 0 {
            phases.append(
                WorkoutPhaseStep(
                    type: .getReady,
                    duration: TimeInterval(getReadyDuration),
                    exerciseIndex: 1,
                    totalExercises: totalEx,
                    repIndex: 1,
                    totalReps: totalReps
                )
            )
        }

        for ex in 1...totalEx {
            for rep in 1...totalReps {
                phases.append(
                    WorkoutPhaseStep(
                        type: .work,
                        duration: TimeInterval(max(1, workDuration)),
                        exerciseIndex: ex,
                        totalExercises: totalEx,
                        repIndex: rep,
                        totalReps: totalReps
                    )
                )

                let isLastExercise = (ex == totalEx)
                let isLastRepOfExercise = (rep == totalReps)

                // After the final rep of the VERY LAST exercise, there must be NO rest at all.
                if isLastExercise && isLastRepOfExercise {
                    continue
                }

                if isLastRepOfExercise {
                    // Between exercises: replace standard rest with Transition (Long) Rest if enabled
                    if enableTransitionRest {
                        if transitionRestDuration > 0 {
                            phases.append(
                                WorkoutPhaseStep(
                                    type: .transitionRest,
                                    duration: TimeInterval(transitionRestDuration),
                                    exerciseIndex: ex,
                                    totalExercises: totalEx,
                                    repIndex: rep,
                                    totalReps: totalReps
                                )
                            )
                        }
                    } else if restDuration > 0 {
                        phases.append(
                            WorkoutPhaseStep(
                                type: .rest,
                                duration: TimeInterval(restDuration),
                                exerciseIndex: ex,
                                totalExercises: totalEx,
                                repIndex: rep,
                                totalReps: totalReps
                            )
                        )
                    }
                } else {
                    // Standard rest between reps of the same exercise
                    if restDuration > 0 {
                        phases.append(
                            WorkoutPhaseStep(
                                type: .rest,
                                duration: TimeInterval(restDuration),
                                exerciseIndex: ex,
                                totalExercises: totalEx,
                                repIndex: rep,
                                totalReps: totalReps
                            )
                        )
                    }
                }
            }
        }

        return phases
    }

    public var totalDurationSeconds: Int {
        Int(buildPhases().reduce(0) { $0 + $1.duration })
    }

    public var formattedTotalDuration: String {
        Self.formatMMSS(totalDurationSeconds)
    }

    public func duplicated() -> Workout {
        var copy = self
        copy.id = UUID()
        copy.name = "\(name) Copy"
        copy.createdAt = Date()
        return copy
    }

    public static func formatMMSS(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public static let sampleFullBody = Workout(
        name: "Full Body 45/15",
        getReadyDuration: 10,
        workDuration: 45,
        restDuration: 15,
        exerciseCount: 5,
        repsPerExercise: 3,
        enableTransitionRest: true,
        transitionRestDuration: 30,
        cueType: .studioVoice,
        soundEffectStyle: .beep,
        countdownMode: .threeTwoOne,
        spotifyBehavior: .mix,
        cueVolume: 0.85
    )
}
