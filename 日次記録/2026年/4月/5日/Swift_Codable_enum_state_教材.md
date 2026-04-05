# Swift: Codable / enum state / モデル境界（1日教材）

---

## 1. 今日のゴール

**目安時間（分）: 1**

次を満たす **1本道の成果物** を `tutorial` 配下の Xcode プロジェクトで完成させる: 固定 JSON を `UserDTO` にデコードする → 結果を `UserListState`（enum）に載せる → SwiftUI で1画面表示する → **単体テスト1件** でデコード〜状態が期待どおりであることを検証する。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間（分）: 3**

**Q1. `Codable` は何の略で、何のためにあるか。**  
**A.** `Codable` は `Encodable` と `Decodable` の合成で、JSON などの外部表現と Swift の型の相互変換（シリアライズ／デシリアライズ）のためにある。

**Q2. `enum` に連想値（associated value）を付けると、画面状態の表現で何が嬉しいか。**  
**A.** 「ロード中にデータが入っている」など **ありえない組み合わせ** を型から排除し、`switch` で状態分岐を網羅しやすくなる。

**Q3. 「DTO」と「View の状態」を混ぜると何が困るか。**  
**A.** 表示用のフラグやローディングがドメイン／API の形に引きずられ、再描画・テスト・変更のたびに全体が壊れやすくなる。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間（分）: 17**

### ポイント1: `Codable` は「境界越えのための型」

- API の JSON とアプリ内表現をつなぐ。プロパティ名やネストは **ワイヤ上の形** に合わせる（`CodingKeys` でリネーム）。
- **よくある誤解/落とし穴:** 「全部 `Codable` にすれば設計がきれい」は誤り。UI 専用の状態まで `Codable` にすると、保存形式と画面の都合が固結びする。

### ポイント2: DTO（Data Transfer Object）は「受け渡し用のスナップショット」

- サーバが返すフィールドをそのまま（またはほぼそのまま）表現する。オプショナルや `[String: JSONValue]` のような逃げは最小限に。
- **よくある誤解/落とし穴:** DTO をそのまま `View` に渡して「とりあえず表示」。後から `isLoading` や `errorMessage` を DTO に足すと、境界が曖昧になる。

### ポイント3: 画面状態は `enum` で「ありうる状態」を列挙する

- 例: `.idle` / `.loading` / `.loaded([Item])` / `.failed(表示用メッセージ)`。分岐は `switch` で網羅。
- **よくある誤解/落とし穴:** `Bool` の `isLoading` と `error` を別々に持つと、`loading && error != nil` のような **不整合な組み合わせ** が表現できてしまう。

### ポイント4: DTO → ドメイン／表示用モデルへの変換は明示的に

- `init(dto:)` や `func toDomain() -> User` のように **変換点を1か所** に寄せると、テストしやすい。
- **よくある誤解/落とし穴:** 変換なしで DTO を ViewModel に流し、画面だけのデフォルト値を各所に散らす。

### ポイント5: モデル境界を意識する（レイヤごとの「所有」）

- **Network 層:** DTO + `Codable`。  
- **Feature / UI 層:** `ScreenState` のような enum、表示用の値オブジェクト。
- **よくある誤解/落とし穴:** 「同じデータだから1つの struct で済む」。実際は **ライフサイクルと変更理由** が違う。

### ポイント6: 非同期・エラー・テストでの落とし穴（実務で頻出）

- **非同期:** `Task` / `URLSession` の完了ハンドラで `UserListState` を更新するとき、**UI 更新は `@MainActor`** に寄せないと、表示がちらついたりクラッシュの原因になる（本日の同期デコードでは省略可だが、次のステップの前提になる）。
- **エラー:** `error.localizedDescription` をそのままユーザー向け文言にすると、OS やロケールで文言が変わり、**想定したエラー分岐テストが不安定** になりやすい。ハンズオンでは簡略のため `String` で持つが、実務では `AppError` やコード値にマップすることが多い。
- **型:** `enum` の `.failed` に `Error` をそのまま載せると `Equatable` 実装が面倒になることがある。**表示用の `String` や独自のエラーID** に落とす選択がよく使われる。
- **テスト:** UI の有無に依存せず、**JSON 文字列 → `UserListState` の純粋関数** をテストすると、壊れにくい（本ハンズオンの方針）。

### 設計の選択肢と、なぜこの選択にしたか（1つ）

- **選択:** DTO と UI state を **別型** にし、まずは「デコード結果を enum に載せる」までを **同期の純粋関数** で切り出す。  
- **理由:** API の形と画面の状態遷移を分離できるうえ、**単体テストで再現性の高い検証** がしやすい。非同期を足すときも、この関数の上に `Task` を載せればよい。

---

## 4. ハンズオン（手順）

**目安時間（分）: 31**

**推奨スタック（60分で迷子になりにくい）:** **iOS App + SwiftUI + Swift Testing**（`import Testing`、Xcode 16 以降。Command Line Tool はテスト設定がやや込み入るため、本教材では非推奨）。

**最小成果物:** 下記 **固定 JSON** をデコードし、`UserListState` が `.loaded` になること。`ContentView` で一覧テキストが見えること。テストターゲットで **同じ JSON** を使い **`#expect` が成功** すること。

**実行環境:** macOS、Xcode、iOS Simulator 利用可能なこと。

---

### ステップ1: プロジェクトと `tutorial` の準備

1. 日付フォルダ直下に `tutorial` フォルダがあることを確認（なければ作成）。  
2. 同階層の `.gitignore` に `tutorial/` があり、Xcode の生成物をコミットしないことを確認。  
3. Xcode → **File → New → Project** → **App** → Interface: **SwiftUI**、Language: **Swift**、Storage: **None** でよい。  
4. 保存先を **`…/5日/tutorial/CodableStateDemo`** のように **`tutorial` 配下** にする（プロジェクト名 `CodableStateDemo` を推奨。以降この名前で説明）。  
5. 作成後、**⌘B** でビルド。シミュレータを選び **⌘R** で起動し、デフォルトの「Hello」画面が出ればよい。

**確認方法（期待される出力/挙動）:** ビルド成功。Simulator でアプリが起動する。

**迷いやすい点:** ファイルを追加したあと **Target Membership**（File Inspector）で **アプリターゲットにチェック** が入っているか。外れていると `Cannot find type` になる。

---

### ステップ2: API 用 DTO（`Codable`）と「契約 JSON」を固定する

1. **File → New → File → Swift File** で `UserDTO.swift` を追加（ターゲットはアプリにチェック）。  
2. 次の **フィールド名どおり** に `struct` を定義する（**この教材の JSON と一致させることが重要**）。

```swift
// UserDTO.swift
import Foundation

struct UserDTO: Codable, Equatable {
    let id: Int
    let name: String
    let email: String
}
```

3. 以降のステップで使う **固定 JSON（配列）** をメモする。コピー用:

```text
[{"id":1,"name":"Alice","email":"alice@example.com"},{"id":2,"name":"Bob","email":"bob@example.com"}]
```

**確認方法:** ビルド成功。`UserDTO` がプロジェクトナビゲータに見える。

---

### ステップ3: 画面状態を `enum` で定義

1. `UserListState.swift` を追加（アプリターゲットに含める）。  
2. 次をそのまま定義する。

```swift
// UserListState.swift
import Foundation

enum UserListState: Equatable {
    case idle
    case loading
    case loaded(users: [UserDTO])
    case failed(message: String)
}
```

**確認方法:** どこかで `let s: UserListState = .loaded(users: [])` と書いてビルドが通ること。

**落とし穴:** `[UserDTO]` を載せるため **`UserDTO` は `Equatable` が必要**（すでに付与済み）。

---

### ステップ4: JSON → 状態へ（純粋関数）と SwiftUI 表示

1. `UserListState+Decode.swift`（名前任意）を追加し、**画面と独立** した関数を置く。

```swift
// UserListState+Decode.swift
import Foundation

enum UserListDecoder {
    static func state(from json: String) -> UserListState {
        let data = Data(json.utf8)
        do {
            let users = try JSONDecoder().decode([UserDTO].self, from: data)
            return .loaded(users: users)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }
}
```

2. `ContentView.swift` を次のように置き換える（`import SwiftUI` は既存どおり）。

```swift
import SwiftUI

struct ContentView: View {
    private let sampleJSON =
        #"[{"id":1,"name":"Alice","email":"alice@example.com"},{"id":2,"name":"Bob","email":"bob@example.com"}]"#

    @State private var state: UserListState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            switch state {
            case .idle, .loading:
                Text("Tap button to load")
            case .loaded(let users):
                ForEach(users, id: \.id) { u in
                    Text("\(u.name) <\(u.email)>")
                }
            case .failed(let message):
                Text(message).foregroundStyle(.red)
            }
            Button("Load JSON") {
                state = UserListDecoder.state(from: sampleJSON)
            }
        }
        .padding()
    }

    private var title: String {
        switch state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .loaded: return "loaded"
        case .failed: return "failed"
        }
    }
}

#Preview {
    ContentView()
}
```

**確認方法:** 実行し **Load JSON** をタップ → Alice / Bob の2行が表示される。意図的に `sampleJSON` を `"["` だけに壊すと赤文字でエラー表示になる。

**落とし穴:** `ForEach(users, id: \.id)` は `UserDTO` が `Identifiable` でないため **`id:` を必ず指定** する（または DTO に `Identifiable` を足す）。

---

### ステップ5: テスト1件（Swift Testing）

**前提:** Xcode 16 以降（Swift Testing は標準ライブラリ／Xcode 同梱のテストフレームワーク。XCTest は使わない）。

1. まだなら **File → New → Target → Unit Testing Bundle** で `CodableStateDemoTests` を追加。  
2. ウィザードに **Testing System** の選択がある場合は **Swift Testing** を選ぶ。既存ターゲットだけの場合は、次の手順のとおり **`import Testing`** のファイルを追加すればよい。  
3. **Host Application** は通常どおりアプリを選ぶ（UI テストではない）。  
4. テストファイルで **`@testable import CodableStateDemo`** を使う（プロダクト名が異なれば合わせる）。  
5. 次を **そのまま** 追加する（JSON はステップ2と同一）。`UserDTO` と `UserListState` が `Equatable` なので、期待値を組み立てて **`#expect` 1本** で比較できる。

```swift
import Testing
@testable import CodableStateDemo

@Suite
struct UserListDecoderTests {
    @Test
    func decodeSampleJSONReturnsLoadedWithTwoUsers() {
        let json =
            #"[{"id":1,"name":"Alice","email":"alice@example.com"},{"id":2,"name":"Bob","email":"bob@example.com"}]"#

        let state = UserListDecoder.state(from: json)

        let expectedUsers: [UserDTO] = [
            UserDTO(id: 1, name: "Alice", email: "alice@example.com"),
            UserDTO(id: 2, name: "Bob", email: "bob@example.com"),
        ]
        #expect(state == .loaded(users: expectedUsers))
    }
}
```

6. テスト対象の Swift ファイル（`UserDTO`, `UserListState`, `UserListDecoder`）は **アプリターゲットにだけ含め**、`@testable import` でテストから読む（ファイルをテストターゲットに二重登録しない）。

**確認方法:** **⌘U**（または Test Navigator から実行）でテストが成功する。失敗時は「テストターゲットの Deployment Target がアプリと合っているか」「`@testable import` のモジュール名」「Xcode のバージョン」を確認。

**最低1つのテストとして妥当な理由:** ワイヤ形式（JSON）と `UserListState` の対応が **回帰テスト** され、リファクタ時も境界が壊れにくい。Swift Testing でも **純粋関数＋`#expect`** の方針は同じ。

---

### ファイル配置の目安

| ファイル | 役割 |
|---------|------|
| `UserDTO.swift` | `Codable` DTO |
| `UserListState.swift` | UI 状態 enum |
| `UserListState+Decode.swift` | 純粋関数 `UserListDecoder.state` |
| `ContentView.swift` | `@State` と表示 |
| `CodableStateDemoTests/...swift` | Swift Testing（`@Test` / `#expect`） |

**アプリの実行:** Simulator 選択 → **⌘R**。**テスト:** **⌘U**。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）: 余剰（Easy 10 / Medium 15 / Hard 20）**

### Easy

DTO と別に `struct User: Equatable { let displayName: String }` を定義し、`UserDTO` から `User` に変換する `extension UserDTO { func toDisplay() -> User }` を書く。

**回答コード例:**

```swift
struct User: Equatable {
    let displayName: String
}

extension UserDTO {
    func toDisplay() -> User {
        User(displayName: name)
    }
}
```

### Medium

`UserListState` の `.loaded` が `[UserDTO]` ではなく `[User]` を持つようにし、デコード直後に `map(\.toDisplay())` で変換する。

**回答コード例:**

```swift
enum UserListState: Equatable {
    case idle
    case loading
    case loaded(users: [User])
    case failed(message: String)
}

enum UserListDecoder {
    static func state(from json: String) -> UserListState {
        let data = Data(json.utf8)
        do {
            let dtos = try JSONDecoder().decode([UserDTO].self, from: data)
            return .loaded(users: dtos.map { $0.toDisplay() })
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }
}
```

### Hard

`CodingKeys` で JSON のキーが `user_name` のときに `name` にマッピングする。加えて、一部フィールド欠損時に `decodeIfPresent` でフォールバックする。

**回答コード例:**

```swift
struct UserDTO: Codable, Equatable {
    let id: Int
    let name: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case name = "user_name"
        case email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
    }
}
```

（`Encodable` が必要な API では `encode(to:)` も実装する。）

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）: 5**

1. **コードレビュー:** PR で「この `struct` は DTO か UI か？」と聞けるようにする。`Codable` はネットワーク層に閉じ、View に渡す直前で `enum` やドメインモデルに載せ替えているかを確認する。  
2. **一覧＋ページング:** `ListState` を `.loadingMore` と `.loaded(hasMore:)` まで分け、**二重リクエスト**や「ロード中にエラーとデータが同時に存在」を防ぐ（enum のケース設計がそのままバグ予防になる）。  
3. **オフラインキャッシュと再表示:** UserDefaults／ファイルに保存するのは **DTO またはドメインのスナップショット** に限定し、画面の「今は編集中か／同期失敗か」は **別の state** で持つ。復元時も「キャッシュ読み → state 組み立て」を関数化し、**テストで再現** する。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）: 2**

- `Codable` はワイヤ形式に寄せた **DTO** に使い、画面の「今どの状態か」は **enum** で表すと不整合が減る。  
- DTO と UI state を分け、**JSON → state** を純粋関数にすると、非同期を足す前から **テストで境界を固定** できる。  
- 非同期・エラー表示・`Equatable` は実務でつまずきやすいので、**次の学習テーマの布石** として意識しておく。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）: 1**

1. **Swift: `@MainActor` と async/await での状態更新** — `UserListDecoder` を `async` 化し、`Task { @MainActor in … }` で `state` を更新するパターンと競合の扱い。  
2. **Swift: `Result` / 型安全な `AppError`** — `.failed` を `String` から、コードとユーザー向け文言に分離し、テストでアサートしやすくする。

---

## 補足: 外部ライブラリ

原則 **標準の `Codable` と Swift Testing（`Testing`）のみ** で完結させる。HTTP クライアントは本日の焦点（型と境界）から外れるため使わない。

---

## このフォルダで用意したもの

- `tutorial/` … ハンズオン用（`.gitignore` でリポジトリから除外）
- `.gitignore` … `tutorial/` を除外
