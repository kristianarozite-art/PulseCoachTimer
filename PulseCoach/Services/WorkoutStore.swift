import Foundation
import Observation

@MainActor
@Observable
public final class WorkoutStore {
    public private(set) var workouts: [Workout] = []

    private let fileName = "pulsecoach_workouts.json"
    private let seededKey = "pulsecoach.hasSeededSampleWorkout.v1"
    private let defaultsKeyPrefix = "pulsecoach.audioDefaults."

    public init() {
        loadWorkouts()
    }

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent(fileName)
    }

    public func loadWorkouts() {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode([Workout].self, from: data)
                self.workouts = decoded
                return
            } catch {
                print("[WorkoutStore] Failed to decode workouts JSON: \(error)")
            }
        }

        let hasSeeded = UserDefaults.standard.bool(forKey: seededKey)
        if !hasSeeded {
            self.workouts = [Workout.sampleFullBody]
            UserDefaults.standard.set(true, forKey: seededKey)
            saveWorkouts()
        }
    }

    public func saveWorkouts() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(workouts)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("[WorkoutStore] Failed to save workouts JSON: \(error)")
        }
    }

    public func add(_ workout: Workout) {
        workouts.insert(workout, at: 0)
        saveAudioDefaults(from: workout)
        saveWorkouts()
    }

    public func update(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
        } else {
            workouts.insert(workout, at: 0)
        }
        saveAudioDefaults(from: workout)
        saveWorkouts()
    }

    @discardableResult
    public func duplicate(_ workout: Workout) -> Workout {
        let copy = workout.duplicated()
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts.insert(copy, at: index + 1)
        } else {
            workouts.append(copy)
        }
        saveWorkouts()
        return copy
    }

    public func delete(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        saveWorkouts()
    }

    public func delete(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            if workouts.indices.contains(index) {
                workouts.remove(at: index)
            }
        }
        saveWorkouts()
    }

    public func makeNewDraftWorkout() -> Workout {
        let ud = UserDefaults.standard
        let cueType = ud.string(forKey: defaultsKeyPrefix + "cueType")
            .flatMap(CueType.init(rawValue:)) ?? .studioVoice
        let sfxStyle = ud.string(forKey: defaultsKeyPrefix + "sfxStyle")
            .flatMap(SoundEffectStyle.init(rawValue:)) ?? .beep
        let countdownMode = ud.string(forKey: defaultsKeyPrefix + "countdownMode")
            .flatMap(CountdownMode.init(rawValue:)) ?? .threeTwoOne
        let spotifyBehavior = ud.string(forKey: defaultsKeyPrefix + "spotifyBehavior")
            .flatMap(SpotifyAudioBehavior.init(rawValue:)) ?? .mix
        let savedVolume = ud.double(forKey: defaultsKeyPrefix + "cueVolume")
        let cueVolume = savedVolume > 0 ? min(1.0, max(0.1, savedVolume)) : 0.85

        return Workout(
            name: "Custom Circuit",
            getReadyDuration: 10,
            workDuration: 45,
            restDuration: 15,
            exerciseCount: 5,
            repsPerExercise: 3,
            enableTransitionRest: true,
            transitionRestDuration: 30,
            cueType: cueType,
            soundEffectStyle: sfxStyle,
            countdownMode: countdownMode,
            spotifyBehavior: spotifyBehavior,
            cueVolume: cueVolume
        )
    }

    private func saveAudioDefaults(from workout: Workout) {
        let ud = UserDefaults.standard
        ud.set(workout.cueType.rawValue, forKey: defaultsKeyPrefix + "cueType")
        ud.set(workout.soundEffectStyle.rawValue, forKey: defaultsKeyPrefix + "sfxStyle")
        ud.set(workout.countdownMode.rawValue, forKey: defaultsKeyPrefix + "countdownMode")
        ud.set(workout.spotifyBehavior.rawValue, forKey: defaultsKeyPrefix + "spotifyBehavior")
        ud.set(workout.cueVolume, forKey: defaultsKeyPrefix + "cueVolume")
    }
}
