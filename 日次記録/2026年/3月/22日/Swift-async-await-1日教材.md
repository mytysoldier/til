# Swift: async/await / Task / 非同期の責務整理 + 4月アプリ候補の絞り込み（初級向け）

**想定:** Swift の文法（変数、関数、クラス）は一通り触れたことがある。業務で Swift を書くこともあるが、非同期はまだ自信がない、という前提です。  
**今日の方針:** 難しい言葉は少なめ。**まず画面で動かす** → **あとからテスト** の順で安心して進められるようにしています。

---

## 1. 今日のゴール

**目安時間（分）: 2**

**画面に「読み込み中 → 結果の文字」が出るアプリ**を自分の手で動かせるようになる。あわせて、「非同期の処理は View にベタ書きせず ViewModel に書く」という**実務でよくある形**を一度体験する。最後に **4月のアプリ候補を 1〜2 個に絞る**。

---

## 2. 事前知識チェック（3問）

**目安時間（分）: 5**

### Q1. `async` と `await` は、ざっくり何をするもの？

**回答:** **`async`** は「この処理は **すぐ終わらない** かもしれない」と印をつける。**`await`** は「その終わりを **ここで待つ**」という意味。ネット通信や待ち時間のあとに結果を受け取るときに使います。

### Q2. `Task { }` って何？

**回答:** **同期のコードの中から**、`async` な処理を動かしたいときに使う「箱」のようなものです。例: `Button` の中は同期なので、`Task { await 読み込み() }` のように書くことがあります。  
（※ `Task.detached` は今は **使わなくて大丈夫** です。上級者向けの選択肢だと思ってください。）

### Q3. SwiftUI の `body` の中に、`await` だけ書ける？

**回答:** **ダメです。** `body` は「今すぐ画面を描く」ための場所なので、待ちは書けません。代わりに **`.task { await ... }`** や **`Task { await ... }`** を使います。

---

## 3. 理論（重要ポイント）

**目安時間（分）: 14**

※ ここは **読んで「なんとなく」で OK**。細部はハンズオンで慣れましょう。

### ポイント1: `await` のあとでも、UI の更新は「メイン側」の意識で

- **内容:** 画面に関係する値（`@Published` など）は、**ユーザーが見ているスレッド（メイン）側で変える**のが基本です。今回の ViewModel は **`@MainActor`** を付けて「画面まわりはここで」とまとめます。
- **よくある落とし穴:** エラーメッセージだけ出して、**本当の原因（ログ）を残さない**。業務コードでは `print` やログだけでなく、後から調べられる形にすることが大切です。

### ポイント2: SwiftUI では「いつ読み込み開始するか」は `.task` がわかりやすい

- **内容:** 画面が表示されたタイミングでデータを取りたいとき、**`.task { await viewModel.load() }`** がよく使われます。画面を離れたあと**キャンセルしやすい**、というメリットもあります。
- **よくある落とし穴:** `.task` と `.onAppear` の両方で同じ `load()` を呼んで **二重に読み込む**。

### ポイント3: 「通信や待ち」は ViewModel、「いつ呼ぶか」は View に寄せる

- **内容:** **API 呼び出し・DB・計算のまとまり**は ViewModel のメソッドに。**画面が表示されたら読む**などのタイミングは View の `.task` に書く、という分け方が実務では多いです（チームによって多少違います）。
- **よくある落とし穴:** View に `URLSession` をそのまま書きすぎて、**あとからテストしづらくなる**。

### ポイント4: テストしやすくする「入れ替え」（プロトコル）

- **内容:** 「文字列を取ってくる役」を **プロトコル** で表し、本番は本物の API、テストでは **すぐ返すモック** に差し替えると、**待ち時間ゼロでテスト**できます。実務のコードレビューでもこの形はよく見ます。
- **よくある落とし穴:** テストが **本番のネットワークに依存** して、たまに失敗する（不安定なテスト）。

### 設計の選択肢と「なぜこの教材ではこうしたか」

- **選択:** データ取得は **ViewModel の `load()`**。取得の中身は **`MessageProviding` というプロトコル**越しに呼ぶ。
- **理由:** 業務でも「**本体は同じ・中身だけテスト用に差し替え**」ができると、バグを早く見つけやすいからです。今は名前に慣れることが目的で大丈夫です。

---

## 4. ハンズオン（手順）

**目安時間（分）: 28**

**最小成果物:** Xcode で **シミュレータ（⌘R）を押したとき**に、**くるくる（読み込み）→ 1 秒後に文字が出る**画面になること。余力があれば **テスト（⌘U）が 1 本緑**になるところまで。

**プロジェクト配置:** 日付フォルダの **`tutorial/`** は手元用（Git では無視）。Xcode ではフォルダを追加するか、グループを作ってファイルを置いてください。

**前提:** **File → New → Project → App**（SwiftUI）。外部ライブラリは使いません。iOS のバージョンは **15 以上** を目安に。

### ステップ0: プロジェクトがそのまま動くか確認

- **手順:**  
  1. 新規 App を作る（名前は例: `AsyncLesson`）。**SwiftUI** を選ぶ。  
  2. 左のファイル一覧で、追加した `.swift` を選び、右の **File Inspector** で **Target Membership** に **メインのアプリにチェック** が付いているか確認（付いていないと「型が見つからない」エラーになります）。
- **確認方法:** 何も変えず **⌘B**（ビルド）が成功する。

### ステップ1: 「文字列を取るAPI」を1ファイルに書く

- **手順:** `tutorial/Services/AsyncLessonAPI.swift` を新規作成。下のコードをコピー。
- **コード例:**

```swift
// AsyncLessonAPI.swift
import Foundation

/// テストで差し替えやすいように「役割」だけ先に書く（プロトコル）
protocol MessageProviding {
    func fetchMessage() async throws -> String
}

/// 本番っぽい「1秒待ってから返す」API
struct AsyncLessonAPI: MessageProviding {
    func fetchMessage() async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "Hello from async"
    }
}
```

- **確認方法:** **⌘B** が通る。`MessageProviding` と `AsyncLessonAPI` がどちらも同じターゲットに入っている。

### ステップ2: ViewModel に `load()` を書く

- **手順:** `tutorial/ViewModels/LessonViewModel.swift` を作成。`LessonViewModel` は画面の状態（文字・読み込み中・エラー）を持ちます。
- **コード例:**

```swift
// LessonViewModel.swift
import Combine
import Foundation
import SwiftUI

@MainActor
final class LessonViewModel: ObservableObject {
    @Published private(set) var text = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api: MessageProviding

    init(api: MessageProviding = AsyncLessonAPI()) {
        self.api = api
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            text = try await api.fetchMessage()
        } catch {
            text = ""
            errorMessage = error.localizedDescription
        }
    }
}
```

- **確認方法:** **⌘B** が通る。`defer { isLoading = false }` で **成功・失敗どちらでも** くるくるが止まることを後で実機で確認します。

### ステップ3: 画面に `.task` を付ける

- **手順:** `tutorial/Views/LessonView.swift` を作成。`ContentView` の中身を `LessonView()` に差し替えてもよいです。
- **コード例:**

```swift
// LessonView.swift
import SwiftUI

struct LessonView: View {
    @StateObject private var viewModel = LessonViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
            }
            Text(viewModel.text.isEmpty ? "—" : viewModel.text)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    LessonView()
}
```

- **確認方法:** **⌘R** で実行。**約1秒後に `Hello from async`**。その間は `ProgressView`。

### ステップ4: `Task { }` で同じことを試す（比較・任意）

- **手順:** `.task` をいったんコメントアウトして、次を試す。

```swift
.onAppear {
    Task {
        await viewModel.load()
    }
}
```

- **確認方法:** 表示は似た動きになることが多いです。業務では **`.task` の方がキャンセルと相性がよい**ことが多い、と覚えておけば十分です。試したら **`.task` に戻す**。

### ステップ5: テストを1本（余力・または翌日でもOK）

- **手順（ざっくり）:**  
  1. **File → New → Target → Unit Testing Bundle** を追加。  
  2. テストターゲットの **Host Application** に、この **iOS アプリ** を指定（詰まったら Xcode のヘルプやチームのテンプレを参照）。  
  3. 下のコードで **[Swift Testing](https://developer.apple.com/documentation/testing)**（`import Testing`）を使い、**`mock-ok`** が表示用の `text` に入るか確認。**XCTest は使わない。**  
  4. `@testable import` の **`AsyncLesson`** の部分は、自分の **プロジェクト名** に合わせる（左のプロジェクトを選び、**Build Settings → Product Module Name** を見る。多くはプロジェクト名と同じ）。

```swift
// LessonViewModelTests.swift
import Testing
@testable import AsyncLesson // ← 自分のモジュール名に変更

private struct MockMessageAPI: MessageProviding {
    func fetchMessage() async throws -> String {
        "mock-ok"
    }
}

@Suite("LessonViewModel")
struct LessonViewModelTests {
    @MainActor
    @Test func loadSuccessSetsTextFromAPI() async {
        let vm = LessonViewModel(api: MockMessageAPI())
        #expect(vm.text == "")
        await vm.load()
        #expect(vm.isLoading == false)
        #expect(vm.text == "mock-ok")
        #expect(vm.errorMessage == nil)
    }
}
```

- **確認方法:** **⌘U** で緑。ここで詰まったら **ステップ1〜3だけ完了**でも今日のゴールは達成です。

### ステップ6: 4月アプリ候補の絞り込み（ワーク）

- **手順:** メモに候補を書き、次の **3 つ** で 1〜5 点ずつつけ、合計が高い **1〜2 個** に絞る。  
  - **学びになるか**  
  - **期限内に形にできそうか**  
  - **続けて作りたいか**  
- **確認方法:** 「4月に手を付けるアプリ」が **1 つ決まった**（または候補 **2 つまで**）なら OK。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）: 5（任意）**

### Easy

- **内容:** 待ち時間を **0.2 秒** に変えて、くるくるの見え方を比較する。  
- **回答:** `nanoseconds` を `200_000_000` にする。

**実装例（`AsyncLessonAPI.swift` の `fetchMessage()` だけ差し替え）:**

```swift
func fetchMessage() async throws -> String {
    try await Task.sleep(nanoseconds: 200_000_000) // 0.2 秒
    return "Hello from async"
}
```

### Medium

- **内容:** `load()` を **ボタン押下** で呼ぶ画面に変える（`Button` の中は `Task { await viewModel.load() }`）。  
- **回答:** 読み込み中は `Button` を `disabled(isLoading)` にすると実務っぽいです。

**実装例（`LessonView.swift` をボタン起動にした全体イメージ）:**

```swift
struct LessonView: View {
    @StateObject private var viewModel = LessonViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
            }
            Text(viewModel.text.isEmpty ? "—" : viewModel.text)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button("読み込む") {
                Task {
                    await viewModel.load()
                }
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
}
```

※ 自動読み込みはやめるので、**`.task { await viewModel.load() }` は付けない**（付けると起動時にも走る）。

### Hard

- **内容:** `MockMessageAPI` で **エラーを投げる** バージョンを作り、`errorMessage` が出るか確認する。  
- **回答:** `throw NSError(domain: "test", code: 1)` などで OK。テストでは `#expect(vm.errorMessage != nil)`（Swift Testing）。

**実装例（テストファイルに追加するモック + テスト）:**

```swift
private struct MockMessageAPIFailing: MessageProviding {
    func fetchMessage() async throws -> String {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "mock failure"])
    }
}

// 既存の @Suite 内、または別 @Test で:
@MainActor
@Test func loadFailureSetsErrorMessage() async {
    let vm = LessonViewModel(api: MockMessageAPIFailing())
    await vm.load()
    #expect(vm.errorMessage != nil)
    #expect(vm.text.isEmpty)
}
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）: 4**

1. **一覧を開いたときに取得:** いまの **`.task { await viewModel.load() }`** と同じ発想で、リスト画面の `onAppear` 相当に **初回だけ API** を呼ぶことが多いです。本番では **`URLSession.shared.data(for:)`** の `async` 版などと組み合わせます。
2. **保存ボタン:** `Button` の中は同期なので、`Task { await viewModel.save() }`。**送信中はボタンを押せない**（`isSaving` で `disabled`）にすると、二重送信を防げます。
3. **プルで更新:** `List` に **`.refreshable { await viewModel.reload() }`**（iOS 15+）を付けるパターンが定番です。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）: 3**

- **`await` は「終わりを待つ」**。画面のタイミングでは **`.task`** が覚えやすい。  
- **通信や待ちの中身は ViewModel** にまとめると、あとから読みやすい（実務でもこの形が多い）。  
- **テストでは本物の代わりにモック**を差し込むと、速くて安定する（名前は慣れで大丈夫）。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）: 1**

1. **`throws` と `do/catch` をもう少し丁寧に**（業務のエラー表示・ログの出し方）  
2. **`URLSession` で実際に API を叩く**（`async` とセットで覚える）

---

## 補足: ファイル一覧と実行方法

| ファイル（想定パス） | 役割 |
|---------------------|------|
| `tutorial/Services/AsyncLessonAPI.swift` | プロトコル + 本番用の待ち |
| `tutorial/ViewModels/LessonViewModel.swift` | 画面の状態と `load()` |
| `tutorial/Views/LessonView.swift` | 表示と `.task` |
| `AsyncLessonTests/LessonViewModelTests.swift` | モックのテスト（任意） |

**実行:** **⌘R**（アプリ）、**⌘U**（テスト）。  
**Git:** `tutorial/` は **`.gitignore` で除外** 想定のため、手元の練習用として使ってください。

**よくあるつまずき:**  
- `ObservableObject` / `@Published` で Combine まわりのエラー → **`import Combine`** をファイル先頭に追加（`ObservableObject` と `@Published` は Combine の型）。  
- `Cannot find type` → **Target Membership** のチェック。  
- `No such module` → **`@testable import` の名前**をモジュール名に合わせる。
