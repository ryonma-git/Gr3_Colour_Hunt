// 「いま画面中央にある色が、さがしている色かどうか」を判定する。
// Swift 版 ColorDetectionService.swift と同じ考え方。
//
// - stableDuration 秒つづけて条件を満たしたら found
// - found のあと foundReleaseDuration 秒つづけて外れたら searching に戻る
//   （カメラを別のものに向ければ、また探し直せる）

import { TUNING, matches, randomHuntColor } from './colors.js';

const now = () => performance.now() / 1000;

export class Detector {
  constructor(profile, onChange) {
    this.activeProfile = profile;
    this.onChange = onChange || (() => {});
    this.phase = 'searching';       // 'searching' | 'found'
    this.isMatchingNow = false;
    this.foundHSV = null;
    this.debugHSV = null;
    this.isDebugEnabled = false;

    this._matchStartedAt = null;
    this._mismatchStartedAt = null;
    this._paused = true;
  }

  /** 次にさがす色をランダムに決める。直前と同じ色は出ない。 */
  pickNextColor() {
    this.activeProfile = randomHuntColor(this.activeProfile);
    this.reset();
  }

  reset() {
    this.phase = 'searching';
    this.isMatchingNow = false;
    this.foundHSV = null;
    this._matchStartedAt = null;
    this._mismatchStartedAt = null;
    this.onChange();
  }

  pause() {
    this._paused = true;
    this.isMatchingNow = false;
    this._matchStartedAt = null;
    this._mismatchStartedAt = null;
    this.onChange();
  }

  resume() {
    this._paused = false;
    this._matchStartedAt = null;
    this._mismatchStartedAt = null;
  }

  /** カメラから届いた中央の色を1回分うけとる */
  ingest(hsv) {
    if (this.isDebugEnabled) this.debugHSV = hsv;
    if (this._paused) return;

    const t = now();
    const hit = matches(this.activeProfile, hsv);
    let changed = false;

    if (hit) {
      this._mismatchStartedAt = null;
      if (this._matchStartedAt === null) this._matchStartedAt = t;
      if (!this.isMatchingNow) {
        this.isMatchingNow = true;
        changed = true;
      }
      if (this.phase === 'searching' &&
          t - this._matchStartedAt >= TUNING.stableDuration) {
        this.foundHSV = hsv;
        this.phase = 'found';
        changed = true;
      }
    } else {
      if (this._mismatchStartedAt === null) this._mismatchStartedAt = t;
      const off = t - this._mismatchStartedAt;

      // 少しの手ぶれでは切らない
      if (off < TUNING.releaseGrace) {
        if (changed) this.onChange();
        return;
      }

      this._matchStartedAt = null;
      if (this.isMatchingNow) {
        this.isMatchingNow = false;
        changed = true;
      }
      // 外れつづけたら「みつけた」を解除して、また探し始められるようにする
      if (this.phase === 'found' && off >= TUNING.foundReleaseDuration) {
        this.phase = 'searching';
        this.foundHSV = null;
        changed = true;
      }
    }

    if (changed || this.isDebugEnabled) this.onChange();
  }
}
