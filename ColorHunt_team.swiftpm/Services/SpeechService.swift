import AVFoundation
import Combine

/// 英語の読み上げ。ネット接続は不要。
final class SpeechService: NSObject, ObservableObject {

    private let synthesizer = AVSpeechSynthesizer()
    private var audioSessionReady = false

    /// 例: speak("Red") → "Red." と読み上げる
    func speak(_ text: String) {
        prepareAudioSession()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = SpeechService.englishVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0
        synthesizer.speak(utterance)
    }

    /// 消音スイッチ／音量に関係なく授業で聞こえるように、再生用の設定にしておく。
    private func prepareAudioSession() {
        guard !audioSessionReady else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
            audioSessionReady = true
        } catch {
            // 音が出せなくてもアプリは続行する
        }
    }

    /// できるだけ自然な英語の声を選ぶ（端末に入っている声だけを使う）
    static func englishVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let usVoices = allVoices.filter { $0.language.hasPrefix("en-US") }
        if let best = usVoices.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            return best
        }
        let englishVoices = allVoices.filter { $0.language.hasPrefix("en") }
        if let best = englishVoices.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            return best
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}
