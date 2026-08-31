// カメラの起動・中央の色の取り出し・写真撮影。
// Swift 版 CameraService.swift にあたる。

import { TUNING } from './colors.js';
import { rgbToHsv } from './hsv.js';

/** 保存する写真の長辺の最大ピクセル数 */
const MAX_PHOTO_SIZE = 2048;
const JPEG_QUALITY = 0.85;

export class Camera {
  constructor(videoEl, { onSample, onError }) {
    this.video = videoEl;
    this.onSample = onSample || (() => {});
    this.onError = onError || (() => {});
    this.stream = null;
    this.timer = null;
    this.isRunning = false;

    // 中央の小領域だけを取り出すための小さなキャンバス
    this.sampleCanvas = document.createElement('canvas');
    this.sampleCanvas.width = TUNING.sampleSize;
    this.sampleCanvas.height = TUNING.sampleSize;
    this.sampleCtx = this.sampleCanvas.getContext('2d', { willReadFrequently: true });
  }

  async start() {
    if (this.isRunning) return true;
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.onError('このブラウザではカメラをつかえません。Safari でひらいてください。');
      return false;
    }
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280 },
          height: { ideal: 960 }
        },
        audio: false
      });
    } catch (err) {
      if (err && (err.name === 'NotAllowedError' || err.name === 'SecurityError')) {
        this.onError('カメラを つかうために きょかが ひつようです。');
      } else if (err && err.name === 'NotFoundError') {
        this.onError('カメラが 見つかりませんでした。');
      } else {
        this.onError('カメラを ひらけませんでした。もういちど ためしてください。');
      }
      return false;
    }

    this.video.srcObject = this.stream;
    this.video.setAttribute('playsinline', '');
    this.video.muted = true;
    try {
      await this.video.play();
    } catch (e) {
      // 自動再生できなくても、あとで play される
    }

    this.isRunning = true;
    const interval = Math.round(1000 / TUNING.samplesPerSecond);
    this.timer = setInterval(() => this.sampleCenter(), interval);
    return true;
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    if (this.stream) {
      this.stream.getTracks().forEach((t) => t.stop());
      this.stream = null;
    }
    this.video.srcObject = null;
    this.isRunning = false;
  }

  /**
   * 画面中央の小さな正方形（既定 7x7 ピクセル）の平均色を HSV で返す。
   * 円全体ではなく、ごく狭い中央だけを見るのが Color Hunt の判定方針。
   * video は object-fit: cover で表示しているので、映像の中心＝画面の中心。
   */
  sampleCenter() {
    const v = this.video;
    const w = v.videoWidth;
    const h = v.videoHeight;
    const n = TUNING.sampleSize;
    if (!w || !h || w < n || h < n) return;

    const sx = Math.floor(w / 2 - n / 2);
    const sy = Math.floor(h / 2 - n / 2);

    try {
      this.sampleCtx.drawImage(v, sx, sy, n, n, 0, 0, n, n);
      const data = this.sampleCtx.getImageData(0, 0, n, n).data;
      let r = 0, g = 0, b = 0;
      const count = n * n;
      for (let i = 0; i < data.length; i += 4) {
        r += data[i];
        g += data[i + 1];
        b += data[i + 2];
      }
      const d = count * 255;
      this.onSample(rgbToHsv(r / d, g / d, b / d));
    } catch (e) {
      // フレームがまだ来ていないときは黙って次へ
    }
  }

  /** いまのカメラ画像を1枚撮る。長辺 2048px までに縮めて JPEG にする。 */
  capturePhoto() {
    return new Promise((resolve, reject) => {
      const v = this.video;
      const w = v.videoWidth;
      const h = v.videoHeight;
      if (!w || !h) {
        reject(new Error('no frame'));
        return;
      }
      const scale = Math.min(1, MAX_PHOTO_SIZE / Math.max(w, h));
      const canvas = document.createElement('canvas');
      canvas.width = Math.round(w * scale);
      canvas.height = Math.round(h * scale);
      const ctx = canvas.getContext('2d');
      ctx.drawImage(v, 0, 0, canvas.width, canvas.height);
      canvas.toBlob(
        (blob) => (blob ? resolve(blob) : reject(new Error('toBlob failed'))),
        'image/jpeg',
        JPEG_QUALITY
      );
    });
  }
}
