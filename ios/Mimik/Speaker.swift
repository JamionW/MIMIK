import AVFoundation
import MediaPlayer
import MimikCore

/// Which button is lit while its clip plays.
struct PlayingKey: Equatable {
    let id: String
    let slow: Bool
}

/// Plays the bundled clips, falling back to the device voice for any that are missing, and wires
/// the lock screen and earbud controls: play replays the last phrase, next track replays it slowly,
/// previous track replays it at normal speed (Feature 3 on the web).
final class Speaker: NSObject, ObservableObject {
    static let slowRate: Float = 0.7

    @Published private(set) var active: PlayingKey?

    /// Changing voice stops whatever is playing, as on the web.
    var gender: Gender = .m {
        didSet { if oldValue != gender { stop() } }
    }

    private var entry: LanguageEntry?
    private var language: Language?
    private var audioRoot: URL?
    private var player: AVAudioPlayer?
    private let synth = AVSpeechSynthesizer()
    private var last: Utterance?

    override init() {
        super.init()
        synth.delegate = self
        setupRemoteCommands()
    }

    func configure(entry: LanguageEntry, language: Language) {
        stop()
        self.entry = entry
        self.language = language
        audioRoot = Catalog.audioRoot(entry.code)
        last = nil
    }

    func play(_ u: Utterance, slow: Bool) {
        stop()
        guard let entry else { return }
        last = u
        active = PlayingKey(id: u.id, slow: slow)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        let path = entry.human.clipPath(u.id, voice: u.voice(for: gender))
        if let url = audioRoot?.appendingPathComponent(path), let p = try? AVAudioPlayer(contentsOf: url) {
            p.enableRate = true
            p.rate = slow ? Self.slowRate : 1
            p.delegate = self
            p.prepareToPlay()
            p.play()
            player = p
        } else {
            speak(u, slow: slow, entry: entry)
        }
        nowPlaying(u, entry: entry, rate: slow ? Self.slowRate : 1)
    }

    func stop() {
        player?.stop()
        player = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        active = nil
    }

    private func replay(slow: Bool) -> MPRemoteCommandHandlerStatus {
        guard let last else { return .noActionableNowPlayingItem }
        play(last, slow: slow)
        return .success
    }

    private func speak(_ u: Utterance, slow: Bool, entry: LanguageEntry) {
        let utterance = AVSpeechUtterance(string: u.spoken)
        let voices = AVSpeechSynthesisVoice.speechVoices().map {
            VoiceCandidate(language: $0.language, name: $0.name, identifier: $0.identifier)
        }
        if let v = pickVoice(voices, lang: entry.lang, deviceLangs: language?.deviceLangs, deviceVoice: language?.deviceVoice) {
            utterance.voice = AVSpeechSynthesisVoice(identifier: v.identifier)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: entry.lang)
        }
        // The web uses 0.9 and 0.6 of the normal rate.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.6 : 0.9)
        synth.speak(utterance)
    }

    private func nowPlaying(_ u: Utterance, entry: LanguageEntry, rate: Float) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: u.text,
            MPMediaItemPropertyArtist: u.en,
            MPMediaItemPropertyAlbumTitle: "Mimik \(entry.name)",
            MPNowPlayingInfoPropertyPlaybackRate: rate,
        ]
        if let player { info[MPMediaItemPropertyPlaybackDuration] = player.duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.replay(slow: false) ?? .commandFailed }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.replay(slow: false) ?? .commandFailed }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.replay(slow: false) ?? .commandFailed }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.replay(slow: true) ?? .commandFailed }
        c.pauseCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
    }
}

extension Speaker: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if p === self.player {
                self.player = nil
                self.active = nil
            }
        }
    }
}

extension Speaker: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if self.player == nil && !self.synth.isSpeaking { self.active = nil }
        }
    }
}
