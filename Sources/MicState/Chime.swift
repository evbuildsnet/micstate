import AVFAudio
import Foundation

/// Two synthesized blips: rising for mic on, falling for mic off. Output only, never touches input.
@MainActor
final class Chime {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private lazy var up = render(from: 620, to: 930)
    private lazy var down = render(from: 930, to: 620)

    private var isBuilt = false

    func play(muted: Bool) {
        if !isBuilt {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.5
            isBuilt = true
        }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        player.scheduleBuffer(muted ? down : up, at: nil, options: .interrupts)
        player.play()
    }

    private func render(from f1: Double, to f2: Double) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let noteFrames = Int(rate * 0.075)
        let frames = noteFrames * 2
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let out = buffer.floatChannelData![0]
        for i in 0..<frames {
            let f = i < noteFrames ? f1 : f2
            let local = Double(i % noteFrames) / Double(noteFrames)
            let envelope = min(local * 12, 1) * (1 - local)
            out[i] = Float(sin(2 * .pi * f * Double(i) / rate) * envelope * 0.6)
        }
        return buffer
    }
}
