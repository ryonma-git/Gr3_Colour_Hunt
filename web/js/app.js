// Color Hunt Web — 画面の行き来と、カメラ・判定・保存・共有のつなぎ。
//
// 大事な考え方:
// アプリは物の色を教えない。児童が「これは青だと思う」と考えてカメラを向け、
// アプリは指定された色の範囲に入っているかを確かめるだけ。判断するのは児童。
//
// 2026-09 簡略版の方針:
//   子どもだけで使えるように、余計な確認と選択肢をなくした。
//   シャッターを押したら確認画面を出さずに自動で保存し、そのまま探索へ戻る。
//     SOLO … 次の色へ（色名を大きく出して読み上げる）
//     TEAM … 同じ色のまま Found +1
//   ロイロノートへの送信は MY COLORS / RESULT の写真から行う。

import {
  COLOR_PROFILES, TEAM_ASSIGNMENTS, TEAM_DURATION, TEAM_WARNING,
  profileById, randomHuntColor, teamProfile, readableColor
} from './colors.js';
import { Detector } from './detector.js';
import { Camera } from './camera.js';
import { speak, primeSpeech } from './speech.js';
import { saveCapture, allCaptures, getCapture, deleteCapture, exportLibraryJSON } from './storage.js';
import { shareCapture, openBlobInNewTab } from './share.js';

const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- 状態
let detector = null;
let camera = null;
let mode = 'solo';           // 'solo' | 'team'
let team = null;             // { number, profile, captureIDs, timingStartedAt, timeUp }
let teamTimer = null;
let countdownToken = 0;
let isCapturing = false;
let objectURLs = [];
let audioCtx = null;
let detailRecord = null;
let viewer = { list: [], index: 0, profile: null };

// ---------------------------------------------------------------- 画面
const SCREENS = ['home', 'team', 'hunt', 'result', 'viewer', 'gallery', 'detail'];
let currentScreen = 'home';

function showScreen(name) {
  SCREENS.forEach((s) => $('screen-' + s).classList.toggle('is-active', s === name));
  currentScreen = name;
}

function trackURL(url) { objectURLs.push(url); return url; }
function releaseURLs() { objectURLs.forEach((u) => URL.revokeObjectURL(u)); objectURLs = []; }

// ---------------------------------------------------------------- 音（控えめに）
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
    gain.gain.exponentialRampToValueAtTime(0.14, audioCtx.currentTime + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.16);
    osc.connect(gain).connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + 0.18);
  } catch (e) { /* 無視 */ }
}

// ---------------------------------------------------------------- さがす画面の見た目
let lastPhase = 'searching';

function canShoot() {
  return detector.phase === 'found' && camera && camera.isRunning && !isCapturing &&
    !(team && team.timeUp);
}

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
  $('btn-shutter').disabled = !canShoot();

  if (found && lastPhase !== 'found') playSuccessCue();
  lastPhase = detector.phase;

  // SOLO / TEAM で上の表示を切りかえる
  const isTeam = mode === 'team' && team;
  $('btn-hunt-close').classList.toggle('hidden', !!isTeam);
  $('btn-finish').classList.toggle('hidden', !isTeam);
  $('team-badge').classList.toggle('hidden', !isTeam);
  $('team-status').classList.toggle('hidden', !isTeam);
  if (isTeam) {
    $('team-badge').textContent = 'TEAM ' + team.number;
    $('team-found').textContent = String(team.captureIDs.length);
  }

  const panel = $('debug-panel');
  if (detector.isDebugEnabled) {
    const h = detector.debugHSV;
    panel.textContent = h
      ? 'H: ' + h.h.toFixed(1) + '  S: ' + h.s.toFixed(2) + '  V: ' + h.v.toFixed(2) +
        '\nmatched: ' + (found || detector.isMatchingNow) + '\ntarget: ' + p.displayName
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
  // あたらしい色になったら、まず英語で1回読み上げる（聞く → さがす）
  speak(detector.activeProfile.speechText);
  $('countdown-color').textContent = detector.activeProfile.displayName;
  $('countdown').classList.remove('hidden');

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
  $('countdown').classList.add('hidden');
  detector.resume();
  // TEAM は 3・2・1 が終わってから5分を数え始める
  if (mode === 'team' && team && !team.timingStartedAt) startTeamTimer();
  updateHuntUI();
}

function cancelCountdown() {
  countdownToken++;
  $('countdown').classList.add('hidden');
}

// ---------------------------------------------------------------- カメラ
function showCameraMessage(text) {
  const el = $('camera-message');
  if (!text) { el.classList.add('hidden'); return; }
  el.textContent = text;
  el.classList.remove('hidden');
}

async function startCamera() {
  showCameraMessage(null);
  $('permission-panel').classList.add('hidden');
  const ok = await camera.start();
  if (!ok) $('permission-panel').classList.remove('hidden');
  updateHuntUI();
  return ok;
}

// ---------------------------------------------------------------- SOLO
async function startSolo() {
  primeAudio();
  primeSpeech();                // iOS: タップの直後に解錠しておく
  mode = 'solo';
  team = null;
  detector.pickNextColor();
  showScreen('hunt');
  updateHuntUI();
  const ok = await startCamera();
  if (ok) runCountdown();
}

// ---------------------------------------------------------------- TEAM
function buildTeamGrid() {
  const grid = $('team-grid');
  grid.innerHTML = '';
  TEAM_ASSIGNMENTS.forEach((a) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'team-card';
    b.setAttribute('aria-label', 'チーム ' + a.teamNumber);
    b.innerHTML = '<small>TEAM</small><span>' + a.teamNumber + '</span>';
    b.addEventListener('click', () => startTeam(a.teamNumber));
    grid.appendChild(b);
  });
}

async function startTeam(number) {
  primeAudio();
  primeSpeech();
  const profile = teamProfile(number);
  if (!profile) return;
  mode = 'team';
  team = { number, profile, captureIDs: [], timingStartedAt: null, timeUp: false };
  stopTeamTimer();
  setTimerText(TEAM_DURATION);
  detector.activeProfile = profile;
  detector.reset();
  showScreen('hunt');
  updateHuntUI();
  const ok = await startCamera();
  if (ok) runCountdown();   // 色名を大きく出して読み上げる（確認画面は出さない）
}

function setTimerText(sec) {
  const s = Math.max(0, Math.ceil(sec));
  const el = $('team-timer');
  el.textContent = Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
  el.classList.toggle('is-warning', s <= TEAM_WARNING && s > 0);
}

function startTeamTimer() {
  team.timingStartedAt = Date.now();
  stopTeamTimer();
  teamTimer = setInterval(() => {
    if (!team) return stopTeamTimer();
    const left = TEAM_DURATION - (Date.now() - team.timingStartedAt) / 1000;
    setTimerText(left);
    if (left <= 0 && !team.timeUp) onTimeUp();
  }, 250);
}

function stopTeamTimer() {
  if (teamTimer) clearInterval(teamTimer);
  teamTimer = null;
}

async function onTimeUp() {
  team.timeUp = true;
  stopTeamTimer();
  updateHuntUI();
  // 保存の途中なら終わるまで待つ（データを壊さない）
  while (isCapturing) await sleep(100);
  $('timesup-sub').textContent = 'Found ' + team.captureIDs.length;
  $('timesup').classList.remove('hidden');
  await sleep(1800);
  finishTeam();
}

function finishTeam() {
  if (!team) return;
  stopTeamTimer();
  cancelCountdown();
  camera.stop();
  $('timesup').classList.add('hidden');
  $('finish-confirm').classList.add('hidden');
  showResult();
}

// ---------------------------------------------------------------- 撮影 → 自動保存
async function shoot() {
  if (!canShoot()) return;
  isCapturing = true;
  updateHuntUI();
  try {
    const profile = detector.activeProfile;
    const hsv = detector.foundHSV;
    const blob = await camera.capturePhoto();
    const rec = await saveCapture({
      blob, profile, hsv,
      mode, teamNumber: team ? team.number : null
    });
    if (team) team.captureIDs.push(rec.id);
    await flashSaved(blob);
  } catch (e) {
    showCameraMessage('しゃしんを ほぞん できませんでした。もういちど とってね');
    isCapturing = false;
    updateHuntUI();
    return;
  }
  isCapturing = false;

  if (mode === 'team') {
    if (team && team.timeUp) return;     // onTimeUp が結果へ進める
    detector.reset();                    // 同じ色を、もう一度さがす
    detector.resume();
    updateHuntUI();
  } else {
    detector.pickNextColor();            // SOLO は次の色へ
    updateHuntUI();
    runCountdown();
  }
}

async function flashSaved(blob) {
  const url = URL.createObjectURL(blob);
  $('saved-image').src = url;
  $('saved-flash').classList.remove('hidden');
  detector.pause();
  await sleep(1200);
  $('saved-flash').classList.add('hidden');
  URL.revokeObjectURL(url);
}

function leaveHuntToHome() {
  cancelCountdown();
  stopTeamTimer();
  camera.stop();
  detector.reset();
  team = null;
  mode = 'solo';
  showScreen('home');
}

// ---------------------------------------------------------------- RESULT
async function showResult() {
  releaseURLs();
  const all = await allCaptures();
  const byId = new Map(all.map((c) => [c.id, c]));
  const list = team.captureIDs.map((id) => byId.get(id)).filter(Boolean);
  const p = team.profile;

  $('result-team').textContent = 'TEAM ' + team.number;
  $('result-color').textContent = p.displayName;
  $('result-color').style.color = readableColor(p);
  $('result-swatch').style.background = p.tint;
  $('result-count').textContent = String(list.length);

  const grid = $('result-grid');
  grid.innerHTML = '';
  if (list.length === 0) {
    const e = document.createElement('div');
    e.className = 'result-empty';
    e.textContent = 'しゃしんは ありません';
    grid.appendChild(e);
  }
  list.forEach((c, i) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'thumb';
    b.setAttribute('aria-label', (i + 1) + 'まいめの しゃしん');
    const img = document.createElement('img');
    img.src = trackURL(URL.createObjectURL(c.blob));
    img.alt = '';
    b.appendChild(img);
    b.addEventListener('click', () => openViewer(list, i, p));
    grid.appendChild(b);
  });
  showScreen('result');
}

// ---------------------------------------------------------------- 写真を大きく（スワイプで前後）
function openViewer(list, index, profile) {
  viewer = { list, index, profile };
  $('viewer-color').textContent = profile.displayName;
  $('viewer-color').style.color = readableColor(profile);
  renderViewer();
  showScreen('viewer');
}

function renderViewer() {
  const { list, index } = viewer;
  const c = list[index];
  if (!c) return;
  $('viewer-image').src = trackURL(URL.createObjectURL(c.blob));
  $('viewer-index').textContent = (index + 1) + ' / ' + list.length;
  $('btn-prev').disabled = index <= 0;
  $('btn-next').disabled = index >= list.length - 1;
}

function moveViewer(step) {
  const next = viewer.index + step;
  if (next < 0 || next >= viewer.list.length) return;
  viewer.index = next;
  renderViewer();
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
    empty.innerHTML = '<p class="big">まだ しゃしんが ありません</p>';
    body.appendChild(empty);
  } else {
    const known = COLOR_PROFILES.map((p) => p.id);
    const sections = COLOR_PROFILES.map((p) => ({
      title: p.displayName, tint: p.tint, items: list.filter((c) => c.targetColor === p.id)
    }));
    sections.push({ title: 'OTHER', tint: '#737376', items: list.filter((c) => !known.includes(c.targetColor)) });

    sections.filter((s) => s.items.length > 0).forEach((s) => {
      const sec = document.createElement('section');
      sec.className = 'color-section';
      sec.innerHTML =
        '<div class="color-section-head"><span class="color-dot" style="background:' + s.tint +
        '"></span><span class="color-name">' + s.title + '</span><span class="color-count">' +
        s.items.length + '</span></div>';
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
  $('detail-date').textContent = new Date(rec.capturedAt).toLocaleString('ja-JP', {
    year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit'
  });
  showScreen('detail');
}

async function doShare(record) {
  const profile = profileById(record.targetColor);
  const result = await shareCapture(record, profile);
  if (result === 'unsupported') {
    await openBlobInNewTab(record, profile);
    alert('共有シートが つかえませんでした。\nひらいた画像を長おしして「写真に追加」してから、ロイロノートで えらんでください。');
  }
}

// ---------------------------------------------------------------- イベント
function wireEvents() {
  $('btn-solo').addEventListener('click', startSolo);
  $('btn-team').addEventListener('click', () => { buildTeamGrid(); showScreen('team'); });
  $('btn-team-back').addEventListener('click', () => showScreen('home'));
  $('btn-home-gallery').addEventListener('click', openGallery);

  $('btn-hunt-close').addEventListener('click', leaveHuntToHome);
  $('target-word').addEventListener('click', () => speak(detector.activeProfile.speechText));
  $('btn-shutter').addEventListener('click', shoot);
  $('btn-retry-camera').addEventListener('click', async () => {
    const ok = await startCamera();
    if (ok) runCountdown();
  });
  $('btn-permission-home').addEventListener('click', leaveHuntToHome);

  // FINISH は確認をはさむ（まちがって押しても消えないように）
  $('btn-finish').addEventListener('click', () => $('finish-confirm').classList.remove('hidden'));
  $('btn-finish-no').addEventListener('click', () => $('finish-confirm').classList.add('hidden'));
  $('btn-finish-yes').addEventListener('click', finishTeam);

  $('btn-result-home').addEventListener('click', () => {
    releaseURLs();
    team = null;
    mode = 'solo';
    showScreen('home');
  });

  $('btn-viewer-back').addEventListener('click', () => {
    if (team) { showScreen('result'); } else { openGallery(); }
  });
  $('btn-prev').addEventListener('click', () => moveViewer(-1));
  $('btn-next').addEventListener('click', () => moveViewer(1));
  $('btn-viewer-share').addEventListener('click', () => {
    const c = viewer.list[viewer.index];
    if (c) doShare(c);
  });
  // 左右スワイプ
  let touchX = null;
  const stage = $('screen-viewer');
  stage.addEventListener('touchstart', (e) => { touchX = e.touches[0].clientX; }, { passive: true });
  stage.addEventListener('touchend', (e) => {
    if (touchX === null) return;
    const dx = e.changedTouches[0].clientX - touchX;
    touchX = null;
    if (Math.abs(dx) > 50) moveViewer(dx < 0 ? 1 : -1);
  });

  $('btn-gallery-close').addEventListener('click', () => { releaseURLs(); showScreen('home'); });
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
    const url = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = 'library.json';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
  });

  // 先生用のかくれた数値表示（左下すみを1.5秒長おし）
  let holdTimer = null;
  const toggle = $('debug-toggle');
  const cancelHold = () => { if (holdTimer) clearTimeout(holdTimer); holdTimer = null; };
  toggle.addEventListener('pointerdown', () => {
    holdTimer = setTimeout(() => { detector.isDebugEnabled = !detector.isDebugEnabled; updateHuntUI(); }, 1500);
  });
  ['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) => toggle.addEventListener(ev, cancelHold));

  // 画面を離れたらカメラを止め、戻ったら再開する
  document.addEventListener('visibilitychange', async () => {
    if (document.hidden) {
      if (camera) camera.stop();
    } else if (currentScreen === 'hunt' && camera && !camera.isRunning) {
      await startCamera();
      detector.resume();
    }
  });
}

// ---------------------------------------------------------------- 起動
function boot() {
  detector = new Detector(randomHuntColor(null), updateHuntUI);
  camera = new Camera($('video'), {
    onSample: (hsv) => detector.ingest(hsv),
    onError: (msg) => {
      showCameraMessage(msg);
      $('permission-panel').classList.remove('hidden');
    }
  });

  wireEvents();
  updateHuntUI();

  // 検証用フック（?debug=1 のときだけ）。カメラが無くても流れを確かめられる。
  if (new URLSearchParams(location.search).has('debug')) {
    window.__colorHunt = {
      get state() { return { mode, team, currentScreen, isCapturing }; },
      detector, showScreen, runCountdown, startTeam, finishTeam, onTimeUp,
      /** 出題中の色ちょうどの色を流して FOUND にする */
      demoFound() {
        const p = detector.activeProfile;
        const r = p.hueRanges[0];
        const hsv = {
          h: r.from <= r.to ? (r.from + r.to) / 2 : r.from,
          s: (p.saturationRange.lower + p.saturationRange.upper) / 2,
          v: (p.brightnessRange.lower + p.brightnessRange.upper) / 2
        };
        detector.resume();
        const t0 = performance.now();
        const t = setInterval(() => { detector.ingest(hsv); if (performance.now() - t0 > 900) clearInterval(t); }, 50);
      },
      /** カメラの代わりに合成写真で「撮影 → 自動保存」を1回やる */
      async demoShoot() {
        const c = document.createElement('canvas');
        c.width = 600; c.height = 800;
        const g = c.getContext('2d');
        g.fillStyle = '#e8e8e8'; g.fillRect(0, 0, 600, 800);
        g.fillStyle = detector.activeProfile.tint;
        g.beginPath(); g.ellipse(300, 380, 180 + Math.random() * 60, 130, 0, 0, Math.PI * 2); g.fill();
        const blob = await new Promise((r) => c.toBlob(r, 'image/jpeg', 0.85));
        camera.isRunning = true;
        camera.capturePhoto = () => Promise.resolve(blob);
        detector.phase = 'found';
        await shoot();
      }
    };
  }

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => { navigator.serviceWorker.register('./sw.js').catch(() => {}); });
  }
}

boot();
