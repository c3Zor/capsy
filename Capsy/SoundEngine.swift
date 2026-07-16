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

    private init() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mixWithOthers: true)
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

    /// Two calm notes — a release ritual completed.
    static func chime() {
        let note1 = 0.4, gap = 0.12, note2 = 0.5
        let total = note1 + gap + note2
        shared.play(shared.tone(duration: total, frequency: { t in
            t < note1 ? 523.25 : 659.25 // C5 then E5
        }) { t in
            if t < note1 {
                return shared.pluckEnvelope(t, peak: 0.3, decayRate: 6)
            } else if t < note1 + gap {
                return 0
            } else {
                return shared.pluckEnvelope(t - note1 - gap, peak: 0.32, decayRate: 5)
            }
        })
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
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            isReady = true
        } catch {
            // No audio hardware (or simulator quirk) — sounds just won't play.
        }
    }
}
