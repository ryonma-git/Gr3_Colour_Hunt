// 写真とメタデータの保存。
// Swift 版 StorageService.swift にあたるが、Web では「ファイル」アプリに
// 直接書けないので IndexedDB に保存する。
//
// 記録する項目は library.json と同じ。
// 「データをかきだす」で library.json 互換の JSON を取り出せる。

const DB_NAME = 'colorhunt';
const DB_VERSION = 1;
const STORE = 'captures';
// schemaVersion 3: 1回の活動（セッション）の情報を写真にもたせた。
//   sessionID / sessionStartedAt / level（難易度）/ limitSeconds（時間制限・0はなし）
//   古い写真にはこれらが無い。履歴では日付ごとにまとめて表示する。
export const SCHEMA_VERSION = 3;

let dbPromise = null;

function openDB() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        const store = db.createObjectStore(STORE, { keyPath: 'id' });
        store.createIndex('capturedAt', 'capturedAt');
        store.createIndex('targetColor', 'targetColor');
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbPromise;
}

function tx(mode) {
  return openDB().then((db) => db.transaction(STORE, mode).objectStore(STORE));
}

function uuid() {
  if (crypto && crypto.randomUUID) return crypto.randomUUID();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/** シャッターを押したときに呼ばれる。正式保存。 */
export async function saveCapture({
  blob, profile, hsv, mode = 'solo', teamNumber = null,
  sessionID = null, sessionStartedAt = null, level = null, limitSeconds = null
}) {
  const id = uuid();
  const record = {
    id,
    targetColor: profile.id,
    displayName: profile.displayName,
    imageFile: 'photos/' + id + '.jpg',
    capturedAt: new Date().toISOString(),
    difficulty: profile.difficulty,
    colorProfileVersion: profile.profileVersion,
    sampledHSV: hsv
      ? { h: Number(hsv.h.toFixed(2)), s: Number(hsv.s.toFixed(3)), v: Number(hsv.v.toFixed(3)) }
      : { h: 0, s: 0, v: 0 },
    mode,
    teamNumber,
    sessionID,
    sessionStartedAt,
    level,
    limitSeconds,
    blob
  };
  const store = await tx('readwrite');
  await new Promise((resolve, reject) => {
    const req = store.add(record);
    req.onsuccess = resolve;
    req.onerror = () => reject(req.error);
  });
  return record;
}

/** 新しい順 */
export async function allCaptures() {
  const store = await tx('readonly');
  const list = await new Promise((resolve, reject) => {
    const req = store.getAll();
    req.onsuccess = () => resolve(req.result || []);
    req.onerror = () => reject(req.error);
  });
  return list.sort((a, b) => (a.capturedAt < b.capturedAt ? 1 : -1));
}

/** 履歴を「1回の活動（セッション）」ごとにまとめる。新しい活動が先頭。
 *  セッション情報の無い古い写真は、日付ごとにまとめる。 */
export function groupBySession(list) {
  // 日付は端末の時刻で数える（UTC の文字列で切ると、朝の写真が前日にまざる）
  const localDay = (iso) => {
    const d = new Date(iso);
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  };
  const groups = new Map();
  list.forEach((c) => {
    const isSession = !!c.sessionID;
    const key = isSession ? 'session:' + c.sessionID : 'day:' + localDay(c.capturedAt);
    let g = groups.get(key);
    if (!g) {
      g = {
        key,
        sessionID: c.sessionID || null,
        mode: isSession ? c.mode || 'solo' : null,
        teamNumber: isSession && c.teamNumber != null ? c.teamNumber : null,
        level: isSession ? c.level || null : null,
        limitSeconds: isSession && c.limitSeconds != null ? c.limitSeconds : null,
        startedAt: c.sessionStartedAt || c.capturedAt,
        items: []
      };
      groups.set(key, g);
    }
    g.items.push(c);
    const when = c.sessionStartedAt || c.capturedAt;
    if (String(when) < String(g.startedAt)) g.startedAt = when;
  });
  const out = Array.from(groups.values());
  out.forEach((g) => g.items.sort((a, b) => (a.capturedAt < b.capturedAt ? -1 : 1)));  // 撮った順
  out.sort((a, b) => (a.startedAt < b.startedAt ? 1 : -1));                            // 新しい活動が上
  return out;
}

export async function getCapture(id) {
  const store = await tx('readonly');
  return new Promise((resolve, reject) => {
    const req = store.get(id);
    req.onsuccess = () => resolve(req.result || null);
    req.onerror = () => reject(req.error);
  });
}

export async function deleteCapture(id) {
  const store = await tx('readwrite');
  return new Promise((resolve, reject) => {
    const req = store.delete(id);
    req.onsuccess = resolve;
    req.onerror = () => reject(req.error);
  });
}

/** library.json 互換の JSON（画像本体は含まない） */
export async function exportLibraryJSON() {
  const list = await allCaptures();
  const captures = list.map((c) => ({
    id: c.id,
    targetColor: c.targetColor,
    displayName: c.displayName,
    imageFile: c.imageFile,
    capturedAt: c.capturedAt,
    difficulty: c.difficulty,
    colorProfileVersion: c.colorProfileVersion,
    sampledHSV: c.sampledHSV,
    mode: c.mode || 'solo',
    teamNumber: c.teamNumber == null ? null : c.teamNumber,
    sessionID: c.sessionID || null,
    sessionStartedAt: c.sessionStartedAt || null,
    level: c.level || null,
    limitSeconds: c.limitSeconds == null ? null : c.limitSeconds
  }));
  return JSON.stringify({ schemaVersion: SCHEMA_VERSION, captures }, null, 2);
}
