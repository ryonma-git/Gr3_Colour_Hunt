// ============================================================================
//  Color Hunt Web — 色の定義と判定のチューニング
//
//  ★ 判定に関わる数値はこのファイルだけにある。
//    調整するときはここを直して保存し、ブラウザを再読み込みするだけ。
//
//  Swift 版 (ColorHunt_team.swiftpm/Models/ColorProfile.swift) と同じ数値。
//  片方を変えたらもう片方も合わせること。
//
//  profileVersion 2（2026-09-14）: 授業で PURPLE・YELLOW などが反応しにくかったので、
//  外れていた境界をゆるめた。ORANGE だけは変更なし。
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
    hueRanges: [hue(340, 360), hue(0, 14)],
    saturationRange: range(0.45, 1.0),   // これ未満は「肌」や「ピンク」
    brightnessRange: range(0.20, 1.0),
    difficulty: 'basic',
    profileVersion: 2,
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
    hueRanges: [hue(40, 75)],            // 山吹色からテニスボールの黄色まで
    saturationRange: range(0.28, 1.0),   // 光って白っぽく写った黄色も通す
    brightnessRange: range(0.45, 1.0),   // 影の黄色も通す（これより暗いとオリーブ色）
    difficulty: 'basic',
    profileVersion: 2,
    tint: '#f7c71a'
  },
  {
    id: 'green',
    displayName: 'GREEN',
    speechText: 'Green',
    hueRanges: [hue(70, 175)],           // 黄緑から青緑まで
    saturationRange: range(0.20, 1.0),   // うすい緑も通す
    brightnessRange: range(0.15, 1.0),   // 黒板の濃い緑も通す
    difficulty: 'basic',
    profileVersion: 2,
    tint: '#2eb354'
  },
  {
    id: 'blue',
    displayName: 'BLUE',
    speechText: 'Blue',
    hueRanges: [hue(180, 250)],          // ターコイズから紺色まで
    saturationRange: range(0.22, 1.0),   // うすい水色（空色）も通す
    brightnessRange: range(0.18, 1.0),   // 紺色も通す
    difficulty: 'basic',
    profileVersion: 2,
    tint: '#216be6'
  },
  {
    id: 'purple',
    displayName: 'PURPLE',
    speechText: 'Purple',
    hueRanges: [hue(245, 325)],          // カメラで青っぽく写る紫から赤むらさきまで
    saturationRange: range(0.18, 1.0),   // ラベンダーなど、うすい紫も通す
    brightnessRange: range(0.22, 1.0),   // S を下げたぶん、黒い服を拾わないよう少し上げた
    difficulty: 'basic',
    profileVersion: 2,
    tint: '#8c4dc7'
  },
  {
    // PINK は2つの範囲の合わせ技。色相だけに頼らない設計の実例。
    //  ① 赤と同じ色相の「うすい赤」（ももいろ）。こい赤は RED なので S は 0.70 まで
    //  ② 赤むらさき寄りの色相の「こいピンク」（ピンクのペンなど）。
    //     この色相に RED は無いので S の上限をなくした
    id: 'pink',
    displayName: 'PINK',
    speechText: 'Pink',
    hueRanges: [hue(340, 360), hue(0, 8)],
    saturationRange: range(0.15, 0.70),  // 0.70 より濃いものは RED 扱い
    brightnessRange: range(0.60, 1.0),   // 暗いピンクは無い
    extraRegions: [
      { hueRanges: [hue(300, 340)], saturationRange: range(0.15, 1.0), brightnessRange: range(0.60, 1.0) }
    ],
    difficulty: 'basic',
    profileVersion: 2,
    tint: '#f273a6'
  },
  {
    // TEAM 8 用。ORANGE と色相が同じなので彩度で分ける（Swift 版と同じ数値）。
    // 注意: 暗めの肌は BROWN の範囲に入る（HSV では分離できない）。
    id: 'brown',
    displayName: 'BROWN',
    speechText: 'Brown',
    hueRanges: [hue(10, 45)],            // 赤みの茶色も通す
    saturationRange: range(0.38, 0.70),  // 0.38 未満は肌 / 0.70 より鮮やかなら ORANGE
    brightnessRange: range(0.18, 0.85),
    difficulty: 'advanced',
    profileVersion: 2,
    tint: '#825c36'
  },
  // ------------------------------------------------------------------
  //  BLACK / WHITE / GRAY は「むずかしい」だけで出す色。
  //  色み（色相）では決まらないので、色相は全部ゆるし、明るさと鮮やかさで分ける。
  //
  //  ※ カメラの自動露出は、画面いっぱいの黒も白も「中くらいの明るさ」に
  //    補正してしまう。近づきすぎず、まわりも一緒に写すと正しく判定できる。
  // ------------------------------------------------------------------
  {
    id: 'black',
    displayName: 'BLACK',
    speechText: 'Black',
    hueRanges: [hue(0, 360)],
    saturationRange: range(0.0, 0.50),
    brightnessRange: range(0.0, 0.30),   // 暗いこと が条件
    difficulty: 'advanced',
    profileVersion: 1,
    tint: '#2b2b30'
  },
  {
    id: 'white',
    displayName: 'WHITE',
    speechText: 'White',
    hueRanges: [hue(0, 360)],
    saturationRange: range(0.0, 0.16),   // 色みが無いこと
    brightnessRange: range(0.74, 1.0),   // 明るいこと
    difficulty: 'advanced',
    profileVersion: 1,
    tint: '#ffffff'
  },
  {
    id: 'gray',
    displayName: 'GRAY',
    speechText: 'Gray',
    hueRanges: [hue(0, 360)],
    saturationRange: range(0.0, 0.20),   // 色みが無いこと
    brightnessRange: range(0.26, 0.78),  // 黒と白の あいだ
    difficulty: 'advanced',
    profileVersion: 1,
    tint: '#8e8e93'
  }
];

/** ★ 難易度。変わるのは「出題する色の数」だけ。
 *    かんたん   … 7色（いちばん基本の色）
 *    ふつう     … 8色（+ BROWN）
 *    むずかしい … 11色（+ BLACK・WHITE・GRAY）
 *
 *  色を減らしたいときは colorIds を書きかえる（例: ['red', 'blue', 'yellow']）。
 *  TEAM HUNT の色は班ごとに固定なので、難易度の影響を受けない。
 */
const BASIC_7 = ['red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink'];
export const DIFFICULTIES = [
  { id: 'easy', label: 'かんたん', colorIds: BASIC_7 },
  { id: 'normal', label: 'ふつう', colorIds: BASIC_7.concat(['brown']) },
  { id: 'hard', label: 'むずかしい', colorIds: BASIC_7.concat(['brown', 'black', 'white', 'gray']) }
];
export const DEFAULT_DIFFICULTY = 'easy';

export function difficultyById(id) {
  return DIFFICULTIES.find((d) => d.id === id) || DIFFICULTIES[0];
}

/** ★ 時間制限（分）のボタン。0 は「なし」。並び順もこのとおり。 */
export const TIME_PRESETS_MIN = [0, 1, 2, 3, 5];
/** 「そのほか」で −／＋ で選べる範囲（分） */
export const CUSTOM_TIME_RANGE = { min: 1, max: 20 };
/** はじめて使うときの既定（分） */
export const DEFAULT_LIMIT_MIN = { solo: 3, team: 5 };

/** ★ TEAM HUNT: 班と担当色（固定・ランダムなし）。Swift 版 TeamHunt.swift と同じ。 */
export const TEAM_ASSIGNMENTS = [
  { teamNumber: 1, colorId: 'red' },
  { teamNumber: 2, colorId: 'blue' },
  { teamNumber: 3, colorId: 'green' },
  { teamNumber: 4, colorId: 'yellow' },
  { teamNumber: 5, colorId: 'orange' },
  { teamNumber: 6, colorId: 'purple' },
  { teamNumber: 7, colorId: 'pink' },
  { teamNumber: 8, colorId: 'brown' }
];

/** 残りがこの秒数以下で、時計の色を変えて知らせる（点滅はしない） */
export const TIME_WARNING = 30;

export function teamProfile(teamNumber) {
  const a = TEAM_ASSIGNMENTS.find((t) => t.teamNumber === teamNumber);
  return a ? COLOR_PROFILES.find((p) => p.id === a.colorId) || null : null;
}

/** 白い背景に文字として置いても読める色（YELLOW などを暗くする） */
export function readableColor(profile) {
  if (profile.id === 'yellow') return '#9a7a00';
  if (profile.id === 'pink') return '#c73f78';
  if (profile.id === 'white') return '#8a8a8f';   // 白い背景では見えないので灰色で出す
  return profile.tint;
}

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
  /** みつけた状態を解除するまでの時間。みつける時間より少し長くして、
   *  シャッターを押すときにカメラが動いても緑が消えにくくしてある。
   *  まだ早いときは 1.0、みつける時間とそろえたいときは 0.5。 */
  foundReleaseDuration: 0.8
};

// ---------------------------------------------------------------------------

function hueContains(r, h) {
  let x = h % 360;
  if (x < 0) x += 360;
  return r.from <= r.to
    ? x >= r.from && x <= r.to
    : x >= r.from || x <= r.to;
}

/** 色相・彩度・明度の範囲（プロファイル本体か、extraRegions の1つ）に入っているか */
function inRegion(region, hsv) {
  const { saturationRange: s, brightnessRange: v } = region;
  if (hsv.s < s.lower || hsv.s > s.upper) return false;
  if (hsv.v < v.lower || hsv.v > v.upper) return false;
  return region.hueRanges.some((r) => hueContains(r, hsv.h));
}

/** 中央の色がこのプロファイルの条件を満たすか（どれか1つの範囲に入っていればよい） */
export function matches(profile, hsv) {
  if (inRegion(profile, hsv)) return true;
  return (profile.extraRegions || []).some((region) => inRegion(region, hsv));
}

export function profileById(id) {
  return COLOR_PROFILES.find((p) => p.id === id) || null;
}

/** その難易度で出題する色 */
export function huntColors(difficultyId) {
  return difficultyById(difficultyId).colorIds.map((id) => profileById(id)).filter(Boolean);
}

/** 次に出す色をランダムに選ぶ。直前と同じ色は選ばない。 */
export function randomHuntColor(current, difficultyId) {
  const all = huntColors(difficultyId);
  const pool = all.filter((p) => !current || p.id !== current.id);
  const from = pool.length > 0 ? pool : all;
  return from[Math.floor(Math.random() * from.length)];
}
