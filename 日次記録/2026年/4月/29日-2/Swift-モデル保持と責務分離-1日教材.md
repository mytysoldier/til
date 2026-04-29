# Swift: モデル保持と責務分離 — 1日学習教材

**参照（最新のデータフロー／観測）**  
[Observation | Apple Developer Documentation](https://developer.apple.com/documentation/Observation)  
[Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)  
[Codable](https://developer.apple.com/documentation/Swift/Codable) の公式ドキュメント  

**想定環境**: Xcode 16 以降（Swift Testing を使うステップがあるため）、デプロイターゲット iOS 17 / macOS 14 以降の SwiftUI アプリ、`@Observable` を使用。

**60分での目安（区切り）** — 初回は Xcode 操作に **10〜15分の余裕**を見てもよい。

| 区切り | 目安 |
|--------|------|
| 今日のゴール | 3 |
| 事前知識チェック | 5 |
| 理論 | 10 |
| ハンズオン（プロジェクト〜UI〜テスト） | 34 |
| 実務での使いどころ | 5 |
| まとめ・明日の布石 | 3 |
| **合計** | **約60**（追加課題は別） |

---

## 今日のゴール

**目安時間（分）**: 3

TODO 一覧を **`Codable` モデル**として表し、**読み書きはデータ層（Repository）**、**画面状態と操作は ViewModel（`@Observable`）** に分けて、SwiftUI で **状態更新の流れ（View → ViewModel → Repository → 永続化）** が追えるミニアプリを一通り動かす。最後に **Repository の単体テスト（Swift Testing）を1本**通し、UI を起動しなくても永続の往復が保証できる状態にする。

---

## 事前知識チェック（3問）※回答付き

**目安時間（分）**: 5

1. **`struct` と `class` を SwiftUI の「状態モデル」に使うときの典型の違いは何ですか。**  
   - **解答の要点**: SwiftUI が追跡しやすいのは、`@Observable class` で共有インスタンスを持つクラス、`@State` や `@Binding` で扱う値型など、**更新の伝播経路が明確な形**になること。複雑な共有状態はクラス、`@Observable`（公式の「モデルデータの管理」を参照）。

2. **MVVM で「モデル」「View」「ViewModel」のうち、`Codable` を付けるのが向いているのはどれですか。**  
   - **解答の要点**: 永続化する**純データ**ならモデル側（構造体）に **`Codable` を宣言**することが多い。View はレイアウト、ViewModel は **UI のための整形・操作**。永続フォーマットの詳細は **Repository／Store に閉じる**とテストしやすい。

3. **「View が直接 `FileManager` で JSON を読む」のが不利な一番の理由は何ですか。**  
   - **解答の要点**: **責務が混ざる**ため。View が壊れたときファイル I/O の修正も絡む。テストでも UI を立ち上げざるを得なくなる。**データの取得・保存を別型に隔離**して、View は画面に関心を置くほうがメンテしやすい。

---

## 理論（重要ポイント）

**目安時間（分）**: 10

この教材では「比較観点」を **ひとつ** に絞ります：**永続フォーマット（JSONファイル）かつ責務分離**。深い設計論は「追加課題」へ回します。

1. **モデル（Domain / `Codable`）は「そのままファイルの形」を表現してよい（小規模では）**  
   - アプリ固有のリスト JSON と 1 対 1 が分かりやすい。  
   - **よくある誤解**: 「ViewModel も全部 `Codable` にしないとダメ」。必要なら **保存用DTO** に分ける（本稿のミニ構成ではモデル直保存で十分）。  
   - **落とし穴**: 将来スキーマが変わったときは **バージョン付けやマイグレーション**が必要になりうる。`Date` や `Decimal` を足すと **エンコード戦略**（`.iso8601` 等）も設計対象になる。

2. **ViewModel は「画面が必要な状態」と「ユーザー操作」を集約する**  
   - SwiftUI と相性が良いのが **`@Observable` クラス**（[`Managing model data in your app`](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)）。  
   - **よくある誤解**: 「ViewModel に永続化の詳細（パス文字列の組み立て）まで全部書く」。小さなアプリでは可能だが、**テストと差し替え**のため **Repository に委譲**するのが定石。  
   - **落とし穴**: ViewModel が肥大化すると「すべてのレイヤ」のコードが同居し、MVVM が形骸化する。  
   - **落とし穴（非同期）**: View から `Task { await ... }` で呼ぶ場合、**画面を閉じたあともタスクが走り続ける**ことがある。本ハンズオン規模では実害は出にくいが、一覧が巨大になったりキャンセルが必要になったら `task(id:)` や **`Task.checkCancellation()`** を検討する（発展）。

3. **データ層（Repository / Store）は「モデルの読み・書き」だけ担当する**  
   - 入力: メモリ上のモデル／出力: ファイルや結果。Swift の **`Codable`** + **`JSONEncoder` / `JSONDecoder`** が標準。  
   - **よくある誤解**: 「Repository で UI文言を組み立てる」。しない。UI に関係する文字は View／ViewModel 側。  
   - **落とし穴**: `save` を `try?` で握りつぶすと **失敗しても画面上は成功に見える**。本稿は最小構成のため `try?` を使うが、実務では **エラー状態**（バナーやログ）へ至少なくとも繋ぐ。

4. **状態更新の流れを一文で決める**: **単方向に近い流れ**がブレません  
   - 例:**ユーザー操作 → View が ViewModel のメソッド → ViewModel が Repository → モデルが更新／保存 → View が観測して再描画**（`body` が `@Observable` のプロパティを読めば自動追跡）。  
   - **落とし穴**: `ObservableObject` と `@Observable` を混ぜると、`@Published` と「マクロ自動追跡」で頭が混乱する。本教材は **Observation の `@Observable` に統一**（iOS 17+）。

5. **`@Observable` を使うときの SwiftUI 側ルールの要点**  
   - **所有する側**では `@State private var viewModel = ...` のように **参照を保持**（公式のマイグレーション記事と同様の考え方）。  
   - **Binding が要る**場合は `@Bindable`（公式「Managing model data」参照）。  
   - **よくある誤解**: **`@ObservedObject` で `@Observable` を包む** — Apple ドキュメントで **非推奨／エラー**の理由が説明されている（`ObservableObject` 用なので）。  
   - **落とし穴**: 観測から外したいプロパティは `@ObservationIgnored`（必要になったら調べる程度で十分）。

6. **設計の選択肢（1つ）: 永続先に「JSON ファイル」と「UserDefaults」**  
   - **この教材の選択**: **JSON ファイル（Application Support 等）**。TODO リストのような **可変長配列**は JSON の方が自然。  
   - **UserDefaults が向く例**: 少数のプリミティブや小さな設定値。大きな JSON を突っ込むのは **避けた方がよい**（意図と性能の両面）。

7. **型と並行性の落とし穴（読みどころ）**  
   - **`TodoRepository: Sendable`**: プロトコルが並行性セーフを宣言しているので、実装側は **`Sendable` にできる設計**（値キャプチャのみ、`class` は設計次第で `@unchecked Sendable` が付くことがある）を意識する。コンパイル警告が出たら **共有ミュータブル状態**がないかを疑う。  
   - **`@MainActor` の ViewModel**: UI 由来のメソッドはメインスレッドで動く想定に揃える。Repository が **actor** になった場合は `await` の境界が増える（追加課題の `InMemoryTodoRepository` 参照）。

---

## ハンズオン（手順）

**目安時間（分）**: 34（うちステップ6のテストに **約6〜8分**）

**成果物の名前**: `TodoMini`（Xcode の **Product Name** も `TodoMini` にすると、`import TodoMini` やモジュール名が手順どおりになる）

**プロジェクトの置き場所**: 教材を置いているリポジトリの **ルート**（または任意の親フォルダ）直下に **`tutorial/`** を作り、その中に Xcode プロジェクトを置く（本リポジトリでは `tutorial/` を `.gitignore` で除外する想定）。

**最初に確認すること（詰まり予防）**

- メニュー **Xcode → About** でバージョンが **16 以降**か（ステップ6で Swift Testing を使うため）。  
- 新規プロジェクト作成後、画面上部で **実行先がシミュレータ**（例: iPhone 16）になっているか。  
- テスト追加後は **Product → Scheme → Edit Scheme** の **Test** に `TodoMiniTests` が含まれているか（含まれていなければ `⌘U` でテストが走らない）。

### ステップ0: `tutorial` 用の `.gitignore`（教材リポジトリ直下）

学習用の試作をコミットに含めたくない場合、**教材ファイル（この `.md`）が置いてあるリポジトリのルート**に次を置く（TIL 全体のルートで管理しているならそのルート）。

```gitignore
# 学習用ハンズオン（教材手順で tutorial 配下に Xcode プロジェクトを作る）
tutorial/
```

**確認方法**: `git status` で `tutorial/` 配下が無視される（既にコミット済みなら一度 `git rm -r --cached tutorial` が必要な場合あり）。

---

### ステップ1: Xcode で新規 App を `tutorial` 以下に作成

1. Xcode → **File → New → Project** → **App**  
2. **Interface: SwiftUI**、**Storage: None**（自分で Repository を書くため）  
3. **Product Name**: `TodoMini`（推奨）  
4. 保存先: `.../あなたのリポジトリ/tutorial/TodoMini/` のように **`tutorial` 配下**を指定  

**確認方法**: `⌘B` でビルドでき、シミュレータで空の `ContentView` が表示される。

---

### ステップ2: モデル `TodoItem.swift`（`Codable`）

`TodoMini` ターゲットに **新規 Swift ファイル** `TodoItem.swift` を追加（ファイルを選んだら右の **Target Membership** で `TodoMini` にチェック）。

```swift
import Foundation

/// 保存する単位の純データ（View と ViewModel からも利用）
struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool

    init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}
```

**確認方法**: ビルド成功。Preview はまだなくてよい。

---

### ステップ3: データ層 `TodoRepository.swift` — プロトコルと JSON 実装

`TodoRepository.swift` を追加。**責務**: モデル配列の読み込み／保存のみ。

```swift
import Foundation

enum TodoRepositoryError: Error {
    case encodingFailed
    case decodingFailed
}

protocol TodoRepository: Sendable {
    func load() async throws -> [TodoItem]
    func save(_ items: [TodoItem]) async throws
}

/// Application Support に JSON で保存する最小実装
final class JSONTodoRepository: TodoRepository, @unchecked Sendable {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = base.appendingPathComponent("TodoMini", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("todos.json")
        }
    }

    func load() async throws -> [TodoItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        do {
            return try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            throw TodoRepositoryError.decodingFailed
        }
    }

    func save(_ items: [TodoItem]) async throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(items)
        } catch {
            throw TodoRepositoryError.encodingFailed
        }
        try data.write(to: fileURL, options: [.atomic])
    }
}
```

**確認方法**: ビルド成功。Simulator 実行後、**デバイス上のコンテナ内**に JSON ができるかは後続ステップ後に確認可能（本題は責務分離）。

**落とし穴**: `JSONTodoRepository` の **デフォルトの保存先**はシミュレータの Application Support 配下。**アプリを削除**するとファイルも消える（期待どおりかどうかを知っておく）。

---

### ステップ4: ViewModel `TodoListViewModel.swift`（`@Observable`）

`Observation` と SwiftUI の標準だけで足りる構成にするため、クラスに **`@Observable`** を付ける（[`Observable()`](https://developer.apple.com/documentation/Observation)）。

```swift
import Foundation
import Observation

@Observable
@MainActor
final class TodoListViewModel {
    private let repository: TodoRepository

    var items: [TodoItem] = []
    var newTitle: String = ""

    init(repository: TodoRepository) {
        self.repository = repository
    }

    func loadOnAppear() async {
        do {
            items = try await repository.load()
        } catch {
            // 最小構成: 壊れたJSONなどは空配列に落とす（実務ではエラー表示・ログへ）
            items = []
        }
    }

    func addTodo() async {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = items
        next.insert(TodoItem(title: trimmed), at: 0)
        items = next
        newTitle = ""
        await persist()
    }

    func toggle(_ item: TodoItem) async {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isDone.toggle()
        await persist()
    }

    private func persist() async {
        try? await repository.save(items)
    }
}
```

**状態更新の流れ（確認のポイント）**:  
ユーザー操作で `items` が変わる → `persist` で Repository が JSON 書き込み → 次回起動で `load` により復元。

**確認方法**: コンパイルが通り、`TodoListViewModel` が **View を import していない**こと（責務分離の目印）。

**落とし穴**: `persist` の `try?` は **保存失敗を無視する**。検証中は **`print(error)` を一時的に足す**と原因（ディスク権限など）が掴みやすい。

---

### ステップ5: `ContentView.swift` で UI と接続

`TodoMiniApp.swift` で **ViewModel を `@State` で保持**し、`ContentView` に渡す（公式の「モデルデータの管理」に沿った形）。

```swift
import SwiftUI

@main
struct TodoMiniApp: App {
    @State private var viewModel = TodoListViewModel(repository: JSONTodoRepository())

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
```

`ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: TodoListViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.items) { item in
                    HStack {
                        Text(item.title)
                        Spacer()
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isDone ? .green : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await viewModel.toggle(item) }
                    }
                }
            }
            .navigationTitle("TODO")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("追加") {
                        Task { await viewModel.addTodo() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                TextField("新しいタイトル", text: $viewModel.newTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(.bar)
            }
            .task {
                await viewModel.loadOnAppear()
            }
        }
    }
}

#Preview {
    ContentView(viewModel: TodoListViewModel(repository: JSONTodoRepository()))
}
```

**確認方法（期待される挙動）**:  
- 起動で空（または前回の JSON）  
- テキスト入力 → **追加**で一覧先頭に行が増える  
- 行タップで **チェックが切り替わる**  
- **アプリを完全終了 → 再起動**しても **内容が残る**  

**つまずき**: 追加しても一覧が増えない → **TextField が空になっているか**、**追加**を押す前にタイトルを入れたかを確認。永続しない → **シミュレータのホームからスワイプで終了**してから再起動（単に Stop しただけではプロセス状態が残ることがある）。

---

### ステップ6（テスト）: 疑似ユニットテスト — Repository だけを検証（**Swift Testing**）

**前提**: Xcode 16 以降（[Swift Testing | Apple Documentation](https://developer.apple.com/documentation/testing) が標準で使える構成）。

1. **File → New → Target** → **Unit Testing Bundle** を追加（名前は `TodoMiniTests` 推奨）。  
2. テストターゲットの **General → Testing** で **Host Application** が `TodoMini` になっているか確認（通常は自動）。  
3. 新規ファイル `TodoRepositoryTests.swift` を **テストターゲットにだけ**追加（`TodoMiniTests` の Target Membership にチェック）。

テスト側は **`import Testing`** と `@Test` / `#expect` を使う。**XCTest（`import XCTest`／`XCTAssert*`）では書かない。**

モジュール名は **Product Name** と同じ（`TodoMini`）であること。

`TodoMiniTests/TodoRepositoryTests.swift` の例（**一時ディレクトリ**に JSON を書いて検証。使い終わったら削除してテスト間の汚染を防ぐ）:

```swift
import Testing
@testable import TodoMini

@Test
func jsonRepository_roundTrip_savedEqualsLoaded() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let url = dir.appendingPathComponent("t.json")
    let repo = JSONTodoRepository(fileURL: url)

    let sample = [TodoItem(title: "A"), TodoItem(title: "B", isDone: true)]
    try await repo.save(sample)
    let loaded = try await repo.load()

    #expect(loaded == sample)
}
```

トップレベルに置くか、`@Suite` 型の中にまとめてもよい（[Swift Testing](https://developer.apple.com/documentation/testing) のドキュメント「Organizing tests」などを参照）。

**確認方法**: `⌘U` でテストが **緑**。`No tests` と出たら **Scheme の Test にターゲットが入っているか**、**ファイルの Target Membership** を再確認。

永続層だけが動けば、View を起動しなくても **データの往復**を保証できる。

---

**ここまでできれば今日のゴール達成**  
モデル（`Codable`）・Repository（I/O）・ViewModel（`@Observable` と操作）・View（表示とイベント）が分かれ、**状態更新の流れ**と **MVVM＋永続化の最小構成**が手元で再現できています。

---

## 追加課題（時間が余ったら）

各難易度に **目安時間** と **回答の方向**（コード例）を付けます。

### Easy（目安 5〜10 分）

**課題**: `TodoItem` に `createdAt: Date` を追加し、JSON のまま保存・表示まで通す。

**回答例（抜粋）**:

```swift
// TodoItem
var createdAt: Date

init(id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date = .now) {
    self.id = id
    self.title = title
    self.isDone = isDone
    self.createdAt = createdAt
}
```

`JSONEncoder` は `Date` を ISO8601 風にしたい場合は `encoder.dateEncodingStrategy` を調整。

---

### Medium（目安 20〜30 分）

**課題**: 「削除」を追加。スワイプで削除、`persist` と整合。

**回答例（ViewModel に追加）**:

```swift
func delete(at offsets: IndexSet) async {
    // `remove(atOffsets:)` は SwiftUI の拡張のため、Foundation だけの層では使えない。
    // インデックスは大きい方から消すと、配列のずれで取り違えない。
    for index in offsets.sorted(by: >) {
        items.remove(at: index)
    }
    await persist()
}
```

```swift
// List に
.onDelete { offsets in
    Task { await viewModel.delete(at: offsets) }
}
```

---

### Hard（発展）

**課題**: **`InMemoryTodoRepository`** を用意し、`TodoListViewModel` のテストで **一覧操作**を検証（ViewModel が Repository をモックできることの確認）。

**回答例**:

```swift
actor InMemoryTodoRepository: TodoRepository {
    private var storage: [TodoItem] = []

    func load() async throws -> [TodoItem] { storage }
    func save(_ items: [TodoItem]) async throws { storage = items }
}
```

```swift
import Testing
@testable import TodoMini

@Test
@MainActor
func viewModel_addTodo_insertsFromNewTitle() async {
    let repo = InMemoryTodoRepository()
    let vm = TodoListViewModel(repository: repo)
    vm.newTitle = "hello"
    await vm.addTodo()
    #expect(vm.items.first?.title == "hello")
}
```

※ `TodoListViewModel` が `@MainActor` なら、テストに **`@MainActor`** を付ける（上の例のとおり）。`#expect` は Swift Testing のアサーション。

---

## 実務での使いどころ（具体例3つ）

**目安時間（分）**: 5

1. **オンボーディングやフォームの下書き保存** — 入力途中の項目を **`Codable` モデル＋ファイル Repository** で退避し、ViewModel が「入力欄の文字列」「送信ボタンの活性」とつなぐ。デザイン変更では View だけ差し替え、**保存形式は Repository が吸収**する。

2. **オフライン優先のローカルキャッシュ（一覧・設定）** — 起動時は **JSON を先に読んで即表示**し、別タスクで API から取得したら Repository 経由で更新。責務分離すると **「キャッシュだけ壊れた」「APIだけ壊れた」**の切り分けがしやすい。

3. **機能ごとの設定ストアの共有** — 複数画面から同じ **Repository／ViewModel** を参照し、**`@Observable` の共有インスタンス**（環境や上位 `App` の `@State`）で同期。A/B や実験用の表示分岐は **別 ViewModel** に閉じ、データの出所は同じ Repository に寄せる。

---

## まとめ（今日の学び3行）

**目安時間（分）**: 2

- **モデルは `Codable`、読み書きは Repository に閉じ、ViewModel は `@Observable` で画面の状態と操作をまとめる**と、状態の流れが追いやすい。  
- **SwiftUI では `@Observable` を直接読ませ、`@ObservedObject` で包まない**（公式の Migrating と Managing model data を確認）。  
- **JSON ファイル + Swift Testing（`#expect`）で Repository を単体テスト**すると、UI を動かさず永続層だけの正しさを担保できる。

---

## 明日の布石（次のテーマ候補を2つ）

**目安時間（分）**: 1

1. **`@ObservationIgnored` と依存注入**: ViewModel が持つキャッシュやロガーを観測から外す／テスト時に Repository を差し替える応用。

2. **Combine との棲み分け**: 非同期ストリームやデバウンスが必要になったとき、Repository／UseCase で Combine をどこまで使うか（本教材より一段上の論点）。
