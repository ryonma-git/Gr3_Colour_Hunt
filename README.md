# Color Hunt

小学3年生の外国語活動のための「いろさがし」アプリです。

画面に大きく出た英語の色（RED / ORANGE / YELLOW / GREEN / BLUE / PURPLE / PINK）を見て、
児童が「これは青だと思う」と考え、教室の中からその色のものを見つけ、カメラの中央に合わせます。
アプリは、中央のごく狭い範囲（7×7ピクセル）の色がその色の範囲に入っているかを確かめるだけです。

**判断するのは児童です。アプリは物の名前も色も当てません。**
これは「カメラが物の色を教えるアプリ」ではなく、児童の探索と確認を支えるだけの道具です。

見つけたら写真を撮り、保存し、ロイロノートへ送って
"I found BLUE. This is a blue pencil case!" のように発表します。

---

## 児童に配る URL

**https://ryonma-git.github.io/Gr3_Colour_Hunt/**

Safari でひらくだけで使えます。ロイロノートや Apple Classroom でこのリンクを配ってください。
共有ボタン →「ホーム画面に追加」でアイコンになり、全画面で動きます。

> 初回だけ「カメラへのアクセスを許可しますか」と出ます。「許可」を押してください。
> 一度ひらけば、次からはオフラインでも起動します。

---

## 2つの版

同じ活動を2つの形で用意しています。**判定に使う数値は完全に同じ**です。

| | 児童の操作 | 準備 | 向いている場面 |
|---|---|---|---|
| **[ColorHunt.swiftpm](ColorHunt.swiftpm/)** | Playgrounds を開いて ▶︎ | 1台ずつ手作業 | 教師が作って直す・少数台 |
| **[web/](web/)** | **URL をひらくだけ** | GitHub Pages で公開ずみ | **授業で全員に配る** |

- Swift 版は、閾値をその場で書き換えて ▶︎ で試せるのが強みです（教室での調整用）
- Web 版は、ロイロノートや Apple Classroom でリンクを配れるのが強みです（配布用）

それぞれの詳しい説明は各フォルダの README にあります。

- [ColorHunt.swiftpm/README.md](ColorHunt.swiftpm/README.md) — Swift Playgrounds 版
- [web/README.md](web/README.md) — Web 版

---

## 判定のしくみ

1. カメラ映像の**中央 7×7 ピクセル**の平均 RGB を、1秒に12回とる
2. RGB → HSV（色相 0–360 / 彩度 0–1 / 明度 0–1）に変換する
3. いま出題されている色の範囲に入っているかを見る
4. **0.5秒つづけて**入っていたら「みつけた」（緑・✓）
5. **0.5秒つづけて**外れたら「さがし中」に戻る（別のものを探し直せる）

円の中の平均ではなく、**中央のごく狭い一点だけ**を見ます。背景の影響を避けるためです。

### 色相だけに頼らない設計

`ColorProfile` は色相・彩度・明度の3つを必ず持ちます。これにより、
**色相が重なる色を明るさや鮮やかさで分ける**ことができます。

- **ORANGE** は木の机（色相27付近）と重なるので、彩度 0.65 以上で分けている
- **PINK** は赤と重なるので、彩度 0.70 以下（＝うすい）で分けている

教室にありそうな26色で検証済みです。**木の机・明るい木の床・肌・白い紙・
灰色のロッカー・黒い服・こげ茶の椅子は、どの色にも当たりません。**
複数の色にまたがるものもありません。Swift 版と Web 版で結果が一致することも確認しています。

---

## 判定値を直す場所

| 版 | ファイル |
|---|---|
| Swift | `ColorHunt.swiftpm/Models/ColorProfile.swift` |
| Web | `web/js/colors.js` |

**片方だけ直すと両者がずれます。** 直したらもう片方も合わせてください。

どちらも、探索画面の**左下すみを1.5秒長おし**すると、
いま測っている H / S / V が出ます（先生用。児童の通常操作では出ません）。

---

## ディレクトリ

```
.
├── ColorHunt.swiftpm/          iPad / Swift Playgrounds 版
├── web/                        Web 版（静的サイト。ビルド不要）
├── typecheck.sh                Swift 版の型チェック（Mac）
├── harness.sh                  Swift 版をカメラ無しで画面確認する（シミュレータ）
└── .claude/launch.json         Web 版のローカルサーバー設定
```

`ColorHunt _defound.swiftpm` / `ColorHunt_7colours.swiftpm` は作業中のスナップショットです。
本番は `ColorHunt.swiftpm` です。

---

## 開発メモ（Mac）

```bash
# Swift 版の型チェック
./typecheck.sh

# Swift 版のフルビルド（iOS 向け）
cd ColorHunt.swiftpm && xcodebuild -scheme ColorHunt \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# Swift 版をシミュレータで画面確認（カメラ無しでも見られる）
./harness.sh found

# Web 版をローカルで開く
python3 -m http.server 8765 --directory web
```

- `.swiftpm` は `swift build` では扱えません（`AppleProductTypes` が
  toolchain に無いため）。`xcodebuild` を使ってください
- `.iOSApplication` は swift-tools-version 5.6 以上が必要です

---

## やらないと決めていること

ユーザーアカウント / サーバー / Firebase / CloudKit / 生成AI / Core ML /
Vision による物体認識 / ランキング / ポイント / 広告 / 課金 /
ロイロノートへの独自API連携 / Apple Classroom 独自API連携。

色の判定は HSV だけで行い、過剰な実装はしていません。
