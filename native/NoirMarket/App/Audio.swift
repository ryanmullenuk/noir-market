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

    enum Effect: String { case cash, siren, page, thud, click, key, gunshot, swipe, boom, knuckles, train, bingbong, ring }

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

    private var firstPassTask: Task<Void, Never>?
    private var firstPassDone = false

    /// Plays the theme once at full volume, then keeps it looping at half volume.
    func play(volume: Float = 1.0) {
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
        let target: Float = firstPassDone ? 0.5 : volume
        fade(to: target, over: 1.6)
        if firstPassTask == nil && !firstPassDone {
            let remaining = max(1, player.duration - player.currentTime)
            firstPassTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(remaining))
                guard let self, !Task.isCancelled else { return }
                self.firstPassDone = true
                self.fade(to: 0.5, over: 1.2)
            }
        }
    }

    /// The game no longer ducks on entry; the volume drop happens after the first full play-through.
    func duck() {}

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
