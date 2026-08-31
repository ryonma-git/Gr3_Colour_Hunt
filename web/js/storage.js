// 写真とメタデータの保存。
// Swift 版 StorageService.swift にあたるが、Web では「ファイル」アプリに
// 直接書けないので IndexedDB に保存する。
//
// 記録する項目は library.json と同じ。
// 「データをかきだす」で library.json 互換の JSON を取り出せる。

const DB_NAME = 'colorhunt';
const DB_VERSION = 1;
const STORE = 'captures';
export const SCHEMA_VERSION = 1;

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

/** 「この しゃしんに する」で呼ばれる。正式保存。 */
export async function saveCapture({ blob, profile, hsv }) {
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
    sampledHSV: c.sampledHSV
  }));
  return JSON.stringify({ schemaVersion: SCHEMA_VERSION, captures }, null, 2);
}
