# Color Hunt

小学3年生の外国語活動のための iPad アプリです。

画面に大きく出た英語の色を見て、児童が「これは青だと思う」と考え、
教室の中からその色のものを見つけ、カメラの中央に合わせます。
アプリは、中央のごく狭い範囲の色がその色の条件に入っているかを確かめるだけです。
**判断するのは児童で、アプリは物の名前や色を当てません。**

見つけたら写真を撮り、保存し、ロイロノートへ送って
"I found BLUE. This is a blue pencil case!" のように発表します。

## 出題される色

**RED / ORANGE / YELLOW / GREEN / BLUE / PURPLE / PINK** の7色から、
**毎回ランダム**に1色が出ます。

- START を押したとき … 新しい色
- 「つぎを さがす」を押したとき … **また別の色**（直前と同じ色は出ません）

色が変わるたびに「3・2・1」のカウントダウンが入り、新しい色の名前が大きく出ます。
**そのとき英語で1回読み上げます**（聞く → さがす）。もう一度聞きたいときは、
画面上の色の名前をタップすれば何度でも鳴ります。
色の名前は白い文字のままにしてあります（色そのものを見せてしまうと
「その色を知っているか」を試せなくなるためです）。

---

## 1. ファイル構成

```
ColorHunt.swiftpm/
├── Package.swift               App Playground の設定（カメラ権限もここ）
├── README.md                   このファイル
├── ColorHuntApp.swift          アプリの入口。activeProfile に RED を入れている
├── Models/
│   ├── ColorProfile.swift      ★ 色の定義と判定のチューニング（ここだけ直せばよい）
│   ├── ColorCapture.swift      library.json の中身
│   └── HSVColor.swift          H/S/V の入れもの
├── Services/
│   ├── CameraService.swift     カメラ起動・中央7x7の平均色・写真撮影
│   ├── ColorDetectionService.swift  0.5秒つづけて一致したら FOUND
│   ├── SpeechService.swift     英語の読み上げ（オフラインでも動く）
│   ├── StorageService.swift    フォルダ選択・JPG保存・library.json
│   └── ShareService.swift      共有シート（ロイロノート）と発表用画像
├── Views/
│   ├── RootView.swift          画面の行き来
│   ├── HomeView.swift          COLOR HUNT / START / MY COLORS
│   ├── HuntView.swift          カメラ・RED表示・ターゲット・シャッター
│   ├── CapturePreviewView.swift  とりなおす / この しゃしんに する
│   ├── GalleryView.swift       MY COLORS 一覧
│   ├── GalleryDetailView.swift 大きく見る・共有・削除
│   ├── FolderSetupView.swift   保存先フォルダの選択
│   ├── CameraPreview.swift     カメラ映像の表示
│   ├── ThumbnailImage.swift    一覧用のサムネイル読み込み
│   └── Theme.swift             色と文字サイズ
└── Utilities/
    ├── RGBHSVConversion.swift  RGB→HSV 変換
    ├── CaptureOrientation.swift 画面の向きあわせ
    ├── ImagePreparation.swift  保存用に写真をととのえる
    ├── ViewCompat.swift        iOS 16/17 両対応の onChange
    └── Feedback.swift          成功時の音と振動
```

---

## 2. Swift Playgrounds での開き方（iPad）

1. `ColorHunt.swiftpm` を iPad に渡す（次項）
2. 受け取ると Swift Playgrounds が開くか、「Swift Playgroundsで開く」を選ぶ
3. 「マイSwift Playgrounds」に **Color Hunt** が入る
4. 右上の ▶︎（実行）で起動

Mac の Xcode でも同じフォルダをそのまま開けます（`ColorHunt.swiftpm` をダブルクリック）。

### 動作条件
- iPadOS 16 以上（`Package.swift` の `platforms: [.iOS("16.0")]`）
- swift-tools-version は 5.6。古い Swift Playgrounds でも開けるように、
  Swift 5.7 以降の新しい書き方（`if let x` の省略形など）は使っていません。

---

## 3. iPad への渡し方

いずれか1つでよいです。

- **AirDrop**（いちばん確実）
  Finder で `ColorHunt.swiftpm` を右クリック →「共有」→「AirDrop」→ 対象の iPad
- **iCloud Drive / ファイル**
  `ColorHunt.swiftpm` を iCloud Drive に置き、iPad の「ファイル」からタップ
- **Apple Classroom / MDM で配布**
  フォルダのまま zip 化せずに配れない場合は zip 化して配布し、
  iPad 側で展開してから `.swiftpm` をタップします

> `.swiftpm` は「フォルダ」です。zip 化するときは中身だけでなくフォルダごと圧縮してください。

---

## 4. 初回のカメラ権限

- 初回に START を押すと「"Color Hunt"がカメラへのアクセスを求めています」と出ます → **OK**
- 権限の説明文は `Package.swift` の
  `capabilities: [.camera(purposeString: "いろをさがすために、カメラをつかいます。")]`
- 誤って「許可しない」を押した場合、アプリは落ちずに
  「カメラを つかうために きょかが ひつようです」という画面になります。
  そこから「せっていを ひらく」→ カメラをオン、で復帰できます。

**授業前に、教師が1台で一度 START まで進めて権限を通しておくと安全です。**
（児童機は各台で1回ずつ許可が必要です）

---

## 5. 保存フォルダの選択方法

初回起動時に「しゃしんを どこに ほぞんしますか？」が出ます。えらぶことは3つだけです。

| 選択肢 | 意味 |
|---|---|
| **フォルダを えらぶ**（おすすめ） | 「ファイル」アプリの好きな場所に `Color Hunt/` を作って保存する |
| **ほぞん せず はじめる** | 保存先を決めずに授業を始める。写真はアプリの中に残るが、アプリを作り直すと消える |
| まえの データを ひらく | 前に使っていた `Color Hunt` フォルダを開き直す（復元） |

「フォルダを えらぶ」を選んだ場合:

1. 「フォルダを えらぶ」
2. ファイルアプリで **このiPad内** を選ぶ
3. そこを選択すると、その中に `Color Hunt` フォルダが自動で作られます

できあがる構成:

```
Color Hunt/
├── library.json
└── photos/
    ├── 1B2C....jpg
    └── ...
```

- すでに `Color Hunt` フォルダがある場合は、それを直接選べば**そのまま復元**されます
  （`library.json` があるフォルダを選ぶと、その中身を読み込みます）
- 「まえの データを ひらく」も同じ選択画面です。過去の `Color Hunt` フォルダを選んでください
- 「ほぞん せず はじめる」を押した場合は、アプリ内部に保存します。
  写真は失われませんが、**アプリを作り直すと消えます**。
  一度これを選ぶと、次の起動からこの画面は自動で出ません（授業を止めないため）
- ホーム画面いちばん下の小さな「ほぞんさき: ...」をタップすると、いつでも選び直せます。
  フォルダ未設定のあいだは、この表示が赤くなります

---

## 6. ロイロノートへの共有方法

ロイロノート専用の連携はしていません。**iOS 標準の共有シート**を使います。

1. 写真を保存したあと、または MY COLORS → 写真をタップ
2. 「ロイロノートに おくる」
3. 共有シートから **ロイロノート** を選ぶ
4. ロイロノート側で提出箱へ提出

- ロイロノートが入っていない iPad でも、共有シートが開くだけでアプリは落ちません
- 共有をキャンセルしても、写真は Gallery に残ります（保存と共有は別の操作です）

### 送られる画像
既定では「発表用の1枚」を作って送ります。

```
        RED
   [ 撮影した写真 ]
   I found RED.
```

写真そのものを送りたい場合は `Services/ShareService.swift` の

```swift
static var style: Style = .presentationCard   // ← .photoOnly に変える
```

---

## 7. 色の判定値の調整場所 ★重要

**判定に関わる数値は `Models/ColorProfile.swift` に全部集めてあります。**
他のファイルを触る必要はありません。

7色の初期値は次のとおりです（Hue は色相・S は鮮やかさ・V は明るさ）。

| 色 | Hue | S | V | ねらい |
|---|---|---|---|---|
| RED | 345–360, 0–14 | 0.45+ | 0.20+ | S を高めにして肌とピンクを除く |
| ORANGE | 16–44 | **0.65+** | 0.50+ | S を高めにして木の机・肌を除く |
| YELLOW | 45–70 | 0.40+ | 0.55+ | V を高めにしてオリーブ色を除く |
| GREEN | 75–165 | 0.25+ | 0.15+ | 濃い緑の黒板も通す |
| BLUE | 195–250 | 0.35+ | 0.18+ | 水色から紺色まで |
| PURPLE | 255–305 | 0.25+ | 0.18+ | うすい紫も通す |
| PINK | 310–360, 0–8 | 0.18–**0.70** | 0.60+ | 赤と同じ色相を「うすさ」で分ける |

**ORANGE と PINK が「色相だけに頼らない設計」の実例です。**
ORANGE は木の机（Hue 27付近）と色相が重なるので S で分け、
PINK は赤と色相が重なるので S の上限で分けています。

### 症状別の直し方

| こまりごと | 直すところ |
|---|---|
| その色なのに反応しない | その色の `saturationRange` の下限を 0.10 下げる |
| 暗いもの（ランドセルなど）が通らない | その色の `brightnessRange` の下限を下げる |
| 木の机が ORANGE になる | ORANGE の `saturationRange` を `ValueRange(0.70, 1.0)` に上げる |
| 手や顔（肌）が RED になる | RED の `saturationRange` を `ValueRange(0.55, 1.0)` に上げる |
| 赤いものが PINK になる | PINK の `saturationRange` の上限を 0.60 に下げる |
| 出題する色を減らしたい | `ColorProfile.huntColors` を書き換える（8章） |
| 一瞬で成功しすぎる／しにくい | 同ファイル下部 `HuntTuning.stableDuration`（既定 0.5秒） |
| 手ぶれで判定が切れる | `HuntTuning.releaseGrace`（既定 0.2秒）を大きく |
| シャッターを押す前に緑が消える | `HuntTuning.foundReleaseDuration` を 1.0 くらいに伸ばす |
| 判定点が狭すぎる／広すぎる | `HuntTuning.sampleSize`（既定 7 → 5〜9で調整） |

値を変えたら `profileVersion` を +1 しておくと、
あとから `library.json` を見て「どの条件で撮った写真か」が分かります。

### 検証済みの誤判定チェック

教室にありそうな26色で、7色すべてに対して判定を確認済みです。
**木の机・明るい木の床・肌（2種）・白い紙・灰色のロッカー・黒い服・こげ茶の椅子は、
どの色にも当たりません。** 複数の色にまたがるものもありませんでした。

### 実機でしか確認できないこと
Mac 上ではカメラ映像が得られないため、**実際の閾値の当たり外れは iPad 実機でしか確認できません。**
教室の照明・iPad の機種（カメラの色味）で変わります。

### 教師用のかくれた数値表示
探索画面の **左下すみを 1.5 秒 長押し** すると、いま測っている値が出ます。

```
H: 3.8  S: 0.82  V: 0.71
matched: true
```

もう一度長押しで消えます。児童の通常操作では絶対に出ません。
授業前に赤鉛筆・掲示物・ランドセルを写して、H と S の値を見ておくと調整が早いです。

---

## 8. 新しい ColorProfile を追加する方法

### 出題する色を減らす（授業でよく使う）

`ColorProfile.huntColors` が出題される色の一覧です。最初の授業で3色にしぼるなら:

```swift
static let huntColors: [ColorProfile] = [.red, .blue, .yellow]
```

`catalog`（アプリが知っている色すべて）とは別なので、
出題から外した色の写真も Gallery にはそのまま並びます。

### 新しい色そのものを足す

`Models/ColorProfile.swift` に定義を足し、`catalog` と `huntColors` に入れるだけです。

```swift
static let blue = ColorProfile(
    id: "blue", displayName: "BLUE", speechText: "Blue",
    hueRanges: [HueRange(200, 250)],
    saturationRange: ValueRange(0.40, 1.0),
    brightnessRange: ValueRange(0.20, 1.0),
    difficulty: .basic, profileVersion: 1,
    tint: RGBTriple(r: 0.16, g: 0.40, b: 0.90))

```

Gallery は `catalog` の順に色ごとの節を作るので、追加すれば自動で分類されます。
出題は `ColorProfile.randomHuntColor(excluding:)` が `huntColors` から選びます。

---

## 9. library.json 仕様

保存先フォルダ直下の `library.json` が唯一の正本（Source of Truth）です。

```json
{
  "schemaVersion" : 1,
  "captures" : [
    {
      "id" : "9C1F5F2E-....",
      "targetColor" : "red",
      "displayName" : "RED",
      "imageFile" : "photos/9C1F5F2E-....jpg",
      "capturedAt" : "2026-08-31T01:24:33Z",
      "difficulty" : "basic",
      "colorProfileVersion" : 1,
      "sampledHSV" : { "h" : 4.8, "s" : 0.81, "v" : 0.73 }
    }
  ]
}
```

- `imageFile` は `library.json` から見た相対パスです
- 日付は ISO8601
- `sampledHSV` は「FOUND になった瞬間に測れていた色」です
- 読み込みに失敗した `library.json` は消さずに `library.broken-<数字>.json` に退避します
  （写真は残るので、手で直すことができます）

---

## 10. 保存のタイミング

| 操作 | 起きること |
|---|---|
| シャッター | 撮るだけ。まだ保存しない |
| とりなおす | 破棄してカメラへ戻る |
| **この しゃしんに する** | JPG保存 → library.json更新 → Galleryへ反映（ここではじめて正式保存） |
| ロイロノートに おくる | 共有シートを開くだけ。失敗・キャンセルしても写真は残る |

写真の保存に成功して `library.json` の更新に失敗した場合は、
食い違いを残さないように写真ファイルも消してエラーを出します。

---

## 11. 将来拡張の考え方

- **色を増やす**: `ColorProfile` を足して `catalog` / `huntColors` に入れるだけ。判定コードは触らない
- **難易度別の出題**: `huntColors` を `catalog.filter { $0.difficulty == .basic }` のようにすれば、
  Advanced（BROWN / NAVY など）や Expert（CRIMSON / MAROON など）へ段階的に広げられる
- **Hue だけに依存しない設計**: `saturationRange` / `brightnessRange` を必ず持つので、
  たとえば ORANGE と BROWN のように「色相が重なり明るさで分かれる色」も表現できます
  （`ColorProfile.swift` にコメントで見本を入れてあります）
- **難易度**: `difficulty` を basic / advanced / expert で持てます
- **再解析**: `sampledHSV` と `colorProfileVersion` を残しているので、
  あとから閾値を変えて過去写真を評価し直すこともできます
- **CIELAB / ΔE**: 必要になったら `ColorProfile.matches(_:)` の中だけを差し替えれば移行できます
  （今回は HSV のみ。過剰実装はしていません）

---

## 12. 既知の制約

- **色判定は厳密な色彩測定ではありません。** 照明・カメラの自動露出・ホワイトバランスで値は動きます
- 中央7x7ピクセルの平均だけを見ます。円の中全体の平均は使いません
- **一度フォルダを選べば、次の起動から最初の画面は出ません。** 起動時にブックマークを解決して
  そのフォルダを開き直すためです。例外は下の4つで、このときだけ最初の画面がまた出ます。
  1. Swift Playgrounds でアプリを作り直した（＝別アプリ扱いになりブックマークが消える）
  2. 選んだフォルダを親ごと削除・移動した
  3. iCloud など保存先が一時的に見えない
  4. まだ一度もフォルダを選んでいない
  いずれも「まえの データを ひらく」で同じフォルダを選び直せば、写真ごと復元できます
- security-scoped bookmark は「同じアプリのインスタンス」でのみ有効です。
  Files 内の実データが正本なので、ブックマークが消えても作品は失われません
- 保存先に iCloud Drive を選ぶこともできますが、同期待ちで写真が見えないことがあります。
  授業では **「このiPad内」** を推奨します
- 縦向き（Portrait）前提の設計です。横向きでも崩れませんが、縦のほうが操作しやすいです
- FOUND（緑）になったあと、対象の色から `HuntTuning.foundReleaseDuration` 秒（既定 0.5秒、
  みつけるのと同じ時間）つづけて外れると、白にもどってまた探し始められます。
  カメラを別のものに向けかえるだけで、何度でも探し直せます
- そのため「シャッターを押す直前にカメラが動いて緑が消える」ことが起こり得ます。
  児童が押しにくそうなら `foundReleaseDuration` を 1.0 くらいに伸ばしてください
- 「とりなおす」でカメラに戻ったときも同じ規則です。赤いものに向いていれば緑のまま、
  外れていれば白にもどります

---

## 13. Mac 上でのビルド確認

```bash
xcodebuild -scheme ColorHunt -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

型チェックだけなら、リポジトリ直下の `typecheck.sh` が使えます。

```bash
./typecheck.sh
```

### カメラ無しで画面を確認する（harness.sh）

シミュレータにはカメラが無いため、本体をそのまま動かしても探索画面は黒いままです。
`harness.sh` は **いまのソースをそのままコピーして** 検証用アプリを組み立て、
1画面ずつシミュレータに出します（本体には手を加えません）。

```bash
./harness.sh found
```

| 画面名 | 内容 |
|---|---|
| `home` | ホーム |
| `setup` | 保存先をえらぶ画面 |
| `hunt` | さがす画面（3・2・1 → カメラ無しの状態） |
| `found` | RED をみつけた状態（合成した赤い色を流し込む） |
| `preview` | 撮影後の確認画面（合成写真。保存とロイロ共有まで試せる） |
| `gallery` | MY COLORS |

**色判定そのものは実機でしか確認できません。** harness.sh で見られるのは
レイアウト・遷移・保存・共有シートまでです。

---

## 14. 授業前の最短チェック（教師用・約3分）

1. iPad で Color Hunt を開いて ▶︎ 実行
2. 保存先を「このiPad内」→ フォルダ選択（`Color Hunt` が作られる）
   ※ 急ぐときは「ほぞん せず はじめる」でも授業は成立します
3. START → 色の名前と「3・2・1」→ カメラが出る
4. 上の **色の名前** をタップ → 英語で聞こえる（音量を確認）
5. その色のものを中央に合わせる → 円が緑・✓・You found ○○!
6. シャッター →「この しゃしんに する」
7. 「ロイロノートに おくる」→ 共有シートにロイロノートが出る
8. 「つぎを さがす」→ **別の色に変わる**ことを確認
9. 「ファイル」アプリで `Color Hunt/photos/` に JPG があることを確認

ここまで通れば授業で使えます。
