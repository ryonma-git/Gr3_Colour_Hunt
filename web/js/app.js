// Color Hunt Web — 画面の行き来と、カメラ・判定・保存・共有のつなぎ。
// Swift 版の RootView / HuntView にあたる。
//
// 大事な考え方:
// これは「カメラが物の色を教えるアプリ」ではない。
// 児童が先に「これは青だと思う」と考えてカメラを向け、
// アプリは指定された色の範囲に入っているかを確かめるだけ。判断するのは児童。

import { COLOR_PROFILES, TUNING, profileById, randomHuntColor } from './colors.js';
import { Detector } from './detector.js';
import { Camera } from './camera.js';
import { speak } from './speech.js';
import { saveCapture, allCaptures, getCapture, deleteCapture, exportLibraryJSON } from './storage.js';
import { shareCapture, openBlobInNewTab } from './share.js';

const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- 状態
let detector = null;
let camera = null;
let currentScreen = 'home';
let pending = null;        // 撮影したがまだ保存していない1枚
let savedRecord = null;    // 保存した1枚
let detailRecord = null;
let countdownToken = 0;
let objectURLs = [];
let audioCtx = null;

// ---------------------------------------------------------------- 画面
const SCREENS = ['home', 'hunt', 'preview', 'gallery', 'detail'];

function showScreen(name) {
  SCREENS.forEach((s) => $('screen-' + s).classList.toggle('is-active', s === name));
  currentScreen = name;
}

function trackURL(url) {
  objectURLs.push(url);
  return url;
}
function releaseURLs() {
  objectURLs.forEach((u) => URL.revokeObjectURL(u));
  objectURLs = [];
}

// ---------------------------------------------------------------- 音
function primeAudio() {
  if (audioCtx) return;
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (Ctx) audioCtx = new Ctx();
  } catch (e) { /* 音が出せなくても続行 */ }
}

function playSuccessCue() {
  if (navigator.vibrate) navigator.vibrate(18);
  if (!audioCtx) return;
  try {
    if (audioCtx.state === 'suspended') audioCtx.resume();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'sine';
    osc.frequency.value = 880;
    gain.gain.setValueAtTime(0.0001, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.18, audioCtx.currentTime + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.18);
    osc.connect(gain).connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + 0.2);
  } catch (e) { /* 無視 */ }
}

// ---------------------------------------------------------------- 判定の見た目
let lastPhase = 'searching';

function updateHuntUI() {
  if (!detector) return;
  const p = detector.activeProfile;
  $('target-name').textContent = p.displayName;
  $('reticle-found').textContent = 'You found ' + p.displayName + '!';

  const reticle = $('reticle');
  const found = detector.phase === 'found';
  reticle.classList.toggle('is-found', found);
  reticle.classList.toggle('is-matching', !found && detector.isMatchingNow);

  $('status-line').textContent = found ? 'しゃしんを とろう' : 'まん中に あわせてね';
  $('btn-shutter').disabled = !(found && camera && camera.isRunning);

  if (found && lastPhase !== 'found') playSuccessCue();
  lastPhase = detector.phase;

  const panel = $('debug-panel');
  if (detector.isDebugEnabled) {
    const h = detector.debugHSV;
    panel.textContent = h
      ? 'H: ' + h.h.toFixed(1) + '  S: ' + h.s.toFixed(2) + '  V: ' + h.v.toFixed(2) +
        '\nmatched: ' + (detector.phase === 'found' || detector.isMatchingNow) +
        '\ntarget: ' + p.displayName
      : 'no sample';
    panel.classList.remove('hidden');
  } else {
    panel.classList.add('hidden');
  }
}

// ---------------------------------------------------------------- 3 2 1
async function runCountdown() {
  const token = ++countdownToken;
  detector.pause();
  const el = $('countdown');
  $('countdown-color').textContent = detector.activeProfile.displayName;
  el.classList.remove('hidden');

  for (const n of [3, 2, 1]) {
    if (token !== countdownToken) return;
    const num = $('countdown-number');
    num.textContent = String(n);
    num.classList.remove('pop');
    void num.offsetWidth;
    num.classList.add('pop');
    await sleep(700);
  }
  if (token !== countdownToken) return;
  el.classList.add('hidden');
  detector.resume();
  updateHuntUI();
}

function cancelCountdown() {
  countdownToken++;
  $('countdown').classList.add('hidden');
}

// ---------------------------------------------------------------- カメラ
function showCameraMessage(text) {
  const el = $('camera-message');
  if (!text) {
    el.classList.add('hidden');
    return;
  }
  el.textContent = text;
  el.classList.remove('hidden');
}

async function startCamera() {
  showCameraMessage(null);
  $('permission-panel').classList.add('hidden');
  const ok = await camera.start();
  if (!ok) {
    $('permission-panel').classList.remove('hidden');
  }
  updateHuntUI();
  return ok;
}

// ---------------------------------------------------------------- 遷移
async function enterHuntWithNewColor() {
  primeAudio();
  detector.pickNextColor();
  showScreen('hunt');
  updateHuntUI();
  const ok = await startCamera();
  if (ok) runCountdown();
}

function leaveHunt() {
  cancelCountdown();
  camera.stop();
  detector.reset();
  clearPending();
  showScreen('home');
  refreshHomeNote();
}

function clearPending() {
  if (pending && pending.url) URL.revokeObjectURL(pending.url);
  pending = null;
  savedRecord = null;
  $('preview-actions').classList.remove('hidden');
  $('saved-actions').classList.add('hidden');
  $('preview-message').classList.add('hidden');
}

// ---------------------------------------------------------------- MY COLORS
async function openGallery() {
  releaseURLs();
  const list = await allCaptures();
  const body = $('gallery-body');
  body.innerHTML = '';

  if (list.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'gallery-empty';
    empty.innerHTML = '<p class="big">まだ しゃしんが ありません</p><p>START から いろを さがしてみよう</p>';
    body.appendChild(empty);
  } else {
    const known = COLOR_PROFILES.map((p) => p.id);
    const sections = COLOR_PROFILES.map((p) => ({
      title: p.displayName, tint: p.tint,
      items: list.filter((c) => c.targetColor === p.id)
    }));
    sections.push({
      title: 'OTHER', tint: '#737376',
      items: list.filter((c) => !known.includes(c.targetColor))
    });

    sections.filter((s) => s.items.length > 0).forEach((s) => {
      const sec = document.createElement('section');
      sec.className = 'color-section';
      const head = document.createElement('div');
      head.className = 'color-section-head';
      head.innerHTML =
        '<span class="color-dot" style="background:' + s.tint + '"></span>' +
        '<span class="color-name">' + s.title + '</span>' +
        '<span class="color-count">' + s.items.length + '</span>';
      sec.appendChild(head);

      const grid = document.createElement('div');
      grid.className = 'color-grid';
      s.items.forEach((c) => {
        const btn = document.createElement('button');
        btn.className = 'thumb';
        btn.type = 'button';
        const img = document.createElement('img');
        img.src = trackURL(URL.createObjectURL(c.blob));
        img.alt = c.displayName;
        btn.appendChild(img);
        btn.addEventListener('click', () => openDetail(c.id));
        grid.appendChild(btn);
      });
      sec.appendChild(grid);
      body.appendChild(sec);
    });
  }
  showScreen('gallery');
}

async function openDetail(id) {
  const rec = await getCapture(id);
  if (!rec) return;
  detailRecord = rec;
  $('detail-color').textContent = rec.displayName;
  $('detail-image').src = trackURL(URL.createObjectURL(rec.blob));
  const d = new Date(rec.capturedAt);
  $('detail-date').textContent = d.toLocaleString('ja-JP', {
    year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit'
  });
  showScreen('detail');
}

// ---------------------------------------------------------------- 共有
async function doShare(record) {
  const profile = profileById(record.targetColor);
  const result = await shareCapture(record, profile);
  if (result === 'unsupported') {
    await openBlobInNewTab(record, profile);
    alert('共有シートが つかえませんでした。\nひらいた画像を長おしして「写真に追加」してから、ロイロノートで えらんでください。');
  }
}

// ---------------------------------------------------------------- ホームの案内
async function refreshHomeNote() {
  const list = await allCaptures();
  const note = $('home-note');
  note.textContent =
    list.length === 0
      ? 'しゃしんは この iPad の ブラウザに ほぞんされます'
      : 'ほぞん ずみ: ' + list.length + 'まい（この iPad の ブラウザの中）';
  note.classList.remove('warn');
}

// ---------------------------------------------------------------- 起動
function wireEvents() {
  // HOME
  $('btn-start').addEventListener('click', enterHuntWithNewColor);
  $('btn-home-gallery').addEventListener('click', openGallery);

  // HUNT
  $('btn-hunt-close').addEventListener('click', leaveHunt);
  $('btn-hunt-gallery').addEventListener('click', openGallery);
  $('target-word').addEventListener('click', () => speak(detector.activeProfile.speechText));
  $('btn-retry-camera').addEventListener('click', startCamera);
  $('btn-permission-home').addEventListener('click', leaveHunt);

  $('btn-shutter').addEventListener('click', async () => {
    if (!detector || detector.phase !== 'found') return;
    $('btn-shutter').disabled = true;
    try {
      const blob = await camera.capturePhoto();
      pending = {
        blob,
        url: URL.createObjectURL(blob),
        profile: detector.activeProfile,
        hsv: detector.foundHSV
      };
      $('preview-color').textContent = pending.profile.displayName;
      $('preview-image').src = pending.url;
      detector.pause();
      showScreen('preview');
    } catch (e) {
      showCameraMessage('しゃしんを とれませんでした。もういちど ためしてください。');
      updateHuntUI();
    }
  });

  // 撮影後
  $('btn-retake').addEventListener('click', () => {
    clearPending();
    showScreen('hunt');
    detector.resume();      // みつけた状態は保ったままカメラへ戻る
    updateHuntUI();
  });

  $('btn-confirm').addEventListener('click', async () => {
    if (!pending) return;
    $('btn-confirm').disabled = true;
    try {
      savedRecord = await saveCapture({
        blob: pending.blob, profile: pending.profile, hsv: pending.hsv
      });
      $('preview-actions').classList.add('hidden');
      $('saved-actions').classList.remove('hidden');
      $('preview-message').classList.add('hidden');
    } catch (e) {
      const msg = $('preview-message');
      msg.textContent = 'ほぞんできませんでした。ブラウザの空き容量を確かめてください。';
      msg.classList.remove('hidden');
    } finally {
      $('btn-confirm').disabled = false;
    }
  });

  $('btn-share').addEventListener('click', () => savedRecord && doShare(savedRecord));

  $('btn-next').addEventListener('click', () => {
    clearPending();
    enterHuntWithNewColor();   // ★ 色が変わる
  });

  // MY COLORS
  $('btn-gallery-close').addEventListener('click', () => {
    releaseURLs();
    showScreen(camera && camera.isRunning ? 'hunt' : 'home');
    if (!camera || !camera.isRunning) refreshHomeNote();
  });
  $('btn-detail-back').addEventListener('click', openGallery);
  $('btn-detail-share').addEventListener('click', () => detailRecord && doShare(detailRecord));
  $('btn-detail-delete').addEventListener('click', async () => {
    if (!detailRecord) return;
    if (!confirm('この しゃしんを けしますか？\nけすと、もとに もどせません。')) return;
    await deleteCapture(detailRecord.id);
    detailRecord = null;
    openGallery();
  });

  $('btn-export').addEventListener('click', async () => {
    const json = await exportLibraryJSON();
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'library.json';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
  });

  // 先生用のかくれた表示（左下すみを1.5秒長おし）
  let holdTimer = null;
  const toggle = $('debug-toggle');
  const startHold = () => {
    holdTimer = setTimeout(() => {
      detector.isDebugEnabled = !detector.isDebugEnabled;
      updateHuntUI();
    }, 1500);
  };
  const cancelHold = () => { if (holdTimer) clearTimeout(holdTimer); holdTimer = null; };
  toggle.addEventListener('pointerdown', startHold);
  toggle.addEventListener('pointerup', cancelHold);
  toggle.addEventListener('pointercancel', cancelHold);
  toggle.addEventListener('pointerleave', cancelHold);

  // 画面を離れたときはカメラを止める
  document.addEventListener('visibilitychange', async () => {
    if (document.hidden) {
      if (camera) camera.stop();
    } else if (currentScreen === 'hunt' && camera && !camera.isRunning) {
      await startCamera();
    }
  });
}

function boot() {
  detector = new Detector(randomHuntColor(null), updateHuntUI);
  camera = new Camera($('video'), {
    onSample: (hsv) => detector.ingest(hsv),
    onError: (msg) => {
      showCameraMessage(msg);
      $('permission-panel').classList.remove('hidden');
      $('permission-note').textContent =
        msg.indexOf('きょか') >= 0
          ? 'Safari の アドレスバー左の「ぁA」→「Webサイトの設定」→ カメラを「許可」にしてください。'
          : 'ページを 読みこみ直すと なおることがあります。';
    }
  });

  wireEvents();
  updateHuntUI();
  refreshHomeNote();

  // 検証用フック（Swift 版の harness.sh にあたる）。
  // URL の末尾に ?debug=1 を付けたときだけ有効。ふだんの授業では何も起きない。
  //   例: .../index.html?debug=1
  //   コンソールで __colorHunt.demoFound() と打つと、カメラが無くても
  //   「みつけた」状態の見た目を確かめられる。
  if (new URLSearchParams(location.search).has('debug')) {
    window.__colorHunt = {
      detector,
      camera,
      showScreen,
      runCountdown,
      /** いま出題されている色ちょうどの色を流し込んで FOUND を再現する */
      demoFound() {
        const p = detector.activeProfile;
        const r = p.hueRanges[0];
        const hsv = {
          h: r.from <= r.to ? (r.from + r.to) / 2 : r.from,
          s: (p.saturationRange.lower + p.saturationRange.upper) / 2,
          v: (p.brightnessRange.lower + p.brightnessRange.upper) / 2
        };
        detector.resume();
        for (let i = 0; i < 20; i++) detector.ingest(hsv);
        const t0 = performance.now();
        const timer = setInterval(() => {
          detector.ingest(hsv);
          if (performance.now() - t0 > 1500) clearInterval(timer);
        }, 60);
      },
      /** どの色にも当たらない色を流し込んで、解除されることを確かめる */
      demoRelease() {
        const hsv = { h: 0, s: 0.02, v: 0.95 };
        const t0 = performance.now();
        const timer = setInterval(() => {
          detector.ingest(hsv);
          if (performance.now() - t0 > 1500) clearInterval(timer);
        }, 60);
      }
    };
  }

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('./sw.js').catch(() => {});
    });
  }
}

boot();
