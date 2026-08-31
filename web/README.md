# Color Hunt Web

Swift Playgrounds 版と同じ活動を、**URL をひらくだけ**でできるようにした Web 版です。
判定に使う数値は Swift 版とまったく同じで、同じ26色のテストで結果が一致することを確認しています。

## なぜ Web 版か

Swift Playgrounds 版は「教師が作って直す」には最高ですが、
`.swiftpm` を1台ずつ手作業で入れる必要があり、**30人に配る手段としては弱い**です。
Web 版なら、ロイロノートや Apple Classroom で **リンクを配るだけ**で全員が使えます。

| | 児童の操作 | 準備 |
|---|---|---|
| Swift Playgrounds 版 | ファイルを Playgrounds に入れて ▶︎ | 1台ずつ手作業 |
| **Web 版** | **URL をひらく** | サーバーに置くだけ |

---

## 公開ずみの URL

**https://ryonma-git.github.io/Gr3_Colour_Hunt/**

このリポジトリの `main` ブランチに push すると、1〜2分で自動的に更新されます。
（リポジトリ直下の `index.html` が `web/` へ転送しているので、短い URL で開けます）

---

## 1. 置き方（別の場所に置きたいとき）

`web/` の中身をそのまま静的サイトとして置くだけです。ビルドは不要です。

### Netlify（ドラッグ&ドロップ）
1. https://app.netlify.com/drop を開く
2. `web` フォルダをドラッグ&ドロップ
3. 出てきた URL を児童に配る

### GitHub Pages（このリポジトリで採用）
1. リポジトリの Settings → Pages
2. Source を `main` ブランチ / `/`（ルート）
3. リポジトリ直下に `.nojekyll` と、`web/` へ転送する `index.html` を置く
4. `https://<ユーザー名>.github.io/<リポジトリ名>/` が URL になる

> **HTTPS が必須です。** カメラ（getUserMedia）は HTTPS か localhost でしか動きません。
> Netlify も GitHub Pages も自動で HTTPS になるので、そのまま使えます。

### 手元で試す
```bash
python3 -m http.server 8765 --directory web
# → http://localhost:8765
```

---

## 2. iPad で使うときの注意

- **Safari で開いてください。** 初回に「カメラへのアクセスを許可しますか」と出るので「許可」
- 誤って「許可しない」を押したら、アドレスバー左の「ぁA」→「Webサイトの設定」→ カメラを「許可」
- **ホーム画面に追加**すると、Safari のバーが消えて全画面になります
  （共有ボタン →「ホーム画面に追加」）。アイコンから開けるので児童にも分かりやすいです
- 音（"Red." の読み上げ）は、**児童が色の名前をタップしたとき**に鳴ります。
  iOS は最初の1回にタップが必要なので、この作りにしてあります
- 一度ひらけば、次からは**オフラインでも起動**します（Service Worker）

---

## 3. 保存とロイロノートへの提出

写真は **その iPad のブラウザの中（IndexedDB）** に保存されます。

1. 「この しゃしんに する」で保存
2. 「ロイロノートに おくる」→ iOS の共有シートが開く → ロイロノートを選ぶ

共有には Web Share API（`navigator.share`）を使っています。iOS 15 以降の Safari なら、
ネイティブアプリと同じ共有シートが開き、ロイロノートが候補に出ます。

共有シートが使えない環境では、画像を別タブで開くので、
**長押し →「写真に追加」**してからロイロノートで選んでください。

### 保存についての制約（重要）

- Safari の「履歴とWebサイトデータを消去」をすると **写真も消えます**
- プライベートブラウズでは保存されません
- iPad を替えるとデータは移りません
- 大事な作品は、その時間のうちにロイロノートへ提出してください

MY COLORS の下にある「データを かきだす（先生用）」で、
Swift 版と同じ `library.json` 形式のメタデータを書き出せます（画像本体は含みません）。

---

## 4. 判定値の調整

**`js/colors.js` だけ**を直します。保存してページを再読み込みすれば反映されます
（Service Worker は「ネットがあるときは必ず最新を取りに行く」設定にしてあるので、
 直したのに反映されない、ということは起きません）。

```js
{
  id: 'red',
  hueRanges: [hue(345, 360), hue(0, 14)],
  saturationRange: range(0.45, 1.0),   // ← 反応しないときは下げる
  brightnessRange: range(0.20, 1.0),
  ...
}
```

出題する色を減らすときは同じファイルの:

```js
export const HUNT_COLOR_IDS = ['red', 'blue', 'yellow'];
```

`TUNING` に、判定の秒数やサンプルサイズがまとまっています。

### 先生用のかくれた数値表示
探索画面の**左下すみを1.5秒長おし**すると、いま測っている H / S / V が出ます。
もう一度長おしで消えます。児童の通常操作では出ません。

### 開発用フック
URL の末尾に `?debug=1` を付けると `window.__colorHunt` が使えます。
Safari のコンソールで `__colorHunt.demoFound()` と打つと、
カメラが無くても「みつけた」状態の見た目を確認できます。

---

## 5. Swift 版との対応

| Web | Swift Playgrounds |
|---|---|
| `js/colors.js` | `Models/ColorProfile.swift` |
| `js/hsv.js` | `Utilities/RGBHSVConversion.swift` |
| `js/detector.js` | `Services/ColorDetectionService.swift` |
| `js/camera.js` | `Services/CameraService.swift` |
| `js/speech.js` | `Services/SpeechService.swift` |
| `js/storage.js` | `Services/StorageService.swift` |
| `js/share.js` | `Services/ShareService.swift` |
| `js/app.js` | `Views/RootView.swift` ほか |

**判定値を片方だけ直すと両者がずれます。** 直したらもう片方も合わせてください。

---

## 6. 既知の制約

- 「ファイル」アプリの `Color Hunt/` フォルダには保存できません（Web の制約）。
  構造化された保存が必要なら Swift 版を使ってください
- カメラは背面カメラを要求しますが、機種によっては前面になることがあります
- 色判定は厳密な色彩測定ではありません。照明で値は動きます
- 縦向き前提です。横向きでも壊れませんが縦のほうが操作しやすいです
