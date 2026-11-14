import Foundation
import AVFoundation
import AudioToolbox

@MainActor
public final class AudioEngine: NSObject {
    public static let shared = AudioEngine()

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var keepAlivePlayer: AVAudioPlayer?
    private var activeCuePlayers: [AVAudioPlayer] = []
    private var duckRestoreTask: Task<Void, Never>?
    private var isWorkoutSessionActive: Bool = false
    private var currentSpotifyBehavior: SpotifyAudioBehavior = .mix

    // Pre-cached synthesized WAV data for fallback SFX so playback has zero latency
    private var synthesizedToneCache: [String: Data] = [:]

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
        prewarmSynthesizedTones()
        setupAudioSessionNotifications()
    }

    // MARK: - Session Lifecycle

    public func startWorkoutAudioSession(spotifyBehavior: SpotifyAudioBehavior) {
        currentSpotifyBehavior = spotifyBehavior
        isWorkoutSessionActive = true
        configureAudioSession(duckingActive: false)
        startKeepAliveLoop()
    }

    public func stopWorkoutAudioSession() {
        isWorkoutSessionActive = false
        duckRestoreTask?.cancel()
        duckRestoreTask = nil

        keepAlivePlayer?.stop()
        keepAlivePlayer = nil

        for player in activeCuePlayers {
            player.stop()
        }
        activeCuePlayers.removeAll()

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("[AudioEngine] Deactivate session error: \(error.localizedDescription)")
        }
    }

    private func configureAudioSession(duckingActive: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            let options: AVAudioSession.CategoryOptions = duckingActive ? [.duckOthers] : [.mixWithOthers]
            try session.setCategory(.playback, mode: .default, options: options)
            try session.setActive(true)
        } catch {
            print("[AudioEngine] Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
    }

    private func beginDuckingIfNeeded(estimatedDuration: TimeInterval) {
        guard currentSpotifyBehavior == .duck else { return }
        duckRestoreTask?.cancel()
        configureAudioSession(duckingActive: true)

        duckRestoreTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((estimatedDuration + 0.25) * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.restoreMixSessionAfterDuck()
        }
    }

    private func restoreMixSessionAfterDuck() {
        guard currentSpotifyBehavior == .duck else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            if isWorkoutSessionActive {
                try session.setActive(true)
                if keepAlivePlayer?.isPlaying == false {
                    keepAlivePlayer?.play()
                }
            }
        } catch {
            print("[AudioEngine] Failed to restore mix session after ducking: \(error.localizedDescription)")
        }
    }

    // MARK: - Silent Keep-Alive Audio Loop (Generated in Code)

    private func startKeepAliveLoop() {
        if let player = keepAlivePlayer, player.isPlaying {
            return
        }
        let silentData = Self.generateSilentKeepAliveWav(durationSeconds: 1.0)
        do {
            let player = try AVAudioPlayer(data: silentData, fileTypeHint: AVFileType.wav.rawValue)
            player.numberOfLoops = -1
            player.volume = 0.01 // Nearly inaudible keep-alive signal for background timer & Bluetooth wake
            player.prepareToPlay()
            player.play()
            keepAlivePlayer = player
        } catch {
            // Safely skip without crashing if keep-alive player cannot be initialized
            print("[AudioEngine] Keep-alive loop skipped safely: \(error.localizedDescription)")
        }
    }

    private func setupAudioSessionNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, self.isWorkoutSessionActive else { return }
                if let typeValue, let type = AVAudioSession.InterruptionType(rawValue: typeValue) {
                    if type == .ended {
                        self.configureAudioSession(duckingActive: false)
                        self.startKeepAliveLoop()
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isWorkoutSessionActive else { return }
                self.configureAudioSession(duckingActive: false)
                self.startKeepAliveLoop()
            }
        }
    }

    // MARK: - Workout Cues

    public func playCountdownTick(
        second: Int,
        workout: Workout
    ) {
        currentSpotifyBehavior = workout.spotifyBehavior
        let volume = Float(min(1.0, max(0.1, workout.cueVolume)))

        switch workout.cueType {
        case .studioVoice:
            let resourceName: String
            let fallbackWord: String
            switch second {
            case 3:
                resourceName = "voice_3"
                fallbackWord = "Three"
            case 2:
                resourceName = "voice_2"
                fallbackWord = "Two"
            case 1:
                resourceName = "voice_1"
                fallbackWord = "One"
            default:
                return
            }

            if !playBundledMP3IfExists(named: resourceName, volume: volume, estimatedDuration: 0.55) {
                speakFallback(text: fallbackWord, volume: volume, rate: 0.54, estimatedDuration: 0.55)
            }

        case .soundEffects:
            // Short countdown beeps (NEVER spoken words when Sound Effects is selected)
            if !playBundledMP3IfExists(named: "sfx_countdown_beep", volume: volume, estimatedDuration: 0.25) {
                playSynthesizedSFX(key: "sfx_countdown_beep", volume: volume, estimatedDuration: 0.25)
            }
        }
    }

    public func playPhaseStartCue(
        for phase: WorkoutPhaseType,
        workout: Workout
    ) {
        currentSpotifyBehavior = workout.spotifyBehavior
        let volume = Float(min(1.0, max(0.1, workout.cueVolume)))

        switch phase {
        case .getReady:
            if workout.cueType == .soundEffects {
                playSynthesizedSFX(key: "sfx_countdown_beep", volume: volume * 0.85, estimatedDuration: 0.25)
            }

        case .work:
            switch workout.cueType {
            case .studioVoice:
                if !playBundledMP3IfExists(named: "voice_work", volume: volume, estimatedDuration: 0.75) {
                    speakFallback(text: "Work!", volume: volume, rate: 0.52, estimatedDuration: 0.75)
                }
            case .soundEffects:
                let resource = workout.soundEffectStyle.workSoundResourceName
                if !playBundledMP3IfExists(named: resource, volume: volume, estimatedDuration: 0.8) {
                    playSynthesizedSFX(key: resource, volume: volume, estimatedDuration: 0.8)
                }
            }

        case .rest, .transitionRest:
            // Single cue at the start of standard or transition rest
            switch workout.cueType {
            case .studioVoice:
                if !playBundledMP3IfExists(named: "voice_rest", volume: volume, estimatedDuration: 0.75) {
                    speakFallback(text: "Rest", volume: volume, rate: 0.50, estimatedDuration: 0.75)
                }
            case .soundEffects:
                let resource = workout.soundEffectStyle.restSoundResourceName
                if !playBundledMP3IfExists(named: resource, volume: volume, estimatedDuration: 0.8) {
                    playSynthesizedSFX(key: resource, volume: volume, estimatedDuration: 0.8)
                }
            }

        case .done:
            switch workout.cueType {
            case .studioVoice:
                if !playBundledMP3IfExists(named: "voice_done", volume: volume, estimatedDuration: 1.4) {
                    speakFallback(text: "Done! Workout complete.", volume: volume, rate: 0.50, estimatedDuration: 1.4)
                }
            case .soundEffects:
                if !playBundledMP3IfExists(named: "voice_done", volume: volume, estimatedDuration: 1.2) {
                    playSynthesizedSFX(key: "sfx_done_fanfare", volume: volume, estimatedDuration: 1.2)
                }
            }
        }
    }

    public func previewCue(for workout: Workout) {
        currentSpotifyBehavior = workout.spotifyBehavior
        configureAudioSession(duckingActive: false)
        playPhaseStartCue(for: .work, workout: workout)
    }

    // MARK: - Bundle & Fallback Playback Helpers

    private func locateBundledSoundURL(named name: String) -> URL? {
        let subdirs: [String?] = ["Sounds", "Resources/Sounds", nil]
        for subdir in subdirs {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: subdir) {
                return url
            }
        }
        return nil
    }

    private func playBundledMP3IfExists(named name: String, volume: Float, estimatedDuration: TimeInterval) -> Bool {
        guard let url = locateBundledSoundURL(named: name) else {
            return false
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.duration > 0.02 else { return false }
            beginDuckingIfNeeded(estimatedDuration: player.duration)
            player.delegate = self
            player.volume = volume
            player.prepareToPlay()
            player.play()
            activeCuePlayers.append(player)
            return true
        } catch {
            print("[AudioEngine] Failed to play bundled MP3 \(name): \(error.localizedDescription)")
            return false
        }
    }

    private func speakFallback(text: String, volume: Float, rate: Float, estimatedDuration: TimeInterval) {
        beginDuckingIfNeeded(estimatedDuration: estimatedDuration)
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = volume
        utterance.rate = rate
        utterance.pitchMultiplier = 1.05
        speechSynthesizer.speak(utterance)
    }

    private func playSynthesizedSFX(key: String, volume: Float, estimatedDuration: TimeInterval) {
        guard let wavData = synthesizedToneCache[key] else {
            AudioServicesPlaySystemSound(1057)
            return
        }
        do {
            let player = try AVAudioPlayer(data: wavData, fileTypeHint: AVFileType.wav.rawValue)
            beginDuckingIfNeeded(estimatedDuration: max(estimatedDuration, player.duration))
            player.delegate = self
            player.volume = volume
            player.prepareToPlay()
            player.play()
            activeCuePlayers.append(player)
        } catch {
            AudioServicesPlaySystemSound(1057)
        }
    }

    // MARK: - Studio-Quality Synthesized Tone Generator (Fallback SFX)

    private func prewarmSynthesizedTones() {
        // Countdown short beep (crisp 880 Hz 110ms)
        synthesizedToneCache["sfx_countdown_beep"] = Self.generateToneWav(
            segments: [(freq: 880, duration: 0.11, harmonics: [1.0, 0.25], decay: 8.0)]
        )

        // 1. Beep (High double-beep for Work, lower single-beep for Rest)
        synthesizedToneCache["sfx_beep_work"] = Self.generateToneWav(
            segments: [
                (freq: 1046.5, duration: 0.14, harmonics: [1.0, 0.3], decay: 6.0),
                (freq: 0, duration: 0.05, harmonics: [], decay: 1.0),
                (freq: 1318.5, duration: 0.28, harmonics: [1.0, 0.35], decay: 5.0)
            ]
        )
        synthesizedToneCache["sfx_beep_rest"] = Self.generateToneWav(
            segments: [
                (freq: 659.25, duration: 0.14, harmonics: [1.0, 0.25], decay: 6.0),
                (freq: 0, duration: 0.05, harmonics: [], decay: 1.0),
                (freq: 523.25, duration: 0.28, harmonics: [1.0, 0.25], decay: 5.0)
            ]
        )

        // 2. Whistle (Bright referee whistle modulation for Work, short double-whistle for Rest)
        synthesizedToneCache["sfx_whistle_work"] = Self.generateToneWav(
            segments: [
                (freq: 2650.0, duration: 0.42, harmonics: [1.0, 0.4, 0.15], decay: 3.5)
            ],
            vibratoHz: 42.0,
            vibratoDepth: 55.0
        )
        synthesizedToneCache["sfx_whistle_rest"] = Self.generateToneWav(
            segments: [
                (freq: 2350.0, duration: 0.18, harmonics: [1.0, 0.35], decay: 5.0),
                (freq: 0, duration: 0.06, harmonics: [], decay: 1.0),
                (freq: 2100.0, duration: 0.24, harmonics: [1.0, 0.35], decay: 4.5)
            ],
            vibratoHz: 38.0,
            vibratoDepth: 45.0
        )

        // 3. Ring (Boxing bell metallic ring for Work & Rest)
        synthesizedToneCache["sfx_ring_work"] = Self.generateToneWav(
            segments: [
                (freq: 1174.66, duration: 0.65, harmonics: [1.0, 0.75, 0.5, 0.35], decay: 4.2)
            ]
        )
        synthesizedToneCache["sfx_ring_rest"] = Self.generateToneWav(
            segments: [
                (freq: 880.0, duration: 0.22, harmonics: [1.0, 0.65, 0.4], decay: 5.5),
                (freq: 0, duration: 0.05, harmonics: [], decay: 1.0),
                (freq: 783.99, duration: 0.48, harmonics: [1.0, 0.65, 0.4], decay: 4.5)
            ]
        )

        // 4. Gong (Deep resonant studio gong for Work, warm low gong for Rest)
        synthesizedToneCache["sfx_gong_work"] = Self.generateToneWav(
            segments: [
                (freq: 293.66, duration: 0.85, harmonics: [1.0, 0.85, 0.6, 0.4, 0.25], decay: 2.8)
            ]
        )
        synthesizedToneCache["sfx_gong_rest"] = Self.generateToneWav(
            segments: [
                (freq: 220.0, duration: 0.85, harmonics: [1.0, 0.8, 0.5, 0.3], decay: 3.0)
            ]
        )

        // 5. Calm Chime (Ascending harmonic chime for Work, descending warm chime for Rest)
        synthesizedToneCache["sfx_chime_work"] = Self.generateToneWav(
            segments: [
                (freq: 587.33, duration: 0.20, harmonics: [1.0, 0.4, 0.15], decay: 4.0),
                (freq: 880.0, duration: 0.48, harmonics: [1.0, 0.45, 0.2], decay: 3.5)
            ]
        )
        synthesizedToneCache["sfx_chime_rest"] = Self.generateToneWav(
            segments: [
                (freq: 783.99, duration: 0.20, harmonics: [1.0, 0.4, 0.15], decay: 4.0),
                (freq: 523.25, duration: 0.48, harmonics: [1.0, 0.4, 0.15], decay: 3.5)
            ]
        )

        // Done fanfare
        synthesizedToneCache["sfx_done_fanfare"] = Self.generateToneWav(
            segments: [
                (freq: 523.25, duration: 0.16, harmonics: [1.0, 0.4], decay: 4.5),
                (freq: 659.25, duration: 0.16, harmonics: [1.0, 0.4], decay: 4.5),
                (freq: 783.99, duration: 0.16, harmonics: [1.0, 0.4], decay: 4.5),
                (freq: 1046.50, duration: 0.55, harmonics: [1.0, 0.5, 0.25], decay: 2.8)
            ]
        )
    }

    private static func generateSilentKeepAliveWav(durationSeconds: Double) -> Data {
        let sampleRate = 22050
        let numSamples = max(1, Int(Double(sampleRate) * durationSeconds))
        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            samples[i] = (i % 2 == 0) ? 1 : -1
        }
        return encodePCM16Wav(samples: samples, sampleRate: sampleRate)
    }

    private static func generateToneWav(
        segments: [(freq: Double, duration: Double, harmonics: [Double], decay: Double)],
        vibratoHz: Double = 0,
        vibratoDepth: Double = 0
    ) -> Data {
        let sampleRate = 44100
        var allSamples: [Int16] = []

        for seg in segments {
            let count = max(1, Int(seg.duration * Double(sampleRate)))
            if seg.freq <= 0 || seg.harmonics.isEmpty {
                allSamples.append(contentsOf: repeatElement(Int16(0), count: count))
                continue
            }

            let weightSum = max(1.0, seg.harmonics.reduce(0, +))
            var phase = 0.0

            for i in 0..<count {
                let t = Double(i) / Double(sampleRate)
                let attack = min(1.0, t / 0.008)
                let release = min(1.0, (seg.duration - t) / 0.015)
                let envelope = attack * release * exp(-seg.decay * t)

                let instantFreq = seg.freq + (vibratoDepth * sin(2.0 * .pi * vibratoHz * t))
                phase += (2.0 * .pi * instantFreq) / Double(sampleRate)

                var sampleVal = 0.0
                for (hIdx, amp) in seg.harmonics.enumerated() {
                    let harmonicMultiplier = Double(hIdx + 1)
                    sampleVal += amp * sin(phase * harmonicMultiplier)
                }

                let normalized = (sampleVal / weightSum) * envelope
                let clamped = max(-0.95, min(0.95, normalized))
                allSamples.append(Int16(clamped * Double(Int16.max)))
            }
        }

        return encodePCM16Wav(samples: allSamples, sampleRate: sampleRate)
    }

    private static func encodePCM16Wav(samples: [Int16], sampleRate: Int) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize = 36 + dataSize

        var data = Data()
        data.reserveCapacity(Int(44 + dataSize))

        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndianBytes(chunkSize))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndianBytes(UInt32(16)))
        data.append(littleEndianBytes(UInt16(1)))
        data.append(littleEndianBytes(numChannels))
        data.append(littleEndianBytes(UInt32(sampleRate)))
        data.append(littleEndianBytes(byteRate))
        data.append(littleEndianBytes(blockAlign))
        data.append(littleEndianBytes(bitsPerSample))
        data.append(contentsOf: "data".utf8)
        data.append(littleEndianBytes(dataSize))

        samples.withUnsafeBufferPointer { buffer in
            if let base = buffer.baseAddress {
                data.append(
                    UnsafeBufferPointer(
                        start: UnsafeRawPointer(base).assumingMemoryBound(to: UInt8.self),
                        count: Int(dataSize)
                    )
                )
            }
        }

        return data
    }

    private static func littleEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }
}

extension AudioEngine: AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.activeCuePlayers.removeAll { $0 === player }
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Restored by duckRestoreTask timer
    }
}
