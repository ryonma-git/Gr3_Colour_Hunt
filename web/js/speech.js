// 英語の読み上げ。ネット接続は不要（端末に入っている音声を使う）。
// Swift 版 SpeechService.swift にあたる。
//
// iOS Safari の注意: 最初の1回はユーザー操作（タップ）の中で呼ぶ必要がある。
// このアプリでは児童が色の名前をタップしたときに呼ぶので条件を満たす。

let cachedVoice = null;

function pickVoice() {
  if (!('speechSynthesis' in window)) return null;
  const voices = window.speechSynthesis.getVoices();
  if (!voices || voices.length === 0) return null;

  const us = voices.filter((v) => v.lang && v.lang.replace('_', '-').startsWith('en-US'));
  if (us.length > 0) {
    return us.find((v) => v.localService) || us[0];
  }
  const en = voices.filter((v) => v.lang && v.lang.toLowerCase().startsWith('en'));
  if (en.length > 0) {
    return en.find((v) => v.localService) || en[0];
  }
  return null;
}

if ('speechSynthesis' in window) {
  // iOS では最初 getVoices() が空なので、そろったら選び直す
  window.speechSynthesis.addEventListener('voiceschanged', () => {
    cachedVoice = pickVoice();
  });
}

/** 例: speak('Red') */
export function speak(text) {
  if (!('speechSynthesis' in window)) return;
  const synth = window.speechSynthesis;
  if (!cachedVoice) cachedVoice = pickVoice();

  synth.cancel();
  const u = new SpeechSynthesisUtterance(text);
  if (cachedVoice) u.voice = cachedVoice;
  u.lang = cachedVoice ? cachedVoice.lang : 'en-US';
  u.rate = 0.9;
  u.pitch = 1.0;
  synth.speak(u);
}
