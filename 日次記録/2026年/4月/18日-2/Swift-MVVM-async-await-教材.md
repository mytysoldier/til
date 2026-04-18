# Swift: MVVM と async/await の入口（1日分）

公式ドキュメントの参照先（必要に応じて併読）:

- [Concurrency（Swift）](https://developer.apple.com/documentation/swift/concurrency) — `Task` / `async` / `await` の全体像
- [Observation](https://developer.apple.com/documentation/Observation) — `@Observable` と変更追跡
- [Migrating from the Observable Object protocol to the Observable macro](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro) — SwiftUI での移行の考え方
- [Testing](https://developer.apple.com/documentation/testing) — Swift Testing（`@Test` / `#expect` / `@Suite`）

---

## 1. 今日のゴール（1〜2行）

**目安時間（分）:** 1

**SwiftUI で「View は薄く・状態と非同期は ViewModel」という最小 MVVM を組み、`async/await` で状態が更新される流れを一度通す。**

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間（分）:** 2

次の 3 問に頭の中で答え、すぐ下の「解答」を見て穴だけ埋める。

**Q1.** `async` 関数を View の `body` から直接 `await` 呼び出しできますか？

**Q2.** SwiftUI で「画面の状態」を表すプロパティを、原則どこに置くと責務が分かりやすいですか？（今日のテーマに沿った答えで OK）

**Q3.** `ObservableObject` と `@Observable` のうち、プロパティ変更のたびに「View が読んだプロパティだけ」追跡しやすいのはどちらの系統ですか？（現行の推奨に近い方）

### 解答

**A1.** **できません。** `body` は同期の宣言的 UI なので、非同期処理は `Task { }` や `.task` など別の入口から起動します（詳細は理論・ハンズオン）。

**A2.** **ViewModel（または同等の「UI 状態をまとめる型」）** に置き、View は表示とユーザー操作の橋渡しに寄せる、が今日の整理の仕方です。

**A3.** **`@Observable`（Observation）** の方が、SwiftUI との組み合わせで細かい更新に寄せやすいです。旧来の `ObservableObject` + `@Published` も有効ですが、新規学習なら `@Observable` を優先するのが無難です。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間（分）:** 9

### 重要ポイント 1: MVVM で「薄くする」のは View

- **要点:** View はレイアウト・ナビゲーション・ユーザー操作の入口。**表示に必要な状態の「出どころ」**は ViewModel 側に寄せると、読み手が追いやすい。
- **よくある誤解:** 「ViewModel があれば全部正しい」ではない。**状態が増えたら ViewModel に逃がす**、が最初の一歩。

### 重要ポイント 2: `async/await` は「別の入口」から起動する

- **要点:** SwiftUI の `body` は `async` にできない。**`Task { await ... }`** や **`.task { await ... }`** など、Swift が用意する非同期の入口から `await` する。
- **よくある落とし穴:** `onAppear` で `Task` を無制限に増やすとキャンセル設計が難しくなる。今日は **`.task`** を使い「画面ライフサイクルに紐づく」形にする。

### 重要ポイント 3: UI 状態の更新は `MainActor` を意識する

- **要点:** SwiftUI の UI 更新は主にメインスレッド（厳密には **MainActor**）。ViewModel を **`@MainActor`** にすると、状態プロパティの更新が UI と整合しやすい。
- **よくある誤解:** 「`await` したら自動でメインに戻る」と思い込む。**戻り先はコンテキスト依存**なので、UI 状態を触る型は `@MainActor` で区切るのが安全。

### 重要ポイント 4: キャンセルとエラーは「握りつぶし方」に注意（実務の入口）

- **要点:** `.task` 内の `await` は、画面を離れると **タスクがキャンセル**され、`Task.sleep` などは **`CancellationError`** を投げうる。実務では **キャンセルは正常系**として扱い、**ネットワーク失敗などと分ける**ことが多い。
- **よくある落とし穴:** `try?` で全部を無視すると、**本当の失敗かキャンセルか**がログにも残らない。今日のサンプルは短さ優先で `try?` を使うが、本番では `do/catch` で `CancellationError` だけ別扱い、が定番。

### 重要ポイント 5: `@Observable` と `@State` の役割分担

- **要点:** ViewModel クラスは `@Observable`。SwiftUI は **`body` が読んだプロパティ**に絡む更新に寄せやすく、古い `ObservableObject` + 丸ごと `@Published` より無駄な再描画が減りやすい、というイメージ（公式の移行ドキュメントの趣旨）。**View 側では** `@State private var viewModel = GreetingViewModel()` のように **インスタンスの保持**に `@State` を使う（SwiftUI が View の寿命に紐づけて保持するため）。「モデルが Observable なのに何で State？」と混乱しがちだが、**ここは別レイヤの話**。
- **よくある落とし穴:** `let viewModel = ...` にすると再描画で作り直されることがあり、意図しない再ロードの原因になる。

### 重要ポイント 6: 今日の比較観点は 1 つだけ — 「状態の出どころ」

- **要点:** **「この画面の“真実”はどこ？」** を決める。View に散らすと動くが、非同期が増えると追えなくなる。
- **設計の選択肢と、今日の選び方（1 つ）**
  - **選択肢 A:** 状態を View の `@State` に置く（小さい画面では速い）。
  - **選択肢 B:** 状態を ViewModel に置く（非同期・分岐が増えるほど有利）。
  - **今日は B を選ぶ理由:** **async で状態が変わる**なら、更新ロジックを View から切り離した方が、あとからテストもしやすい。

---

## 4. ハンズオン（手順）

**目安時間（分）:** 41

**最小成果物:** `tutorial` 配下に SwiftUI アプリプロジェクトを作り、**挨拶文を非同期取得する画面**が動く。View は表示と `.task` だけ、ロジックは ViewModel。

**前提:** macOS に Xcode をインストール済み。デプロイは **iOS 17 以上**（`@Observable` を使うため）。初回は Xcode のダウンロードやシミュレータ初回起動で **目安を超える**ことがあるので、その分は別日に回してもよい。

### 準備: `tutorial` フォルダと `.gitignore`

1. 教材 Markdown と同じ階層に **`tutorial` フォルダを作成**する（中身はまだ空でよい）。
2. Git で管理する場合は **`.gitignore` に `tutorial/` を追加**し、ハンズオン生成物をコミット対象外にする（この教材フォルダにはサンプルとして置いてある場合もある）。

**確認方法:** Finder で `tutorial` が存在し、必要なら `.gitignore` に `tutorial/` が含まれる。

---

### ステップ 1: Xcode でプロジェクトを `tutorial` 以下に作る

1. Xcode を起動 → **File → New → Project…**
2. **iOS → App** を選ぶ。
3. プロダクト名例: **`MVVMMini`**。Interface: **SwiftUI**。Language: **Swift**。
4. 保存場所を **教材フォルダ直下の `tutorial/`** に指定して作成（パスは環境ごとに違ってよい）。

**確認方法:** `tutorial/MVVMMini/` に `.xcodeproj` があり、シミュレータで空のアプリが起動する。

---

### ステップ 2: デプロイターゲットを iOS 17 以上にする

1. Xcode 左のプロジェクトナビゲータで **プロジェクト名（青いアイコン）** をクリック。
2. **TARGETS** から **`MVVMMini`**（アプリ本体）を選択 → **General**。
3. **Minimum Deployments → iOS** を **17.0** 以上にする（デフォルトが 17 未満の場合がある）。

**確認方法:** General に **iOS 17.0**（以上）と表示される。ここが低いと `@Observable` でビルドエラーになる。

---

### ステップ 3: ViewModel ファイルを追加する（状態の出どころ）

1. プロジェクトに **Swift File** を追加し、名前を **`GreetingViewModel.swift`** とする。
2. 追加ダイアログで **Target Membership** の **`MVVMMini` にチェック**が入っていることを確認（外れるとビルドに含まれない）。
3. 次のコードを置く（**ファイル名: `GreetingViewModel.swift`**）。

```swift
import Foundation
import Observation

@Observable
@MainActor
final class GreetingViewModel {
    private(set) var message: String = "…"
    private(set) var isLoading: Bool = false

    /// 実務では URLSession などに置き換える。今日は遅延だけの疑似 API。
    func loadGreeting() async {
        isLoading = true
        defer { isLoading = false }

        // 疑似ネットワーク遅延（2 秒）。短くしたい場合は .seconds(1) でもよい。
        try? await Task.sleep(for: .seconds(2))
        message = "こんにちは、MVVM + async/await"
    }
}
```

**確認方法:** プロダクト **⌘B** でビルドが通る。`Cannot find type` や `Observable` 関連エラーなら、ステップ 2 の iOS 17 と `import Observation` を確認。

---

### ステップ 4: View を薄くする（表示と `.task` のみ）

1. **`ContentView.swift`** を次のようにする（既存の `ContentView` を置き換え）。

```swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel = GreetingViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
            }
            Text(viewModel.message)
                .font(.title2)
        }
        .padding()
        .task {
            await viewModel.loadGreeting()
        }
    }
}
```

**確認方法:** **⌘R** でシミュレータ起動。最初は `…` とローディング → 約 2 秒後に「こんにちは、MVVM + async/await」に変わる。

**なぜ `.task` か（一言）:** 画面が表示されている間の非同期に紐づけやすく、ビューが消えたときの **キャンセル**とも相性がよい。

**なぜ `viewModel` を `@State` に置くか（一言）:** View が **ViewModel インスタンスの所有者**になり、再描画のたびに `GreetingViewModel()` を作り直さないため。

---

### ステップ 5: エントリ（`App`）が `ContentView` を表示していることを確認

1. **`MVVMMiniApp.swift`**（プロジェクト名に応じてファイル名は異なる場合あり）で、`WindowGroup` が `ContentView()` を呼んでいることを確認。なければ修正。

```swift
import SwiftUI

@main
struct MVVMMiniApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**確認方法:** 再ビルド・実行して、ステップ 4 と同じ挙動。

---

### ステップ 6: テスト 1 本（ViewModel のみ・Swift Testing）

**前提:** **Xcode 16 以降**（**Swift Testing** がテストターゲットで標準利用可能な環境）。古い Xcode の場合は XCTest で同じ検証を書くか、Xcode を上げてからこのステップに進む。

1. メニュー **File → New → Target…** → **Unit Testing Bundle** → 名前例 **`MVVMMiniTests`** → Finish。
2. 左のナビゲータで **`MVVMMiniTests`** フォルダを選び、既存のテストファイルがあれば中身を置き換え、なければ **File → New → File… → Swift File** で **`GreetingViewModelTests.swift`** を追加（テンプレートに **Test** 系があればそれでも可）。**Target Membership** で **`MVVMMiniTests`** にチェック。
3. **プロジェクト設定 → TARGETS → `MVVMMini` → Build Settings** で **Enable Testability** が **Yes**（Debug）になっていることを確認（通常、テストターゲット追加時に有効になる）。
4. 次のコードを置く（**ファイル名例: `GreetingViewModelTests.swift`**）。

```swift
import Testing
@testable import MVVMMini

@Suite("GreetingViewModel")
struct GreetingViewModelTests {
    @Test
    @MainActor
    func loadGreeting_updatesMessage() async {
        let vm = GreetingViewModel()
        #expect(vm.message == "…")
        #expect(!vm.isLoading)

        await vm.loadGreeting()

        #expect(vm.message == "こんにちは、MVVM + async/await")
        #expect(!vm.isLoading)
    }
}
```

5. **`@testable import MVVMMini`** の `MVVMMini` は、アプリターゲットの **Product Module Name** と一致させる。確認手順: **TARGETS → MVVMMini → Build Settings** で **Product Module Name** を検索（未設定なら **Product Name** と同じことが多い）。

**確認方法:** テストナビゲータ（⌘6）で **`GreetingViewModel`** スイート（または **`loadGreeting_updatesMessage`**）を実行し、成功する。

**よくあるビルドエラー:** `No such module 'MVVMMini'` → Product Module Name と `import` の名前を揃える。**テストが真っ赤** → 左パネルで **MVVMMiniTests** ターゲットにテストファイルの **Target Membership** チェックがあるか確認。**`No such module 'Testing'`** → Xcode 16 未満の可能性あり。プロジェクトの **Swift Tools Version** と Xcode を確認。

---

**ここまでできれば今日のゴール達成** — SwiftUI で ViewModel に状態と `async` ロジックを置き、`.task` で `await` し、ViewModel に対する **Swift Testing** のテストが 1 本通る最小構成が完成。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）:** 任意（本文は読むだけ。実施は Easy 5〜10 分〜）

### Easy（5〜10 分）

**課題:** `loadGreeting()` のメッセージを **引数で変えられる**ようにし、画面に「再読み込み」ボタンを置く（View は `Button` と `viewModel` 呼び出しのみ）。

**回答例:**

```swift
// GreetingViewModel.swift のイメージ
func loadGreeting(prefix: String = "こんにちは") async {
    isLoading = true
    defer { isLoading = false }
    try? await Task.sleep(for: .seconds(1))
    message = "\(prefix)、MVVM + async/await"
}
```

```swift
// ContentView.swift にボタンを追加
Button("再読み込み") {
    Task { await viewModel.loadGreeting(prefix: "やあ") }
}
```

### Medium

**課題:** `loadGreeting()` を **失敗しうる** API に見立て、`throws` + `Result` または `errorMessage: String?` を ViewModel に持たせ、View はエラー表示だけ行う。

**回答例（要点）:**

```swift
enum GreetingError: Error { case network }

@Observable @MainActor
final class GreetingViewModel {
    private(set) var message: String = "…"
    private(set) var errorMessage: String?

    func loadGreeting() async {
        errorMessage = nil
        do {
            try await Task.sleep(for: .seconds(1))
            throw GreetingError.network // 疑似失敗
        } catch is CancellationError {
            // 画面離脱など。必要ならログのみ
        } catch {
            errorMessage = "読み込みに失敗しました"
        }
    }
}
```

### Hard

**課題:** `.task` に代わり **`task(id:)`** で「ユーザー ID が変わったら再取得」するパターンを試す（キャンセルと再実行の体感）。

**回答例（イメージ）:**

```swift
@State private var userID = 1
@State private var viewModel = GreetingViewModel()

var body: some View {
    VStack {
        Text(viewModel.message)
        Button("別ユーザー") { userID += 1 }
    }
    .task(id: userID) {
        await viewModel.loadGreeting()
    }
}
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）:** 4

1. **EC の注文一覧:** 画面表示と同時に `GET /orders` を `async` で叩き、ViewModel が `orders` / `isLoading` / `lastError` を保持。View は `List`・プルリフレッシュ・再試行ボタンだけ。同じ `loadOrders()` を **初回と更新**の両方から呼ぶと責務が揃う。
2. **社内アプリの承認フロー:** 「承認」「差し戻し」ボタンは View に置き、**可否や送信中フラグ**は ViewModel。`approve()` が `async` で API を叩き、成功後にだけローカル状態を差し替えると、**二重タップや状態の食い違い**を防ぎやすい。
3. **設定画面の保存:** `TextField` の下書きは `@Bindable` などでつなぎつつ、**確定ボタン**で呼ぶ `saveSettings()` を ViewModel に閉じる。オフライン時は `errorMessage` を出し、**再送はユーザー操作に紐づける**（バックグラウンドの自動リトライは別設計になる、という切り分けがしやすい）。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）:** 2

- View は薄く、**変化する状態と非同期の手順は ViewModel** に寄せると、読み手が「状態の出どころ」を追いやすい。
- **`body` からは直接 `await` せず**、`.task` / `Task` など Swift が用意する入口から `async` 関数を呼ぶ。**キャンセル**は失敗と混ぜない、が実務の入口。
- **`@MainActor` + `@Observable`** で UI に触れる状態更新を区切り、View 側は **`@State` で ViewModel を保持**する、という組み合わせが現行 SwiftUI で扱いやすい。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）:** 1

1. **`@Bindable` とフォーム** — `TextField` など双方向バインディングを ViewModel とどう接続するか（Observation 前提）。
2. **`actor` / リポジトリ層** — ネットワークや DB を ViewModel から一段離し、**データ取得の責務**を分ける入門。

---

### 時間の目安 合計

| セクション           | 分   |
|----------------------|------|
| 1. 今日のゴール      | 1    |
| 2. 事前知識チェック  | 2    |
| 3. 理論              | 9    |
| 4. ハンズオン        | 41   |
| 6. 実務での使いどころ | 4    |
| 7. まとめ            | 2    |
| 8. 明日の布石        | 1    |
| **合計**             | **60** |

（追加課題は任意のため合計に含めていません。）
