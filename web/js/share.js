// ロイロノートへの共有。専用APIは使わず、iOS 標準の共有シート
// (navigator.share) を呼ぶ。Swift 版 ShareService.swift にあたる。

/** 送る画像の種類。'card' = 発表用の1枚 / 'photo' = 撮った写真そのまま */
export const SHARE_STYLE = 'card';

const CARD_W = 1200;
const CARD_H = 1560;

function loadImage(blob) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('image load failed'));
    };
    img.src = url;
  });
}

function fontStack(size, weight) {
  return weight + ' ' + size + 'px -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Helvetica Neue", sans-serif';
}

/** 発表用の1枚（色の名前 / 写真 / I found X.）をつくる */
async function makeCard(blob, capture, profile) {
  const img = await loadImage(blob);
  const canvas = document.createElement('canvas');
  canvas.width = CARD_W;
  canvas.height = CARD_H;
  const ctx = canvas.getContext('2d');

  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, CARD_W, CARD_H);

  // 上: 色の名前
  ctx.fillStyle = profile ? profile.tint : '#1c1c1e';
  ctx.font = fontStack(150, '800');
  ctx.textAlign = 'center';
  ctx.textBaseline = 'alphabetic';
  ctx.fillText(capture.displayName, CARD_W / 2, 200);

  // 中: 写真（縦横比を保って収める）
  const box = { x: 60, y: 250, w: 1080, h: 1080 };
  ctx.fillStyle = '#efefef';
  ctx.fillRect(box.x, box.y, box.w, box.h);
  const scale = Math.min(box.w / img.width, box.h / img.height);
  const dw = img.width * scale;
  const dh = img.height * scale;
  ctx.drawImage(img, box.x + (box.w - dw) / 2, box.y + (box.h - dh) / 2, dw, dh);

  // 下: 発表のことば
  ctx.fillStyle = '#111111';
  ctx.font = fontStack(82, '600');
  ctx.fillText('I found ' + capture.displayName + '.', CARD_W / 2, 1455);

  return new Promise((resolve) => {
    canvas.toBlob((b) => resolve(b || blob), 'image/jpeg', 0.9);
  });
}

function fileName(capture) {
  const d = new Date(capture.capturedAt);
  const p = (n) => String(n).padStart(2, '0');
  const stamp =
    d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + '-' + p(d.getHours()) + p(d.getMinutes());
  return 'ColorHunt_' + capture.displayName + '_' + stamp + '.jpg';
}

/** 共有用の画像（Blob）をつくる */
export async function makeShareBlob(capture, profile) {
  if (SHARE_STYLE !== 'card') return capture.blob;
  try {
    return await makeCard(capture.blob, capture, profile);
  } catch (e) {
    return capture.blob; // カードが作れなくても写真は送れるようにする
  }
}

/**
 * 共有シートを開く。
 * @returns {'shared'|'cancelled'|'unsupported'}
 */
export async function shareCapture(capture, profile) {
  const blob = await makeShareBlob(capture, profile);
  const file = new File([blob], fileName(capture), { type: 'image/jpeg' });

  if (navigator.canShare && navigator.canShare({ files: [file] }) && navigator.share) {
    try {
      await navigator.share({ files: [file] });
      return 'shared';
    } catch (e) {
      if (e && e.name === 'AbortError') return 'cancelled';
      return 'unsupported';
    }
  }
  return 'unsupported';
}

/** 共有シートが使えないときの逃げ道: 画像を別タブで開いて長押し保存してもらう */
export async function openBlobInNewTab(capture, profile) {
  const blob = await makeShareBlob(capture, profile);
  const url = URL.createObjectURL(blob);
  window.open(url, '_blank');
  setTimeout(() => URL.revokeObjectURL(url), 60000);
}
