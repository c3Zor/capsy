import AVFoundation

/// Every sound in Capsy is synthesized in code — no audio files.
/// Category `.ambient` so we never interrupt music or other apps.
final class SoundEngine {
    static let shared = SoundEngine()

    /// Reads the same key a Settings toggle would write via `@AppStorage("soundOn")`.
    static var isOn: Bool {
        UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true
    }

    private let sampleRate = 44_100.0
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isReady = false
    private var isConfigured = false

    private init() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: .mixWithOthers)
            try session.setActive(true)
        } catch {
            // Sound is a nice-to-have. Never let it crash the app.
        }
    }

    // MARK: - Public sounds

    /// Soft low blip — a drop hitting the water.
    static func plop() {
        shared.play(shared.tone(duration: 0.18, frequency: { _ in 160 }) { t in
            shared.pluckEnvelope(t, peak: 0.55, decayRate: 28)
        })
    }

    /// Gentle rising tone, about a second — inhale.
    static func breatheIn() {
        let duration = 1.0
        shared.play(shared.tone(duration: duration, frequency: { t in
            200 + 140 * (t / duration)
        }) { t in
            shared.breathEnvelope(t, duration: duration, peak: 0.12)
        })
    }

    /// Gentle falling tone, about a second — exhale.
    static func breatheOut() {
        let duration = 1.1
        shared.play(shared.tone(duration: duration, frequency: { t in
            340 - 150 * (t / duration)
        }) { t in
            shared.breathEnvelope(t, duration: duration, peak: 0.12)
        })
    }

    /// Tibetan bowl tone (C4·G4·C5) with a long tail decay and natural
    /// variation — the ritual is complete. "A wave, not an explosion."
    static func chime() {
        shared.play(shared.bowlBuffer())
    }

    /// The room quietly "hums" — a very quiet 55 Hz drone during the ritual.
    static func droneOn() {
        guard isOn else { return }
        shared.startDrone()
    }

    static func droneOff() {
        shared.stopDrone()
    }

    // MARK: - Tone generation

    /// Builds one mono buffer. `frequency` may glide over time; phase is accumulated
    /// sample-by-sample so a changing frequency never produces a click.
    private func tone(
        duration: Double,
        frequency: (Double) -> Double,
        amplitude: (Double) -> Double
    ) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                             frameCapacity: AVAudioFrameCount(duration * sampleRate)),
              let data = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = buffer.frameCapacity
        var phase = 0.0
        for frame in 0..<Int(buffer.frameLength) {
            let t = Double(frame) / sampleRate
            phase += 2 * .pi * frequency(t) / sampleRate
            data[frame] = Float(sin(phase) * amplitude(t))
        }
        return buffer
    }

    /// Fast fade-in, exponential decay — good for plops and chime notes.
    private func pluckEnvelope(_ t: Double, peak: Double, decayRate: Double) -> Double {
        guard t >= 0 else { return 0 }
        let attack = min(t / 0.008, 1.0)
        return peak * attack * exp(-decayRate * t)
    }

    /// Raised, rounded fade in and out across the whole tone — good for breathing.
    private func breathEnvelope(_ t: Double, duration: Double, peak: Double) -> Double {
        let fade = duration * 0.3
        let fadeIn = min(t / fade, 1.0)
        let fadeOut = min((duration - t) / fade, 1.0)
        return peak * max(0, min(fadeIn, fadeOut))
    }

    /// Trys deriniai (C4·G4·C5), kiekvienas su vos praskleista pora (f ir f·1.003),
    /// slow attack and ~4.5 s exponential decay. A ±0.5 % variation every time.
    private func bowlBuffer() -> AVAudioPCMBuffer? {
        let duration = 4.5
        let variation = 1 + Double.random(in: -0.005...0.005)
        let partials: [(freq: Double, amp: Double)] = [(261.6, 0.11), (392.0, 0.09), (523.2, 0.07)]
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                             frameCapacity: AVAudioFrameCount(duration * sampleRate)),
              let data = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = buffer.frameCapacity
        for frame in 0..<Int(buffer.frameLength) {
            let t = Double(frame) / sampleRate
            let envelope = min(t / 0.15, 1.0) * exp(-1.24 * max(0, t - 0.15))
            var sample = 0.0
            for p in partials {
                let f = p.freq * variation
                sample += p.amp * (sin(2 * .pi * f * t) + sin(2 * .pi * f * 1.003 * t)) / 2
            }
            data[frame] = Float(sample * envelope)
        }
        return buffer
    }

    // MARK: - Drone

    private let dronePlayer = AVAudioPlayerNode()
    private var droneConfigured = false

    /// Seamless 2 s loop: 55 Hz + 82.5 Hz (whole cycle counts — no clicking).
    private func startDrone() {
        startIfNeeded()
        guard isReady else { return }
        if !droneConfigured {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
            engine.attach(dronePlayer)
            engine.connect(dronePlayer, to: engine.mainMixerNode, format: format)
            droneConfigured = true
        }
        guard !dronePlayer.isPlaying,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                             frameCapacity: AVAudioFrameCount(2.0 * sampleRate)),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        for frame in 0..<Int(buffer.frameLength) {
            let t = Double(frame) / sampleRate
            data[frame] = Float(0.035 * (sin(2 * .pi * 55 * t) + 0.7 * sin(2 * .pi * 82.5 * t)))
        }
        dronePlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        dronePlayer.play()
    }

    private func stopDrone() {
        guard droneConfigured, dronePlayer.isPlaying else { return }
        dronePlayer.stop() // the drone is barely audible anyway — an abrupt stop goes unnoticed
    }

    // MARK: - Playback

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard Self.isOn, let buffer else { return }
        startIfNeeded()
        guard isReady else { return }
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func startIfNeeded() {
        guard !isReady else { return }
        // Attach/connect exactly once — re-attaching an already-attached node
        // throws an NSException, and engine.start() may fail and be retried.
        if !isConfigured {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isConfigured = true
        }
        do {
            try engine.start()
            isReady = true
        } catch {
            // No audio hardware (or simulator quirk) — sounds just won't play.
        }
    }
}
