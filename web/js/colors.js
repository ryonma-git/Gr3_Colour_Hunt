// ============================================================================
//  Color Hunt Web — 色の定義と判定のチューニング
//
//  ★ 判定に関わる数値はこのファイルだけにある。
//    調整するときはここを直して保存し、ブラウザを再読み込みするだけ。
//
//  Swift 版 (ColorHunt.swiftpm/Models/ColorProfile.swift) と同じ数値。
//  片方を変えたらもう片方も合わせること。
// ============================================================================

/** 色相の範囲。from > to のときは 360度をまたぐ範囲として扱う。 */
const hue = (from, to) => ({ from, to });

/** 0...1 の範囲 */
const range = (lower, upper) => ({ lower, upper });

export const COLOR_PROFILES = [
  {
    id: 'red',
    displayName: 'RED',
    speechText: 'Red',
    hueRanges: [hue(345, 360), hue(0, 14)],
    saturationRange: range(0.45, 1.0),   // これ未満は「肌」や「ピンク」
    brightnessRange: range(0.20, 1.0),
    difficulty: 'basic',
    profileVersion: 1,
    tint: '#e62929'
  },
  {
    id: 'orange',
    displayName: 'ORANGE',
    speechText: 'Orange',
    hueRanges: [hue(16, 44)],
    saturationRange: range(0.65, 1.0),   // 木の机・肌をはじくため高め
    brightnessRange: range(0.50, 1.0),
    difficulty: 'basic',
    profileVersion: 1,
    tint: '#f2851a'
  },
  {
    id: 'yellow',
    displayName: 'YELLOW',
    speechText: 'Yellow',
    hueRanges: [hue(45, 70)],
    saturationRange: range(0.40, 1.0),
    brightnessRange: range(0.55, 1.0),   // 暗いとオリーブ色なので明るい方だけ
    difficulty: 'basic',
    profileVersion: 1,
    tint: '#f7c71a'
  },
  {
    id: 'green',
    displayName: 'GREEN',
    speechText: 'Green',
    hueRanges: [hue(75, 165)],
    saturationRange: range(0.25, 1.0),
    brightnessRange: range(0.15, 1.0),   // 黒板の濃い緑も通す
    difficulty: 'basic',
    profileVersion: 1,
    tint: '#2eb354'
  },
  {
    id: 'blue',
    displayName: 'BLUE',
    speechText: 'Blue',
    hueRanges: [hue(195, 250)],
    saturationRange: range(0.35, 1.0),
    brightnessRange: range(0.18, 1.0),   // 紺色も通す
    difficulty: 'basic',
    profileVersion: 1,
    tint: '#216be6'
  },
  {
    id: 'purple',
    displayName: 'PURPLE',
    speechText: 'Purple',
    hueRanges: [hue(255, 305)],
    saturationRange: range(0.25, 1.0),
    brightnessRange: range(0.18, 1.0),
    difficulty: 'basic',
    profileVersion: 1,
    tint: '#8c4dc7'
  },
  {
    // PINK は「赤と同じ色相だが、うすい・明るい」で分ける。
    // 色相だけに頼らない設計の実例。
    id: 'pink',
    displayName: 'PINK',
    speechText: 'Pink',
    hueRanges: [hue(310, 360), hue(0, 8)],
    saturationRange: range(0.18, 0.70),  // 0.70 より濃いものは RED 扱い
    brightnessRange: range(0.60, 1.0),   // 暗いピンクは無い
    difficulty: 'basic',
    profileVersion: 1,
    tint: '#f273a6'
  }
];

/** ★ 授業で出題する色。減らせば、その色だけが出る。
 *    例: 最初の授業は3色だけ
 *    export const HUNT_COLOR_IDS = ['red', 'blue', 'yellow'];
 */
export const HUNT_COLOR_IDS = COLOR_PROFILES.map((p) => p.id);

/** 判定の広さ以外の調整値 */
export const TUNING = {
  /** 画面中央から取り出す正方形の一辺（ピクセル）。5〜9 くらいで調整する。 */
  sampleSize: 7,
  /** 1秒あたりに色を調べる回数 */
  samplesPerSecond: 12,
  /** 何秒つづけて条件を満たしたら「みつけた」にするか */
  stableDuration: 0.5,
  /** 手ぶれ対策。この秒数だけ外れても、まだ当たっているとみなす */
  releaseGrace: 0.2,
  /** みつけた状態を解除するまでの時間（みつけるのと同じ長さ） */
  foundReleaseDuration: 0.5
};

// ---------------------------------------------------------------------------

function hueContains(r, h) {
  let x = h % 360;
  if (x < 0) x += 360;
  return r.from <= r.to
    ? x >= r.from && x <= r.to
    : x >= r.from || x <= r.to;
}

/** 中央の色がこのプロファイルの条件を満たすか */
export function matches(profile, hsv) {
  const { saturationRange: s, brightnessRange: v } = profile;
  if (hsv.s < s.lower || hsv.s > s.upper) return false;
  if (hsv.v < v.lower || hsv.v > v.upper) return false;
  return profile.hueRanges.some((r) => hueContains(r, hsv.h));
}

export function profileById(id) {
  return COLOR_PROFILES.find((p) => p.id === id) || null;
}

export function huntColors() {
  return COLOR_PROFILES.filter((p) => HUNT_COLOR_IDS.includes(p.id));
}

/** 次に出す色をランダムに選ぶ。直前と同じ色は選ばない。 */
export function randomHuntColor(current) {
  const all = huntColors();
  const pool = all.filter((p) => !current || p.id !== current.id);
  const from = pool.length > 0 ? pool : all;
  return from[Math.floor(Math.random() * from.length)];
}
