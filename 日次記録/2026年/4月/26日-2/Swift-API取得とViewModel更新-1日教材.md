# Swift: API取得と ViewModel更新（1日分学習教材）

## 1. 今日のゴール（1〜2行）

**目安時間（分）:** 0（読了のみ）

`async/await` で JSON を取得し、`ViewModel` の状態を更新して SwiftUI の画面に反映する最小のミニアプリを一連で作れること。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間（分）:** 5

**Q1. `async` 関数内で `await` すると何が起きる？**  
**A.** 非同期処理が完了するまで、そのタスク上では実行が一時停止し、完了後に同じ文から再開する。呼び出し元のスレッドを固くブロックし続けない点が、従来の `DispatchQueue` 同期ブロックと異なる（UI 応答性に効く）。

**Q2. SwiftUI で View が「ViewModel の変化」に反応する典型的な方法は？**  
**A.** 観測可能な state（例: iOS 17+ の [`@Observable`](https://developer.apple.com/documentation/observation/observable) クラス + View で `ViewModel` を `@State` として保持。または従来の `ObservableObject` + `@Published` + `@StateObject` / `@ObservedObject`）を使い、View の `body` がそのプロパティを読む。

**Q3. MVVM の「M」「V」「VM」に相当する部分は、今日の例だと何に相当する？**  
**A.** M: API から返る `Decodable` モデル。V: SwiftUI の `View`。VM: 取得の実行・`phase`（読み込み中/成功/失敗）の保持。今日の規模では「専用リポジトリ」は作らず、取得ロジックは ViewModel のメソッド内に置く（分割は明日以降の布石）。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間（分）:** 9

> **比較観点（今日は1つ）:** データフロー — 「誰が API を呼び、誰が state を更新し、誰が画面を描画するか」を一直線に固定する（View → ViewModel（アクション）→ 非同期取得 → state 更新 → View が再描画）。

### 重要ポイント1: `URLSession` の `data(from:)` は Swift Concurrency と相性が良い

公式: [`data(from:delegate:)`](https://developer.apple.com/documentation/foundation/urlsession/3767353-data)  
`try await URLSession.shared.data(from: url)` は転送完了まで `await` で待てる。戻り値は `(Data, URLResponse)`。

- **よくある誤解/落とし穴:** `response` を見ずに `JSONDecoder` だけ通す。4xx/5xx でも **本文に JSON（エラーメッセージ）** が乗ることがあるため、**`HTTPURLResponse` の `statusCode` を 2xx か確認**してから解釈する（WWDC のサンプルと同様）。

### 重要ポイント2: View に `URLSession` を直置きしない

View は表現に専念し、**取得と状態遷移は ViewModel 側**に置く。`.task` や `Button` は **「いつ load を起動するか」** だけ担う。  
- **よくある誤解/落とし穴:** `body` の再評価のたびに手当たり次第 `Task` を作る → **同じ取得が多発**しやすい。`.task(id:)`、ユーザ操作1回1 `Task`、重複を避ける、のどれかを意識する（今日のサンプルは初回＝`.task`、手動＝ボタン、の二箇所に限定）。

### 重要ポイント3: UI に効く state は `MainActor` 側で揃える

`@Observable` の ViewModel に [`@MainActor`](https://developer.apple.com/documentation/swift/mainactor) を付け、**`phase` など表示用の更新は同じ型のメソッド内**で行う。  
- **よくある誤解/落とし穴:** バックグラウンドから直接 `@Published` / `@Observable` のプロパティを書き、Main Thread Checker や不整合で気づく。`@MainActor` 付き ViewModel なら、通常は `load()` 全体でアクター隔離が一貫する（実務では境界で `Task { @MainActor in ... }` も併用）。

### 重要ポイント4: エラーをユーザー向け文面に直す（実務の入口）

`error.localizedDescription` は**開発時の仮**には便利だが、**機種言語任せ**で文言が揺れ、API の意図とズレることがある。  
- **よくある誤解/落とし穴:** ネット断と JSON 不整合を同じ「失敗: …」1パターンで出す。最低限、**`DecodingError` と `URLError` を分けてメッセージ**するか、**ログに型を出して**次の作業（契約不整合 or 回線）を切り分ける（今日のコードは学習用に簡略化しつつ、落とし穴として把握しておく）。

### 重要ポイント5: 型（`Decodable`）と JSON 契約のズレ

キー名・型（数値/文字列）の不一致、必須フィールド欠落、**200 なのに空 `Data`** 等で `JSONDecoder` は `throws` する。  

- **よくある誤解/落とし穴:** 追加フィールドは **JSON に余分なキーがあっても通常は無視**される（デフォルト）。逆に、**足りない必須プロパティ**はすぐ壊れる。  

**「契約固め」とは何か:** クライアントの `struct` と、サーバーが返す JSON（**キー名・型・必須/任意**）の対応関係を、仕様書・OpenAPI・チーム合意などで**確定させた段階**のこと。今日の教材のように**まず動かす**ときは、仕様に合わせた**最小限の `Decodable`** でよい。  

**`CodingKeys` を検討するタイミング:** JSON のキー名が Swift のプロパティ名と違うとき（例: サーバーが `user_id`、Swift は `userId`）。`enum CodingKeys: String, CodingKey` で**名前の対応**を書き、**デコード可能にする**（仕様が確かなうちに導入する。推測で型を合わせない）。  

**オプショナル化（`String?` 等）を検討するタイミング:** 同じエンドポイントでも、**状況によってフィールドが欠ける**、**A/B や段階リリースで一部のキーだけ後から出る**、といった**揺れ**がありうると分かったとき。プロパティを**必須（非オプショナル）**のままにすると、**キーが1回でも足りない**と全体が `DecodingError` になる。揺れを**許容する**なら、該当フィールドだけ**オプショナル**にし、UI 側で `nil` のときの表示を決める。逆に、**揺れはバグ**として扱い**早期に壊して気づきたい**なら、あえて必須のままにし、**テストやステージングで不整合を検出する**、という**運用**も選べる。  

まとめると、**`CodingKeys` もオプショナル化も「本番用に JSON と Swift 型の対応を固めてから」迷いなく直す**ための手当であり、**初日の学習用サンプルで全部やる必須手順ではない**、という区別の話である。

### 重要ポイント6: キャンセルと「遅いレスポンス」（入口）

`Task` は `cancel()` 可能。画面を抜けたあと、**古いレスポンスが遅延到着して state を上書き**しうる。  
- **よくある誤解/落とし穴:** キャンセルしても一瞬遅延表示が戻る。本番は世代 ID、`Task` 保持、`onDisappear` 連動など。詳細は **追加課題 Hard** へ。

### 設計の選択肢（1つ）

- **小規模の画面では、ViewModel のメソッド内に `URLSession` + バリデーション + `JSONDecoder` を置く** — ファイル数を増やさず、今日の**データフロー**（誰が何を触るか）の教材に向く。  
- **実務でコードベースが大きい場合は、** 取得だけを `struct` / `actor` / `class`（いわゆる DataSource/Repository）に抜かし、ViewModel は **UI 用 state と意図（refresh 等）** だけ持つ。  
- **今回のサンプルは「前者」**（最小構成）を選び、**境界は `async` メソッド＋`Decodable` 型**に揃えて、後でメソッドごと抜き出しやすくしてある。

### 補足（参考リンク）

- [Use async/await with URLSession（WWDC21 動画）](https://developer.apple.com/videos/play/wwdc2021/10095)  
- [Observation フレームワーク（@Observable）](https://developer.apple.com/documentation/observation)

---

## 4. ハンズオン（手順）

**目安時間（分）:** 36

作業は **`tutorial` 配下**に Xcode プロジェクトを作る想定。手順は「動く」までの**最短経路**に絞る（**教材用にファイル群は倉庫にコミットしない**方針なら、同ディレクトリの `.gitignore` の `tutorial/` も利用可）。

**最小成果物の表示内容:** [JSONPlaceholder](https://jsonplaceholder.typicode.com/) の `/posts/1` から、**投稿タイトル**と **`userId`**（ユーザー識別子）を表示。著者名はこのエンドポイントには含まれない。失敗時はメッセージ表示。

- **想定URL:** `https://jsonplaceholder.typicode.com/posts/1`（HTTPS・学習用。オフライン用の挙動確認はシミュレータの機内モード等）

**トラブルが出たら先に確認（実務で詰まりやすい所）:**  
- **Test の `@testable import` が失敗** → テスト Target の **General → Host Application** をメイン App に。`Product Name` と異なる **Product Module Name**（Build Settings）を `import` に合わせる。  
- **Cannot find 'QuotePost' in scope（テスト）** → テストファイル右パネル **Target Membership** に **APIQuoteMiniTests だけ**でなく、型が定義された **App ターゲット**はビルドに含まれる。テストは `@testable import` で本番モジュールを参照。  
- **`import Testing` が使えない** → **Xcode 16 以降**、テストターゲットを **Swift 6** のツールチェーンでビルド。古いテンプレのまま `XCTest` だけ入っているなら、ファイル内容を**ステップ5の Swift Testing 例**に差し替える。  
- **ATS / HTTP 不可** — 学習用に **HTTP のローカル**を叩くなら、Info.plist の App Transport Security 例外が必要。本手順は **HTTPS 前提**のため未設定。  

---

### ステップ0: `tutorial` 用 .gitignore（任意）

リポジトリのルートに、次の1行（手元の日次記録フォルダでは同梱例あり）:

```gitignore
tutorial/
```

**確認方法:** `git check-ignore -v tutorial` で `tutorial/` が除外される（Git 管理時）。

---

### ステップ1: プロジェクト作成（5分）

1. `tutorial` フォルダを作成。  
2. **Xcode → File → New → Project → iOS → App**  
3. **Product Name:** `APIQuoteMini`、**Interface:** SwiftUI、**Language:** Swift、**Storage:** None で可。  
4. **Minimum Deployments: iOS 17.0** 以上（`@Observable` 採用のため。iOS 16 以前は `ObservableObject` + `@Published` へ切り替えが必要）。  
5. 保存先: `.../tutorial/APIQuoteMini/`

**確認方法:** ターゲット `APIQuoteMini` を選び **ビルド（⌘B）** が成功し、白画面がシミュレータで起動する。

---

### ステップ2: モデル `QuotePost.swift`（4分）

1. **File → New → File → Swift File**、名前 `QuotePost`。  
2. **Target Membership** に **APIQuoteMini** にチェック。  
3. 次を貼る（API の `posts` 応答の**必要フィールド**を `Decodable` で受ける）。`body` は今回未表示だが、解の安定のため**含めて**おく（将来の拡張やテスト用）。

```swift
// ファイル: QuotePost.swift
import Foundation

struct QuotePost: Decodable, Equatable, Sendable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
}
```

**確認方法:** 保存後 **⌘B** が通る。Xcode 左のファイルが **青アイコン**（ターゲットに入っている）である。

---

### ステップ3: ViewModel `QuoteViewModel.swift`（9分）

1. 新規 Swift ファイル、**Target: APIQuoteMini**。  
2. 以下を貼る。`load()` は**ネットとデコード**の失敗を吸収し、**表示用**は `failed(String)` へ落とす（`localizedDescription` は学習用。実務では下記コメント通り拡張）。

```swift
// ファイル: QuoteViewModel.swift
import Foundation
import Observation

@MainActor
@Observable
final class QuoteViewModel {
    enum Phase: Equatable {
        case idle, loading, loaded(QuotePost), failed(String)
    }

    private(set) var phase: Phase = .idle
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() async {
        phase = .loading
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard !data.isEmpty else {
                // 学習用: 2xx でも空ボディのケースを分ける
                throw URLError(.badServerResponse)
            }
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                // 実務: statusCode / 応答骨子を外部ログ（Sentry 等）へ
                throw URLError(.badServerResponse)
            }
            let post = try JSONDecoder().decode(QuotePost.self, from: data)
            phase = .loaded(post)
        } catch is DecodingError {
            phase = .failed("データの解釈に失敗（サーバー応答の形が想定外の可能性）")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
```

**確認方法:** **⌘B** が通る。`URLSession` は `async` 版（[公式 `data(from:)`](https://developer.apple.com/documentation/foundation/urlsession/3767353-data)）。

---

### ステップ4: `ContentView.swift` で UI と接続（7分）

1. プロジェクト付属の `ContentView.swift` を置き換え。  
2. 初回取得は **`.task`**（表示ライフサイクルに合わせる）。`ステップ3` 説明にあった **`.onAppear` + `Task`** との違い: `.task` は**ビューが無効化されると取り消し**に寄与しやすい（[SwiftUI の .task](https://developer.apple.com/documentation/swiftui/view/task(priority:_:))。今日は**二重起動を避ける**意味でも `.task` 一択推奨）。**再取得**だけボタンで `Task { await viewModel.load() }`。

```swift
// ファイル: ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel: QuoteViewModel

    init() {
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
        _viewModel = State(initialValue: QuoteViewModel(url: url))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.phase {
            case .idle, .loading:
                ProgressView("読み込み中…")
            case .loaded(let post):
                Text(post.title)
                    .font(.headline)
                Text("userId: \(post.userId)（著者名ではない）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Text("失敗: \(message)")
                    .foregroundStyle(.red)
            }
            Button("再取得") {
                Task { await viewModel.load() }
            }
        }
        .padding()
        .task { await viewModel.load() } // 初回のみここ。ボタンと役割を分ける
    }
}
```

**確認方法:** 実行（⌘R）で**タイトル**と `userId` が出る。機内モード等で**赤い失敗行**に切り替わる。著者名は出ない想定（別 API が必要）と理解する。

---

### ステップ5: テスト目標の追加（8分）※必ず1本以上 — **Swift Testing**

1. **File → New → Target → Unit Testing Bundle**、名前 `APIQuoteMiniTests`。**Host Application** を **APIQuoteMini** に。  
2. 新規ファイル `QuotePostDecodingTests.swift`（名前は任意）、**Target Membership: APIQuoteMiniTests のみ**。  
3. **Build Settings**（テストターゲット）で **Swift Language Version** が **Swift 6**（またはプロジェクト既定の Swift 6）になっていることを確認。  
4. **Build Settings** の **Product Module Name**（App 側）を確認。`@testable import` の名前はここに合わせる（既定なら `APIQuoteMini`）。  
5. 次を貼る（**ネット不要**・モデルの契約テスト。実務では `Decodable` の形が崩れたらここで早期検知）。**[Swift Testing](https://developer.apple.com/documentation/testing)**（`import Testing`、`@Test`、`#expect`）を使う。

```swift
// ファイル: QuotePostDecodingTests.swift
import Foundation
import Testing
@testable import APIQuoteMini

@Suite("QuotePost JSON 契約")
struct QuotePostDecodingTests {
    @Test
    func decodePostMatchesJSONPlaceholderShape() throws {
        let json = #"""
        {
          "userId": 1,
          "id": 1,
          "title": "sunt aut facere",
          "body": "quia et"
        }
        """#
        let data = Data(json.utf8)
        let post = try JSONDecoder().decode(QuotePost.self, from: data)
        #expect(post.id == 1)
        #expect(post.userId == 1)
        #expect(post.title == "sunt aut facere")
    }

    /// 意図的に壊した JSON では、デコード失敗（契約不整合の検出）
    @Test
    func decodeFailsWhenTitleIsNotString() {
        let bad = #"{"userId":1,"id":1,"title":999,"body":"x"}"#
        let data = Data(bad.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(QuotePost.self, from: data)
        }
    }
}
```

**確認方法:** スキームで **APIQuoteMini** を選び、**Product → Test（⌘U）**、または Test ナビゲータで **緑のチェック**が付く。上記2件が成功（2本目は**最低1本**目で足りるが、型ズレの落とし穴用に推奨）。  
`@testable import` が通らない場合 → テスト Target の **Host** と **同じ Team/署名**、**iOS シミュレータ**で再実行。  
**`No such module 'Testing'`** → **Xcode 16 以降**を使う。テストターゲットの **General → Minimum Deployments** と **Swift 6** を確認し、必要ならプロジェクトをアップデートする。

---

**ここまでできれば今日のゴール達成** — `async` 取得 → ViewModel の `phase` 更新 → SwiftUI 反映。HTTP 成否、空データ、デコード失敗の**入口**に触れている。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）:** 0〜10（本編の余裕に応じて）

### Easy（5〜10分）

`ContentView` の `.loaded` で `Text(post.body).lineLimit(3)` を追加し、本文を要約表示。

**回答例（抜粋）**

```swift
Text(post.body)
    .lineLimit(3)
    .font(.subheadline)
```

---

### Medium

`load()` 内の `URLSession.shared.data(from:)` を、`URLRequest` + `data(for:)` に変え、**`Accept: application/json`** を付与する。振る舞いは同一でよい。

**回答例**

```swift
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.setValue("application/json", forHTTPHeaderField: "Accept")
let (data, response) = try await URLSession.shared.data(for: request)
```

---

### Hard

次の**いずれか**（併用するとより実務に近い）:（1）`onDisappear` / 再取得直前に `Task` を `cancel` し、**遅延レスポンスで state を上書きしにくくする**。（2）`load` に**世代（世代 ID）**を入れ、**最後に開始した取得の完了だけ**が `phase` を更新する。

**回答例（1）View — 手動「再取得」用の `Task` を保持し、上書き前に `cancel`**

`ContentView` に `@State` を足し、**初回**は従来どおり `.task`、**再取得**だけ `loadTask` に乗せる。画面が消えたら `loadTask` を捨てる。

```swift
// ContentView.swift に追加・変更（既存の @State 群の下）
@State private var loadTask: Task<Void, Never>?

// body 内: Button("再取得") を差し替え
Button("再取得") {
    loadTask?.cancel()
    loadTask = Task { await viewModel.load() }
}

// body の末尾の modifier に追加（VStack など最後）
.onDisappear { loadTask?.cancel() }
```

**回答例（2）ViewModel — 世代 ID で「遅い古いレスポンス」を採用しない**

`class` 内に **`loadGeneration` を1つ**置き、`load()` 開始のたびにインクリメントする。古い `load` は変数 `g` に**開始時点の番号**を持ち、**成功・各 catch の直前**に `g == loadGeneration` を満たすときだけ `phase` を更新する。`try Task.checkCancellation()` をネット前に入れると、**子 `Task` の `cancel` と連動**しやすい（[Swift のタスク取り消し](https://developer.apple.com/documentation/swift/task)）。

`QuoteViewModel` の **ステップ3 完成版**を、次のように差し替え（`private let url` など既存のまま。プロパティを1行足し、`load()` 全体を置き換え）。

```swift
private var loadGeneration = 0

func load() async {
    loadGeneration += 1
    let g = loadGeneration
    phase = .loading
    do {
        try Task.checkCancellation()
        let (data, response) = try await URLSession.shared.data(from: url)
        guard !data.isEmpty else {
            throw URLError(.badServerResponse)
        }
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let post = try JSONDecoder().decode(QuotePost.self, from: data)
        guard g == loadGeneration else { return }
        phase = .loaded(post)
    } catch is DecodingError {
        guard g == loadGeneration else { return }
        phase = .failed("データの解釈に失敗（サーバー応答の形が想定外の可能性）")
    } catch {
        guard g == loadGeneration else { return }
        if error is CancellationError {
            phase = .idle
            return
        }
        if (error as? URLError)?.code == .cancelled {
            phase = .idle
            return
        }
        phase = .failed(error.localizedDescription)
    }
}
```

**注意:** 取消しは `CancellationError` だけでなく **`URLError` の `.cancelled`** になることも多い。本例のように両方扱うか、失敗表示に出さないかは**プロダクト方針**で決める。世代 ID は**レース**対策、取消し分岐は**失敗扱いにしたくない** UX 向け。併用が実務に近い。

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）:** 3

1. **BFF からの1画面1 GET** — 例: モバイル用に集約された `GET /me/summary` を画面表示の `.task` で取り、同じ `Phase` 列挙型で**ローディング・中身・403（再ログイン誘導）**を分岐。KPI 文言は**サーバが決めたラベル**をそのまま出し、**クライアントのハードコーディング**を減らす。  
2. **オフライン時の手動再試行** — 圏外で `URLError` →「通信できません＋再試行」ボタン。`viewModel.load()` の**冪等化**（何度押しても同じ GET）を意識し、**連打**で多重リクエストが出ないよう、追加課題のキャンセル/世代IDとセットで扱うのが多い。  
3. **契約の回帰テスト** — リリース前に、**採取した生 JSON サンプル**（個人情報はマスク）を `Data` リソース化し、**`Decodable` テスト**を CI で回し、**バックエンドの予告なしキー型変更**を早期に掴む（本教材の `testDecode` 拡張ライン）。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）:** 2

- `URLSession` の `data(from:)` を `async/await` で待つ。**HTTP ステータス・空データ**を捨てずに、デコード前に弾く。  
- View からは「いつ `load` するか」だけ。状態は ViewModel の **`phase` のみ**信頼。  
- **デコード**は 200 でも壊れうる。`DecodingError` を**ログとユーザー向け**で分けて扱うのが実務の入り口。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）:** 2

1. **依存注入** — `URLSession` 互換の `protocol` や、[`URLProtocol`](https://developer.apple.com/documentation/foundation/urlprotocol) スタブで、**`load()` を完全オフラインテスト**。  
2. **並行** — 画面をセクション分けし、`async let` で **2 GET を同時**に取り、合流して 1 画面に合成。

---

## 時間配分（合計）

| セクション     | 目安（分） |
|----------------|------------|
| 1. 今日のゴール | 0 |
| 2. 事前知識   | 5 |
| 3. 理論       | 9 |
| 4. ハンズオン | 36 |
| 5. 追加課題   | 0〜10（任意） |
| 6. 実務例     | 3 |
| 7. まとめ     | 2 |
| 8. 布石       | 2 |
| **合計**      | **60**（5は除く。5を行うと最大約70） |

（60 分は「余裕を含めない」学習想定。ハンズオン内で行き詰まったら、**トラブル**節を先に当て、テスト2本目はスキップ可。）

---

## 参考（公式・一次情報）

- [URLSession.data(from:delegate:)](https://developer.apple.com/documentation/foundation/urlsession/3767353-data)  
- [WWDC21 — Use async/await with URLSession](https://developer.apple.com/videos/play/wwdc2021/10095)  
- [Swift Testing](https://developer.apple.com/documentation/testing)（`#expect`、`@Test`）  
- [Observation / @Observable](https://developer.apple.com/documentation/observation)  
- [View.task](https://developer.apple.com/documentation/swiftui/view/task(priority:_:))  

---

*教材更新: 2026-04-26 / 想定: Xcode 16 系, Swift 6, iOS 17+ (Observable 利用) / ステップ5テスト: Swift Testing*
