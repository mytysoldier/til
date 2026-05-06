# Swift: Repository + Model 分離（MVVM で動く一覧画面）

**目安時間（分）: 約 54〜60（セクション 1〜4・6〜8 の合計。**手慣れたら下限、Xcode での初回作成なら **+10〜15 分のバッファ**を見てよい。追加課題は別途）**

---

## 1. 今日のゴール

**目安時間（分）: 2**

`Model`・`Repository`・`ViewModel` を分離し、SwiftUI で **一覧が表示されるところまで**をゴールとする。**比較観点は「データの流れが一方向に追えるか」**に絞る。あわせて **ローディング / エラー / 空配列**の 3 状態が区別できるようにする（後述のチェックリストで確認）。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間（分）: 5**

1. **SwiftUI で `body` が再評価される主因は何か。**  
   **回答例:** 読み取った状態（購読対象のプロパティ）が変わったときなど。Observation では、ビューが実際に読んだプロパティにだけ反応することが多い。

2. **`throws` と `async` を併記した関数（`async throws`）が表すことは。**  
   **回答例:** 非同期に実行でき、かつ完了時に成功値かエラーかのどちらかを返す、という両方を表す。

3. **`@MainActor` が付いたメソッドは、どのスレッド上で実行されることが期待されるか。**  
   **回答例:** メインスレッド（UI 属性の更新などに使う）。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間（分）: 9**

公式ではモデルデータ管理に **Observation**（`@Observable`）が推奨される。移行ガイド: [Migrating from the Observable Object protocol to the Observable macro](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro)。モデルデータ全般: [Managing model data in your app](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app)。

### ポイント 1: Model は「形」と検証だけ（UI は持たない）

- **内容:** DTO / ドメイン型は、`Codable` や単純な不変条件に集中させ、ローディングやアラート文は載せない。  
- **よくある誤解 / 落とし穴:** JSON と 1 対 1 で `CamelCase` と `snake_case` がずれると、`CodingKeys` が必要になり「突然デコードだけ失敗する」。型は合っているつもりでもキー不一致が典型。

### ポイント 2: Repository は「取得の詳細」を隠す境界

- **内容:** ファイル／HTTP／キャッシュなど **データソース差分をひとつの同期・非同期 API の裏側に閉じる**。  
- **よくある誤解 / 落とし穴:** `Bundle` 読み込みや `JSONDecoder.decode` が **同期的に重くなる処理**になり得る。教材では簡略化するが、実務では I/O とデコードのスレッド設計まで踏み込む。

### ポイント 3: ViewModel は「画面状態機械」（ロード中・成功・失敗・空）

- **内容:** `isLoading`・ユーザー向け `errorMessage`・`books` など。**成功だが配列が空**は「異常」とは限らず、文言を変えるほうが親切なことが多い。  
- **よくある誤解 / 落とし穴:** `catch` でメッセージだけ出して **`books` を前回のままにする**と、画面上「古い一覧 + エラー」が共存しユーザーが困惑する。**失敗時に一覧をどう見せるか**は仕様として決める。

### ポイント 4: View は描画・入力イベントの転送のみ

- **内容:** `.task { await vm.load() }` のような **開始トリガだけ**が View に残るようにする（ロジック本体は VM）。  
- **よくある誤解 / 落とし穴:** `.task` はビューライフサイクルに紐づき **自動キャンセル**が効くことがある。連打リロードなどでは **競合（あと勝ち／先勝ち）**が起きやすく、それをどう吸収するかは実務では設計項目。

### ポイント 5: `@MainActor` を ViewModel に置くときの非同期パス

- **内容:** ViewModel が `@MainActor` なら、プロパティ更新はメイン側に揃えやすい。Repository の `fetch` が内部で同期的にファイル I/O をする場合、その時間は **メインを占有**しうる（教材規模では許容しつつ認識しておく）。  
- **よくある誤解 / 落とし穴:** `await` が付いていても「必ず別スレッド」ではない。**誰がどのキューでデコードしているか**を追う習慣が必要。

### ポイント 6（設計の選択肢 1 つ）: 依存注入は初期化子で足りることが多い

- **内容:** `init(repository:)` で渡し、ユニットテストでは **同じプロトコルに合わせたフェイク**に差し替える。環境オブジェクトは画面階層が深いほど便利だが、**呼び出し元が増えるほど依存の把握が難しくなる**。  
- **よくある誤解 / 落とし穴:** シングルトンにすると速い反面、テストでの差し替えと **実行順の隠れた依存**が増えやすい。

---

## 4. ハンズオン（手順）

**目安時間（分）: 36**

**前提:** Xcode、**iOS 17 以上**の SwiftUI アプリ。言語 Swift。本教材は **Observation の `@Observable`** を使う（[Observation](https://developer.apple.com/documentation/Observation)）。**ユニットテストは Swift Testing**（`import Testing`、`@Test`、`#expect`）。**Xcode 16 以降**を推奨（[Swift Testing](https://developer.apple.com/documentation/testing)）。

**フォルダ方針:** プロジェクト内に **`tutorial/` ディレクトリ**を作り、Swift ソースはその下へ。Xcode では **フォルダを追加するとき「Copy items if needed」を必要に応じて選択し、作成したファイルは必ずアプリターゲットにチェック**する。

**ゴール確認チェックリスト（Run 後）**

| 状態 | 期待 |
|------|------|
| 初回読み込み | 一瞬〜短時間 `ProgressView` が出て、2 件表示 |
| `books.json` を外した／壊した | 赤いエラー文が出る |
| JSON を `[]` にした | 空の `List`（真っ白に見える場合は「空である」ことを確認） |

**実行方法:** シミュレータで Run（⌘R）。

---

### 全体の流れ（迷子防止）

0. `tutorial/` と `.gitignore`  
1. `Book`（Model）  
2. `BookRepositoryProtocol` と `LocalJSONBookRepository`、`books.json` と **Copy Bundle Resources**  
3. `BookListViewModel`  
4. `BookListView` と `App` の差し替え  
5. ユニットテスト 1 本（フェイク Repository）

---

### ステップ 0: `tutorial` ディレクトリと `.gitignore`

1. Xcode で **App**（SwiftUI）を新規作成。プロダクト名は任意（以降は例として **`MVVMRepositoryDay1`** と書く）。**Organization Identifier** も設定する。
2. Finder で、`.xcodeproj` と同じ階層に **`tutorial`** フォルダを作成。
3. Xcode の Project Navigator でプロジェクト名を右クリック → **Add Files to "…"** → `tutorial` を選び、**Create groups**（まだ中身がなくてもよい。後からファイルを足す）。
4. プロジェクトルートに **`.gitignore`** を置き、学習用をコミットしない方針なら次を追記する。

```
# 教材どおり tutorial 以下をコミット対象外にする（必要ならコメントアウト）
tutorial/
```

**確認方法:** `tutorial` が Xcode ナビゲータに見えること。Git 利用時は `git check-ignore -v tutorial` などで無視されることを確認できるとよい。

---

### ステップ 1: Model（`tutorial/Models/Book.swift`）

1. `File > New > File…` → **Swift File**。保存先は `tutorial/Models/Book.swift`。
2. 右ペイン **File Inspector** の **Target Membership** で **アプリターゲット**にチェック。

```swift
import Foundation

struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var author: String
}
```

**確認方法:** ⌘B でビルド成功。

---

### ステップ 2: Repository + `books.json`（Bundle 登録が成否を分ける）

1. `tutorial/Repositories/BookRepository.swift` を新規作成し、ターゲットに含める。

```swift
import Foundation

protocol BookRepositoryProtocol {
    func fetchBooks() async throws -> [Book]
}

/// 教材用: Bundle 内の JSON（ネットワーク不要）
final class LocalJSONBookRepository: BookRepositoryProtocol {
    private let resourceName: String

    init(resourceName: String = "books") {
        self.resourceName = resourceName
    }

    func fetchBooks() async throws -> [Book] {
        try await Task.sleep(nanoseconds: 150_000_000)

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw URLError(.fileDoesNotExist)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Book].self, from: data)
    }
}
```

2. **`books.json` を追加:** `File > New > File…` → **Empty** 相当で `books.json` を作成（例: `tutorial/Resources/books.json`）。**Target Membership でアプリにチェック。**
3. **必須:** プロジェクトの **Targets > アプリ > Build Phases > Copy Bundle Resources** に **`books.json` が並んでいる**ことを確認する。並んでいない場合は **+** で追加。**ここが抜けるとランタイムでファイルが見つからず一覧が出ない。**

`tutorial/Resources/books.json` の例（`id` は **有効な UUID 文字列**。コピペ可）:

```json
[
  {"id":"A1EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11","title":"サンプル1","author":"著者A"},
  {"id":"B2FEBC99-9C0B-4EF8-BB6D-6BB9BD380A12","title":"サンプル2","author":"著者B"}
]
```

**確認方法:** ⌘B 成功。**Product > Show Build Folder in Finder** まで行かなくてよいが、Run 後に一覧が出ることが最終確認。**出ないときはほぼ Copy Bundle Resources かファイル名 (`books` / `books.json`) の不一致。**

---

### ステップ 3: ViewModel（`tutorial/ViewModels/BookListViewModel.swift`）

1. `import Observation` と `@Observable` が効く環境であること（デプロイメント iOS 17+）。
2. 読み込み失敗時は **`books` を空に戻す**（古い結果とエラーの共存を避ける）。

```swift
import Foundation
import Observation

@MainActor
@Observable
final class BookListViewModel {
    private let repository: BookRepositoryProtocol

    private(set) var books: [Book] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(repository: BookRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            books = try await repository.fetchBooks()
        } catch {
            books = []
            errorMessage = "読み込みに失敗しました（設定・ファイルを確認）"
        }
    }
}
```

**確認方法:** ⌘B 成功。**注意:** `@Observable @MainActor` にしたので `BookListViewModel` はメインアクタ隔離。`load()` を `View` から呼ぶ場合は `.task` から `await` でよい。

---

### ステップ 4: View + App エントリ

`tutorial/Views/BookListView.swift`:

```swift
import SwiftUI

struct BookListView: View {
    @State private var viewModel: BookListViewModel

    init(viewModel: BookListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("読み込み中")
                } else if let message = viewModel.errorMessage {
                    ContentUnavailableView(
                        "読み込みエラー",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                    .foregroundStyle(.red)
                } else if viewModel.books.isEmpty {
                    ContentUnavailableView("まだデータがありません", systemImage: "books.vertical")
                } else {
                    List(viewModel.books) { book in
                        VStack(alignment: .leading) {
                            Text(book.title).font(.headline)
                            Text(book.author).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Books")
            .task {
                await viewModel.load()
            }
        }
    }
}
```

**App ファイル**（例: `MVVMRepositoryDay1App.swift`）を次のようにする。`ContentView` の代わりに `BookListView` を使う。

```swift
import SwiftUI

@main
struct MVVMRepositoryDay1App: App {
    var body: some Scene {
        WindowGroup {
            BookListView(
                viewModel: BookListViewModel(
                    repository: LocalJSONBookRepository()
                )
            )
        }
    }
}
```

**確認方法:** Run で **ローディング → 2 件**。`books.json` を一時的にリネームして Run すると **エラー用 UI**。`[]` の JSON にすると **空データ用 UI**。

**トラブルシューティング（優先度順）**

1. **Copy Bundle Resources** に `books.json` がない。  
2. **Target Membership** がアプリについておらず、型はあるが JSON がバンドルに入っていない。  
3. **デプロイメントターゲットが iOS 16 以下**で `ContentUnavailableView` や `@Observable` が使えない → ターゲットを 17 以上へ。  
4. **`@testable import` のモジュール名**がプロダクト名と異なる → 「ステップ 5」を参照し **Product Module Name** を確認。

---

### ステップ 5: ユニットテスト 1 本（フェイク Repository・Swift Testing）

**方針:** ViewModel と Repository の **境界**を検証する。UI はテストしない。**XCTest は使わず** [Swift Testing](https://developer.apple.com/documentation/testing) を使う。

1. Xcode で **File > New > Target…** → **Unit Testing Bundle**（または **Swift Testing Bundle** が出る Xcode ならそちら）。製品モジュール名が `MVVMRepositoryDay1` でない場合は、**Build Settings > Product Module Name** を確認し、後述の `@testable import` をそれに合わせる。
2. **フェイクはテストターゲット側**に置く（`FakeBookRepository` をアプリターゲットに入れないと、本番に混ざる）。
3. `tutorial/` を無視している場合でも、テストソースは **`MVVMRepositoryDay1Tests/`** のような **通常ディレクトリ**に置けばコミット可能（運用は任意）。

テストターゲットに `FakeBookRepository.swift`（またはテストファイル内に `private struct` でもよい）:

```swift
import Foundation
@testable import MVVMRepositoryDay1

struct FakeBookRepository: BookRepositoryProtocol {
    var books: [Book] = []
    var error: Error?

    func fetchBooks() async throws -> [Book] {
        if let error { throw error }
        return books
    }
}
```

`BookListViewModelTests.swift`:

```swift
import Foundation
import Testing
@testable import MVVMRepositoryDay1

@Suite("BookListViewModel")
struct BookListViewModelTests {
    @Test @MainActor
    func loadSuccess_assignsBooksAndClearsError() async {
        let id = UUID(uuidString: "A1EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11")!
        let expected = [Book(id: id, title: "t", author: "a")]
        let repo = FakeBookRepository(books: expected, error: nil)
        let vm = BookListViewModel(repository: repo)

        await vm.load()

        #expect(vm.books == expected)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }
}
```

**確認方法:** テストナビゲータで green（Swift のマークで実行）。**`No such module 'MVVMRepositoryDay1'`** のときは **スキームで Test をアプリターゲットと一緒にビルド**しているか、アプリターゲットが **検証対象としてビルド**されているかを確認する。

---

**ここまでできれば今日のゴール達成**（Model / Repository / ViewModel が分離し、一覧が動き、状態 3 分岐が確認でき、フェイクで Swift Testing の 1 テストが通る）。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）: 0〜40（任意。Easy 5〜10 / Medium 15〜25 / Hard 25〜40 の目安）**

### Easy（目安 5〜10 分）

**課題:** `author` でソートしてから `books` に代入する。

**回答例:**

```swift
var loaded = try await repository.fetchBooks()
loaded.sort { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
books = loaded
```

---

### Medium

**課題:** `FakeBookRepository` で `error` を渡し、**失敗時に `books` が空で `errorMessage` が非 nil**になるテストを 1 本追加する。

**回答例:**（同じテストターゲットで `import Foundation` と `import Testing` を済ませ、`FakeBookRepository` と `BookListViewModel` がインポート可能な状態にする）

```swift
import Foundation
import Testing
@testable import MVVMRepositoryDay1

@Test @MainActor
func loadFailure_clearsBooksAndSetsError() async {
    let repo = FakeBookRepository(
        books: [Book(id: UUID(), title: "x", author: "y")],
        error: URLError(.notConnectedToInternet)
    )
    let vm = BookListViewModel(repository: repo)
    await vm.load()
    #expect(vm.books.isEmpty)
    #expect(vm.errorMessage != nil)
}
```

---

### Hard

**課題:** `URLSession` 利用の `URLSessionBookRepository` を追加し、`App` では **ローカル／リモートを切り替え**可能にする（DEBUG のみリモート等）。**ATS・HTTP の例外**は必要なら `Info.plist` に明記する。

**回答例（骨子）:**

```swift
final class URLSessionBookRepository: BookRepositoryProtocol {
    private let url: URL
    private let session: URLSession

    init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    func fetchBooks() async throws -> [Book] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Book].self, from: data)
    }
}
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）: 3**

1. **マイページの「プロフィール取得」:** `UserProfileRepository` を **キャッシュ（ローカル）から即表示**しつつ、バックグラウンドで **API Repository** を叩いて差し替える。ViewModel は「表示用モデル + リフレッシュ中」のみ知ればよい。  
2. **Feature Flag / リモート設定:** 取得先を **Firebase Remote Config 用 / 自社 API 用**の 2 実装に分け、**ビルド種別や Debug メニュー**から `Repository` だけ差し替えて動作確認する。  
3. **購読・課金状態の表示:** 画面は「課金状態が不明／利用可／不可」の 3 状態を ViewModel が組み立て、取得の都合（StoreKit / サーバレシート検証）は Repository に閉じる。**審査用にスタブ Repository** を差すと、ストア接続なしで UI 検証が回せる。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）: 3**

- Repository で **取得の裏側**を隠すと、画面は **状態の見せ方**に集中できる。  
- ViewModel は **ロード中・成功・失敗・空**を区別し、失敗時に **古いデータをどう扱うか**まで含めて仕様にする。  
- `BookRepositoryProtocol` に合わせたフェイクで、**View を立ち上げずに**境界の振る舞いを固定できる。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）: 2**

1. **連打リロード・画面遷移時のタスクキャンセル**（`withTaskCancellationHandler` や ID 付き `.task` など、結果の取りこぼし防止）。  
2. **`Sendable` と actor / バックグラウンドデコード**（実機で読み込みが重いときのメインスレッド占有対策）。

---

## 参考リンク（公式）

- [Observation | Apple Developer Documentation](https://developer.apple.com/documentation/Observation)  
- [Swift Testing | Apple Developer Documentation](https://developer.apple.com/documentation/testing)  
- [Managing model data in your app | Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app)  
- [Migrating from the Observable Object protocol to the Observable macro | Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro)
