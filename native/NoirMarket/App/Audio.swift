import AVFoundation
import UIKit

/// Background music plus haptics. Music respects the silent switch (ambient category).
@MainActor
final class Audio {
    static let shared = Audio()
    private var player: AVAudioPlayer?
    private var fadeTask: Task<Void, Never>?

    var musicOn: Bool {
        get { !ProcessInfo.processInfo.arguments.contains("-musicOff") && (UserDefaults.standard.object(forKey: "musicOn") as? Bool ?? true) }
        set {
            UserDefaults.standard.set(newValue, forKey: "musicOn")
            newValue ? play() : stop()
        }
    }

    var soundsOn: Bool {
        get { !ProcessInfo.processInfo.arguments.contains("-musicOff") && (UserDefaults.standard.object(forKey: "soundsOn") as? Bool ?? true) }
        set { UserDefaults.standard.set(newValue, forKey: "soundsOn") }
    }

    private var effects: [String: AVAudioPlayer] = [:]

    enum Effect: String { case cash, siren, page, thud, click, key, gunshot, swipe, boom, knuckles, train, bingbong }

    func play(_ effect: Effect, volume: Float = 0.6) {
        guard soundsOn else { return }
        if effects[effect.rawValue] == nil, let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            effects[effect.rawValue] = try? AVAudioPlayer(contentsOf: url)
        }
        guard let p = effects[effect.rawValue] else { return }
        p.volume = volume
        p.currentTime = 0
        p.play()
    }

    var hapticsOn: Bool {
        get { UserDefaults.standard.object(forKey: "hapticsOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsOn") }
    }

    func play(volume: Float = 0.8) {
        guard musicOn else { return }
        if player == nil, let url = Bundle.main.url(forResource: "game-music", withExtension: "mp3") {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0
            player?.prepareToPlay()
        }
        guard let player else { return }
        if !player.isPlaying { player.play() }
        fade(to: volume, over: 1.6)
    }

    /// Duck the music once the game proper begins.
    func duck() { fade(to: 0.4, over: 2) }

    func stop() {
        fadeTask?.cancel()
        player?.stop()
    }

    private func fade(to target: Float, over seconds: Double) {
        fadeTask?.cancel()
        fadeTask = Task { [weak self] in
            guard let player = self?.player else { return }
            let steps = 24
            let start = player.volume
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(seconds / Double(steps)))
                if Task.isCancelled { return }
                player.volume = start + (target - start) * Float(i) / Float(steps)
            }
        }
    }

    private let typing = UIImpactFeedbackGenerator(style: .soft)

    /// A faint tick while NOIRNET types.
    func typeTick() {
        guard hapticsOn else { return }
        typing.impactOccurred(intensity: 0.45)
    }

    enum Buzz { case tap, success, warning, danger }

    func buzz(_ kind: Buzz) {
        guard hapticsOn else { return }
        switch kind {
        case .tap: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .danger:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
