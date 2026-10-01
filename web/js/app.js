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
//
// 2026-09-30 追加:
//   ・はじめる前の画面（難易度＝いろの かず / じかん）を SOLO・TEAM 両方に置いた
//   ・SOLO にも じかん・Found の数・おわりの画面をつけた
//   ・1回ぶんを「セッション」として記録し、MY COLORS はセッションごとに並べる

import {
  TEAM_ASSIGNMENTS, TIME_WARNING, DIFFICULTIES, DEFAULT_DIFFICULTY, difficultyById,
  TIME_PRESETS_MIN, CUSTOM_TIME_RANGE, DEFAULT_LIMIT_MIN,
  profileById, randomHuntColor, teamProfile, readableColor
} from './colors.js';
import { Detector } from './detector.js';
import { Camera } from './camera.js';
import { speak, primeSpeech } from './speech.js';
import {
  saveCapture, allCaptures, getCapture, deleteCapture, exportLibraryJSON, groupBySession
} from './storage.js';
import { shareCapture, openBlobInNewTab } from './share.js';

const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- 状態
let detector = null;
let camera = null;
// いま遊んでいる1回ぶん（セッション）。null なら遊んでいない。
let run = null;   // { id, mode, teamNumber, profile, level, limitSeconds, startedAt, captureIDs, timingStartedAt, timeUp }
let runTimer = null;
let countdownToken = 0;
let isCapturing = false;
let objectURLs = [];
let audioCtx = null;
let detailRecord = null;
let viewer = { list: [], index: 0, from: 'result' };
// はじめる前の画面で選んでいる内容
let setup = { mode: 'solo', teamNumber: null, level: DEFAULT_DIFFICULTY, limitMin: DEFAULT_LIMIT_MIN.solo };
let customDraft = 10;        // 「そのほか」の分数

const isTeamRun = () => !!run && run.mode === 'team';

// ---------------------------------------------------------------- 設定の記憶
// 端末ごとに、前回えらんだ難易度と時間をおぼえておく（先生が毎回えらばなくてよい）。
const KEY = { level: 'colorhunt.level', soloLimit: 'colorhunt.limit.solo', teamLimit: 'colorhunt.limit.team' };

function loadSetting(key, fallback) {
  try {
    const v = localStorage.getItem(key);
    return v === null ? fallback : v;
  } catch (e) { return fallback; }
}

function saveSetting(key, value) {
  try { localStorage.setItem(key, String(value)); } catch (e) { /* 使えなくても続ける */ }
}

/** 0（なし）か 1〜20分だけを通す */
function cleanLimitMin(value, fallback) {
  const n = Math.round(Number(value));
  if (!Number.isFinite(n) || n < 0 || n > CUSTOM_TIME_RANGE.max) return fallback;
  return n;
}

function limitLabel(seconds) {
  return !seconds ? 'じかん なし' : Math.round(seconds / 60) + 'ふん';
}

function levelLabel(levelId) {
  const d = difficultyById(levelId);
  return d.label + '（' + d.colorIds.length + 'いろ）';
}

// ---------------------------------------------------------------- 画面
const SCREENS = ['home', 'team', 'setup', 'hunt', 'result', 'viewer', 'gallery', 'detail'];
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
  return !!run && detector.phase === 'found' && camera && camera.isRunning &&
    !isCapturing && !run.timeUp;
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
  const isTeam = isTeamRun();
  $('btn-hunt-close').classList.toggle('hidden', isTeam);   // SOLO は × でおわる
  $('btn-finish').classList.toggle('hidden', !isTeam);      // TEAM は FINISH
  $('team-badge').classList.toggle('hidden', !isTeam);
  if (isTeam) $('team-badge').textContent = 'TEAM ' + run.teamNumber;

  // Found の数はどちらのモードでも出す。時計は「じかん なし」のときだけ隠す。
  $('hunt-found').textContent = String(run ? run.captureIDs.length : 0);
  $('hunt-timer').classList.toggle('hidden', !run || !run.limitSeconds);

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
  // 3・2・1 が終わってから、じかんを数え始める
  if (run && run.limitSeconds && !run.timingStartedAt) startRunTimer();
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

// ---------------------------------------------------------------- はじめる前の画面
function openSetup(mode, teamNumber) {
  primeAudio();
  primeSpeech();                // iOS: タップの直後に音声を解錠しておく
  setup.mode = mode;
  setup.teamNumber = teamNumber == null ? null : teamNumber;
  if (mode === 'solo') {
    setup.level = difficultyById(loadSetting(KEY.level, DEFAULT_DIFFICULTY)).id;
    setup.limitMin = cleanLimitMin(loadSetting(KEY.soloLimit, DEFAULT_LIMIT_MIN.solo), DEFAULT_LIMIT_MIN.solo);
  } else {
    setup.limitMin = cleanLimitMin(loadSetting(KEY.teamLimit, DEFAULT_LIMIT_MIN.team), DEFAULT_LIMIT_MIN.team);
  }
  if (setup.limitMin > 0) customDraft = setup.limitMin;
  renderSetup();
  showScreen('setup');
}

function setLimitMin(minutes) {
  setup.limitMin = minutes;
  if (minutes > 0) customDraft = minutes;
  saveSetting(setup.mode === 'team' ? KEY.teamLimit : KEY.soloLimit, minutes);
  renderSetup();
}

/** 「そのほか」の −／＋。1〜20分のあいだで動かし、そのまま選んだことにする。 */
function stepCustom(delta) {
  const base = setup.limitMin > 0 ? setup.limitMin : customDraft;
  const next = Math.min(CUSTOM_TIME_RANGE.max, Math.max(CUSTOM_TIME_RANGE.min, base + delta));
  setLimitMin(next);
}

function setupSummary() {
  const parts = [];
  if (setup.mode === 'team') {
    const p = teamProfile(setup.teamNumber);
    parts.push('TEAM ' + setup.teamNumber + (p ? '：' + p.displayName : ''));
  } else {
    parts.push(levelLabel(setup.level));
  }
  parts.push(limitLabel(setup.limitMin * 60));
  return parts.join('・');
}

function renderSetup() {
  const isTeam = setup.mode === 'team';
  $('setup-title').textContent = isTeam ? 'TEAM ' + setup.teamNumber : 'SOLO HUNT';

  // TEAM は担当の色を確認する（タップで英語読み上げ）
  $('setup-team-color').classList.toggle('hidden', !isTeam);
  if (isTeam) {
    const p = teamProfile(setup.teamNumber);
    $('setup-swatch').style.background = p ? p.tint : '#dcdcdc';
    $('setup-color-name').textContent = p ? p.displayName : '';
    $('setup-color-name').style.color = p ? readableColor(p) : '';
  }

  // SOLO は いろの かず（難易度）をえらぶ
  $('setup-level-block').classList.toggle('hidden', isTeam);
  const levels = $('setup-levels');
  levels.innerHTML = '';
  DIFFICULTIES.forEach((d) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'chip' + (d.id === setup.level ? ' is-on' : '');
    b.appendChild(document.createTextNode(d.label));
    const small = document.createElement('small');
    small.textContent = d.colorIds.length + 'いろ';
    b.appendChild(small);
    b.addEventListener('click', () => {
      setup.level = d.id;
      saveSetting(KEY.level, d.id);
      renderSetup();
    });
    levels.appendChild(b);
  });

  // じかん
  const times = $('setup-times');
  times.innerHTML = '';
  TIME_PRESETS_MIN.forEach((m) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'chip' + (m === setup.limitMin ? ' is-on' : '');
    b.textContent = m === 0 ? 'なし' : m + 'ふん';
    b.addEventListener('click', () => setLimitMin(m));
    times.appendChild(b);
  });
  const isCustom = setup.limitMin > 0 && !TIME_PRESETS_MIN.includes(setup.limitMin);
  const custom = $('btn-time-custom');
  custom.textContent = (isCustom ? setup.limitMin : customDraft) + 'ふん';
  custom.classList.toggle('is-on', isCustom);

  $('setup-summary').textContent = setupSummary();
}

function newRunID() {
  if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
  return 'run-' + Date.now() + '-' + Math.floor(Math.random() * 1e6);
}

// ---------------------------------------------------------------- START
async function startRun() {
  primeAudio();
  primeSpeech();
  const isTeam = setup.mode === 'team';
  const profile = isTeam ? teamProfile(setup.teamNumber) : null;
  if (isTeam && !profile) return;

  run = {
    id: newRunID(),
    mode: setup.mode,
    teamNumber: isTeam ? setup.teamNumber : null,
    profile,
    level: isTeam ? null : setup.level,
    limitSeconds: setup.limitMin * 60,
    startedAt: new Date().toISOString(),
    captureIDs: [],
    timingStartedAt: null,
    timeUp: false
  };

  stopRunTimer();
  setTimerText(run.limitSeconds);
  detector.difficultyId = run.level;        // SOLO の出題色の範囲
  if (isTeam) {
    detector.activeProfile = profile;
    detector.reset();
  } else {
    detector.pickNextColor();
  }
  showScreen('hunt');
  updateHuntUI();
  const ok = await startCamera();
  if (ok) runCountdown();
}

// ---------------------------------------------------------------- TEAM をえらぶ
function buildTeamGrid() {
  const grid = $('team-grid');
  grid.innerHTML = '';
  TEAM_ASSIGNMENTS.forEach((a) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'team-card';
    b.setAttribute('aria-label', 'チーム ' + a.teamNumber);
    b.innerHTML = '<small>TEAM</small><span>' + a.teamNumber + '</span>';
    b.addEventListener('click', () => openSetup('team', a.teamNumber));
    grid.appendChild(b);
  });
}

function setTimerText(sec) {
  const s = Math.max(0, Math.ceil(sec));
  const el = $('hunt-timer');
  el.textContent = Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
  el.classList.toggle('is-warning', s <= TIME_WARNING && s > 0);
}

function startRunTimer() {
  if (!run || !run.limitSeconds) return;
  run.timingStartedAt = Date.now();
  stopRunTimer();
  runTimer = setInterval(() => {
    if (!run || !run.limitSeconds) return stopRunTimer();
    const left = run.limitSeconds - (Date.now() - run.timingStartedAt) / 1000;
    setTimerText(left);
    if (left <= 0 && !run.timeUp) onTimeUp();
  }, 250);
}

function stopRunTimer() {
  if (runTimer) clearInterval(runTimer);
  runTimer = null;
}

async function onTimeUp() {
  if (!run) return;
  run.timeUp = true;
  stopRunTimer();
  cancelCountdown();          // 次の色の 3・2・1 の途中でも止める
  detector.pause();
  updateHuntUI();
  // 保存の途中なら終わるまで待つ（データを壊さない）
  while (isCapturing) await sleep(100);
  $('timesup-sub').textContent = 'Found ' + run.captureIDs.length;
  $('timesup').classList.remove('hidden');
  await sleep(1800);
  finishRun();
}

function finishRun() {
  if (!run) return;
  stopRunTimer();
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
      mode: run.mode, teamNumber: run.teamNumber,
      sessionID: run.id, sessionStartedAt: run.startedAt,
      level: run.level, limitSeconds: run.limitSeconds
    });
    run.captureIDs.push(rec.id);
    await flashSaved(blob);
  } catch (e) {
    showCameraMessage('しゃしんを ほぞん できませんでした。もういちど とってね');
    isCapturing = false;
    updateHuntUI();
    return;
  }
  isCapturing = false;

  if (run.timeUp) return;                // onTimeUp が結果へ進める
  if (run.mode === 'team') {
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
  stopRunTimer();
  camera.stop();
  detector.reset();
  run = null;
  showScreen('home');
}

// ---------------------------------------------------------------- 写真1枚のボタン
/** withName が true なら色の名前を写真の下に出す（SOLO は色がまざるため） */
function thumbButton(record, withName, onClick) {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = 'thumb';
  b.setAttribute('aria-label', (record.displayName || '') + 'の しゃしん');
  const img = document.createElement('img');
  img.src = trackURL(URL.createObjectURL(record.blob));
  img.alt = '';
  b.appendChild(img);
  if (withName) {
    const cap = document.createElement('span');
    cap.className = 'thumb-cap';
    cap.textContent = record.displayName || '';
    b.appendChild(cap);
  }
  b.addEventListener('click', onClick);
  return b;
}

// ---------------------------------------------------------------- RESULT
async function showResult() {
  releaseURLs();
  const all = await allCaptures();
  const byId = new Map(all.map((c) => [c.id, c]));
  const list = run.captureIDs.map((id) => byId.get(id)).filter(Boolean);
  const isTeam = run.mode === 'team';
  const p = run.profile;

  $('result-title').textContent = isTeam ? 'TEAM ' + run.teamNumber : 'SOLO HUNT';
  $('result-color-row').classList.toggle('hidden', !isTeam || !p);
  if (isTeam && p) {
    $('result-color').textContent = p.displayName;
    $('result-color').style.color = readableColor(p);
    $('result-swatch').style.background = p.tint;
  }
  $('result-sub').textContent = isTeam
    ? limitLabel(run.limitSeconds)
    : levelLabel(run.level) + '・' + limitLabel(run.limitSeconds);
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
    grid.appendChild(thumbButton(c, !isTeam, () => openViewer(list, i, 'result')));
  });
  showScreen('result');
}

// ---------------------------------------------------------------- 写真を大きく（スワイプで前後）
function openViewer(list, index, from) {
  viewer = { list, index, from: from || 'result' };
  renderViewer();
  showScreen('viewer');
}

function renderViewer() {
  const { list, index } = viewer;
  const c = list[index];
  if (!c) return;
  const p = profileById(c.targetColor);
  $('viewer-color').textContent = c.displayName || (p ? p.displayName : '');
  $('viewer-color').style.color = p ? readableColor(p) : '';
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
/** 「9月30日 10:15」。セッション情報が無い古い写真は日付だけ。 */
function sessionWhen(g) {
  const d = new Date(g.startedAt);
  const date = d.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' });
  if (!g.sessionID) return date;
  return date + ' ' + d.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
}

/** 「SOLO・かんたん・3ふん」「TEAM 4・YELLOW・5ふん」 */
function sessionWhat(g) {
  if (!g.sessionID) return 'これより まえの しゃしん';
  const parts = [];
  if (g.mode === 'team') {
    parts.push('TEAM ' + (g.teamNumber == null ? '?' : g.teamNumber));
    const p = teamProfile(g.teamNumber);
    if (p) parts.push(p.displayName);
  } else {
    parts.push('SOLO');
    if (g.level) parts.push(difficultyById(g.level).label);
  }
  if (g.limitSeconds != null) parts.push(limitLabel(g.limitSeconds));
  return parts.join('・');
}

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
    // 1回の活動（セッション）ごとに、何枚とれたかと写真を並べる
    groupBySession(list).forEach((g) => {
      const sec = document.createElement('section');
      sec.className = 'session';

      const head = document.createElement('div');
      head.className = 'session-head';
      const when = document.createElement('span');
      when.className = 'session-when';
      when.textContent = sessionWhen(g);
      const what = document.createElement('span');
      what.className = 'session-what';
      what.textContent = sessionWhat(g);
      const count = document.createElement('span');
      count.className = 'session-count';
      count.textContent = g.items.length + 'まい';
      head.appendChild(when);
      head.appendChild(what);
      head.appendChild(count);
      sec.appendChild(head);

      const grid = document.createElement('div');
      grid.className = 'color-grid';
      g.items.forEach((c) => grid.appendChild(thumbButton(c, true, () => openDetail(c.id))));
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
  $('btn-solo').addEventListener('click', () => openSetup('solo'));
  $('btn-team').addEventListener('click', () => { buildTeamGrid(); showScreen('team'); });
  $('btn-team-back').addEventListener('click', () => showScreen('home'));
  $('btn-home-gallery').addEventListener('click', openGallery);

  // はじめる前の画面
  $('btn-setup-back').addEventListener('click', () => showScreen(setup.mode === 'team' ? 'team' : 'home'));
  $('setup-team-color').addEventListener('click', () => {
    const p = teamProfile(setup.teamNumber);
    if (p) speak(p.speechText);
  });
  $('btn-time-minus').addEventListener('click', () => stepCustom(-1));
  $('btn-time-plus').addEventListener('click', () => stepCustom(1));
  $('btn-time-custom').addEventListener('click', () => setLimitMin(customDraft));
  $('btn-start').addEventListener('click', startRun);

  // SOLO は × でおわる（まちがって押しても消えないように確認する）
  $('btn-hunt-close').addEventListener('click', () => $('finish-confirm').classList.remove('hidden'));
  $('target-word').addEventListener('click', () => speak(detector.activeProfile.speechText));
  $('btn-shutter').addEventListener('click', shoot);
  $('btn-retry-camera').addEventListener('click', async () => {
    const ok = await startCamera();
    if (ok) runCountdown();
  });
  $('btn-permission-home').addEventListener('click', leaveHuntToHome);

  // FINISH も確認をはさむ
  $('btn-finish').addEventListener('click', () => $('finish-confirm').classList.remove('hidden'));
  $('btn-finish-no').addEventListener('click', () => $('finish-confirm').classList.add('hidden'));
  $('btn-finish-yes').addEventListener('click', finishRun);

  $('btn-result-home').addEventListener('click', () => {
    releaseURLs();
    run = null;
    showScreen('home');
  });

  $('btn-viewer-back').addEventListener('click', () => {
    if (viewer.from === 'gallery') { openGallery(); } else { showScreen('result'); }
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
  detector = new Detector(randomHuntColor(null, DEFAULT_DIFFICULTY), updateHuntUI);
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
      get state() { return { run, setup, currentScreen, isCapturing }; },
      detector, showScreen, runCountdown, openSetup, startRun, finishRun, onTimeUp,
      /** 開始前画面をとばして、その場で遊び始める（検証用） */
      quickStart(mode, opts) {
        openSetup(mode, opts && opts.teamNumber);
        if (opts && opts.level) setup.level = opts.level;
        if (opts && opts.limitMin != null) setup.limitMin = opts.limitMin;
        return startRun();
      },
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
