# Swift Codable 1日分学習教材

**合計目安: 60分**（理論15分 + ハンズオン28分 + その他17分）※Architecture 補習はオプション

## 1. 今日のゴール（目安: 2分）

**struct と enum を使って JSON をデコードできるようになる。**  
Codable の仕組みを理解し、実務でよくある落とし穴を避けられるようになる。  
（オプション）**DTO と Domain を分け、Mapper で変換する**考え方に触れる。

---

## 2. 事前知識チェック（目安: 5分）

### Q1. `Codable` は何の型エイリアスか？
<details>
<summary>回答</summary>

`Codable` は `Encodable` と `Decodable` の型エイリアスである。

```swift
typealias Codable = Encodable & Decodable
```

</details>

### Q2. JSON のキー名と Swift のプロパティ名が異なる場合、どう対応するか？
<details>
<summary>回答</summary>

`CodingKeys` という enum を定義し、`String` を Raw Value として使う。`CodingKey` に準拠させることで、JSON のキーとプロパティのマッピングをカスタマイズできる。

</details>

### Q3. `JSONDecoder` で日付文字列（例: `"2024-03-17T10:00:00Z"`）をデコードするには？
<details>
<summary>回答</summary>

`JSONDecoder` の `dateDecodingStrategy` を設定する。例: `.iso8601` や `.formatted(DateFormatter())` など。

</details>

---

## 3. 理論（目安: 15分）

### ポイント1: Codable はコンパイラによる自動合成

- **重要**: `struct` や `enum` の全プロパティが `Codable` なら、`init(from decoder:)` や `encode(to:)` は自動生成される。
- **よくある誤解**: 「Codable に準拠するだけで動く」と思いがちだが、**ネストした型や Optional の扱い**で型が合わないと実行時エラーになる。
- **落とし穴**: プロパティを1つでも追加・削除・リネームすると、既存の JSON との互換性が崩れる。

### ポイント2: enum と Codable の相性

- **重要**: `enum` は Raw Value が `String` や `Int` のとき、そのまま Codable に対応できる。JSON の文字列/数値が enum の case にマッピングされる。
- **よくある誤解**: 「enum は Codable で扱いにくい」と思いがちだが、Raw Value 型を指定すればシンプルに使える。
- **落とし穴**: JSON に想定外の値が来ると `DecodingError.dataCorrupted` になる。`init(from decoder:)` を自前実装してフォールバック値を用意する設計もある。その場合、`encode(to:)` も自前実装しないと Encodable が動かない。

### ポイント3: CodingKeys によるキーマッピング

- **重要**: JSON のキー（snake_case など）と Swift のプロパティ名（camelCase）が違うときは `CodingKeys` で対応する。
- **よくある誤解**: 「キー名を完全一致させるしかない」と思いがちだが、`CodingKeys` で柔軟にマッピングできる。
- **落とし穴**: `convertFromSnakeCase` を使うと、`CodingKeys` を書かずに snake_case → camelCase 変換ができるが、**キー名が完全に snake_case でないと期待通り動かない**。

### ポイント4: オプショナルとデコード失敗

- **重要**: プロパティを `Optional` にすると、JSON にキーがなくても `nil` としてデコードされる。キーはあるが値が `null` の場合も同様。
- **よくある誤解**: 「キーがない」と「値が null」は同じ扱いになる。
- **落とし穴**: キーはあるが型が違う（例: `"id": "1"` のように文字列が来るのに `Int` を期待）と `DecodingError.typeMismatch` で失敗する。Optional にしても型不一致は防げない。**API の仕様と型を必ず合わせる。**

### ポイント5: デコードエラーの扱い

- **重要**: `try?` で失敗を無視すると原因が分からない。`do-catch` で `DecodingError` を捕まえ、`context.debugDescription` をログ出力するとデバッグしやすい。
- **落とし穴**: 本番では不正な JSON に対するフォールバック（デフォルト値やスキップ）を設計しておくことが多い。

### ポイント6: 設計の選択肢 — ネスト vs フラット

- **選択肢**: API の JSON がネストしている場合、Swift 側もネストした struct にするか、フラットな struct に展開するか。
- **この教材の選択**: ネストした struct をそのまま使う。理由は、API の構造と Swift の型が1対1で対応し、変更に強いため。フラット化は `CodingKeys` やカスタム `init` で可能だが、API 変更時の修正箇所が増える。

### ポイント7: Architecture 視点 — DTO / Domain 分離と Mapper

- **DTO（Data Transfer Object）**: API の JSON に **1対1 で対応** させる型。`Codable` を付け、キー名・型はサーバー仕様に合わせる。UI やドメインルールは持たせない。
- **Domain（ドメインモデル）**: アプリの **ビジネス意味** を表す型。`Codable` にしないことも多い（API が変わっても Domain の意図は保ちたいため）。
- **Mapper**: `RunResponse（DTO）` → `Run（Domain）` のように **変換だけ** を担当する層（`init(dto:)`、`toDomain()`、`RunMapper.map(_:)` など）。DTO の変更が Mapper に閉じ込められやすい。
- **よくある誤解**: 「全部 `Codable` の struct 1つで済ませればよい」と思いがちだが、API に **計算フィールドを無理に載せる** と、クライアントとサーバーで二重定義になりやすい。
- **落とし穴**: DTO に **pace（ペース）** のような **クライアントで計算すべき値** を混ぜると、API が pace を返さない版に変わったときに全体が壊れやすい。**距離・時間など生データは DTO、pace は Domain 側で算出** するのが実務では扱いやすい。

### 🎯 Architecture でやること（要点）

- `RunResponse（DTO）` → `Run（Domain）` に **Mapper で変換**する。
- **pace（例: 1km あたりの秒数）** などは **Domain で計算**する（DTO には持たせない、または DTO には距離・時間だけ載せる）。

---

## 4. ハンズオン（目安: 28分）

### 前提・準備（3分）

1. Xcode で **File → New → Project** → **macOS** → **Command Line Tool** を選択し、プロジェクトを作成する（`main.swift` が自動生成され、実行が確実）。
2. プロジェクト名は `CodableTutorial` など任意でよい。
3. プロジェクトルートに `tutorial` フォルダを作成し、ここにモデル用の `.swift` を置く。
4. `tutorial` 内のファイルを Xcode のプロジェクトに追加する（ドラッグ＆ドロップで追加し、「Copy items if needed」は不要、「Add to targets」でメインターゲットにチェック）。

### ステップ1: 最小の Codable struct を作る（目安: 5分）

**手順:**
1. `tutorial/User.swift` を作成し、以下の struct を定義する。

```swift
struct User: Codable {
    let id: Int
    let name: String
    let email: String?
}
```

2. プロジェクトの `main.swift`（Command Line Tool で自動生成されたもの）の内容を以下に置き換える。`try` は `throws` のコンテキストが必要なため、`do-catch` で囲む。

```swift
import Foundation

do {
    let json = """
    {"id": 1, "name": "山田太郎", "email": "yamada@example.com"}
    """.data(using: .utf8)!

    let user = try JSONDecoder().decode(User.self, from: json)
    print(user.name)  // 山田太郎
} catch {
    print("デコード失敗:", error)
}
```

3. `swift run` または Xcode で Run して実行する。

**確認方法:** コンソールに `山田太郎` が出力されること。

---

### ステップ2: enum を組み込む（目安: 5分）

**手順:**
1. `tutorial/User.swift` に `UserRole` enum を追加する。

```swift
enum UserRole: String, Codable {
    case admin
    case member
    case guest
}
```

2. `User` に `role: UserRole` を追加する。
3. `main.swift` の JSON を以下に更新し、デコードする。

```swift
let json = """
{"id": 1, "name": "山田太郎", "email": "yamada@example.com", "role": "admin"}
""".data(using: .utf8)!
```

**確認方法:** `print(user.role)` で `admin` が出力されること。

---

### ステップ3: CodingKeys でキー名をマッピングする（目安: 5分）

**手順:**
1. `User` に `createdAt: Date` を追加する（JSON では `created_at`）。
2. `CodingKeys` enum を定義して `created_at` → `createdAt` をマッピングする。
3. `main.swift` で `JSONDecoder` の `dateDecodingStrategy` を `.iso8601` に設定する。

```swift
// User.swift
struct User: Codable {
    let id: Int
    let name: String
    let email: String?
    let role: UserRole
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email, role
        case createdAt = "created_at"
    }
}
```

```swift
// main.swift のデコード部分
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

let user = try decoder.decode(User.self, from: json)
```

4. JSON に `"created_at": "2024-03-17T10:00:00Z"` を追加する。

**確認方法:** `print(user.createdAt)` で正しい日付が出力されること。

---

### ステップ4: ネストした JSON をデコードする（目安: 5分）

**手順:**
1. `tutorial/Address.swift` を作成し、住所用の struct を定義する。API では `zip_code` のように snake_case が多いため、`CodingKeys` でマッピングする。

```swift
struct Address: Codable {
    let city: String
    let zipCode: String

    enum CodingKeys: String, CodingKey {
        case city
        case zipCode = "zip_code"
    }
}
```

2. `User` に `address: Address?` を追加する。`CodingKeys` にも `case address` を追加する。
3. `main.swift` の JSON を以下に更新する（ネストした `address` を含む）。

```swift
let json = """
{
  "id": 1,
  "name": "山田太郎",
  "email": "yamada@example.com",
  "role": "admin",
  "created_at": "2024-03-17T10:00:00Z",
  "address": { "city": "東京", "zip_code": "100-0001" }
}
""".data(using: .utf8)!
```

**確認方法:** `print(user.address?.city ?? "なし")` で `東京` が出力されること。

---

### ステップ5: デコードエラーをハンドリングする（目安: 5分）

**手順:**
1. `main.swift` で、一時的に不正な JSON に差し替えて実行する（例: `"id": "1"` のように Int のところに文字列を渡す）。
2. `do-catch` で `DecodingError` を捕まえ、`context.debugDescription` を `print` する。

```swift
} catch let error as DecodingError {
    switch error {
    case .typeMismatch(let type, let context):
        print("型不一致: \(type), \(context.debugDescription)")
    case .keyNotFound(let key, let context):
        print("キーなし: \(key.stringValue), \(context.debugDescription)")
    default:
        print("デコードエラー:", error)
    }
} catch {
    print("その他:", error)
}
```

3. 正常な JSON に戻し、最後に正しくデコードできることを確認する。

**確認方法:** 不正 JSON でエラーメッセージが分かりやすく表示されること。正常 JSON に戻すと `山田太郎` など期待どおり出力されること。

---

### 最小成果物

- `User` と `Address` をデコードできるコード
- `main.swift` を実行すると、`山田太郎` と `東京` がコンソールに出力されること

---

### テスト（最低1つ）

Command Line Tool プロジェクトに **Test ターゲットを追加** する（File → New → Target → macOS Unit Testing Bundle）。以下を `CodableTutorialTests` 内に追加する。

```swift
import XCTest
@testable import CodableTutorial

final class UserDecodeTests: XCTestCase {
    func testUserDecode() throws {
        let json = """
        {"id": 1, "name": "山田太郎", "email": "yamada@example.com", "role": "admin", "created_at": "2024-03-17T10:00:00Z"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let user = try decoder.decode(User.self, from: json)

        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "山田太郎")
        XCTAssertEqual(user.role, .admin)
    }
}
```

**確認方法:** Cmd+U でテストを実行し、`testUserDecode` が成功すること。

---

### Architecture 補習（オプション・目安: 10〜15分）

DTO → Domain の流れを **ラン記録** で一通りやる。`tutorial` にファイルを追加してよい。

#### 🎯 やること

- `RunResponse（DTO）` → `Run（Domain）` へ **Mapper** で変換する。
- **pace（1km あたりの秒数）** などは **Domain で計算**する（JSON に pace がなくてもよい）。

#### 1. DTO: API の形に合わせる（`RunResponse.swift`）

```swift
import Foundation

/// API レスポンス用。サーバーのキー・型に合わせる（DTO）。
struct RunResponse: Codable {
    let id: String
    let distanceMeters: Double
    let durationSeconds: Double

    enum CodingKeys: String, CodingKey {
        case id
        case distanceMeters = "distance_meters"
        case durationSeconds = "duration_seconds"
    }
}
```

#### 2. Domain: 意味と計算を持つ（`Run.swift`）

```swift
import Foundation

/// アプリ内のドメインモデル。Codable にしない例（API と切り離す）。
struct Run: Equatable {
    let id: String
    let distanceMeters: Double
    let durationSeconds: Double
    /// 1km あたりの所要秒数（Domain で算出）
    let paceSecondsPerKm: Double
}
```

#### 3. Mapper: 変換のみ（`RunMapper.swift`）

```swift
import Foundation

enum RunMapper {
    static func toDomain(_ dto: RunResponse) -> Run {
        let km = dto.distanceMeters / 1000.0
        let pace: Double
        if km > 0 {
            pace = dto.durationSeconds / km
        } else {
            pace = 0
        }
        return Run(
            id: dto.id,
            distanceMeters: dto.distanceMeters,
            durationSeconds: dto.durationSeconds,
            paceSecondsPerKm: pace
        )
    }
}
```

#### 4. `main.swift` で確認

```swift
let runJSON = """
{"id": "run-1", "distance_meters": 5000, "duration_seconds": 1500}
""".data(using: .utf8)!

let dto = try JSONDecoder().decode(RunResponse.self, from: runJSON)
let run = RunMapper.toDomain(dto)
// 5km を 1500秒 → pace = 1500/5 = 300 秒/km
print(run.paceSecondsPerKm)  // 300.0
```

**確認方法:** `paceSecondsPerKm` が `300.0` になること。

---

## 5. 追加課題（時間が余ったら・目安: 各2〜3分）

### Easy: Optional の挙動確認

`email` を JSON から省略した場合と `null` を渡した場合の両方で、`user.email` が `nil` になることを確認する。

<details>
<summary>回答</summary>

どちらも `nil` になる。`Optional` はキーがない場合と値が `null` の場合の両方で `nil` を返す。

</details>

### Medium: 想定外の enum 値への対応

`UserRole` に存在しない文字列（例: `"unknown"`）が JSON で渡されたとき、`guest` にフォールバックするように `init(from decoder:)` を自前実装する。

<details>
<summary>回答</summary>

`init(from decoder:)` を自前実装すると `encode(to:)` は自動合成されないため、両方書く必要がある。

```swift
enum UserRole: String, Codable {
    case admin
    case member
    case guest

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = UserRole(rawValue: raw) ?? .guest
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
```

</details>

### Hard: 複数フォーマットの日付に対応

`created_at` が ISO8601 と `"yyyy/MM/dd"` の両方で来る可能性がある場合、カスタム `Date` デコーダーを実装する。

<details>
<summary>回答</summary>

`JSONDecoder` の `dateDecodingStrategy` を `.custom` にし、複数の `DateFormatter` を順に試すクロージャを渡す。または `User` の `init(from decoder:)` 内で `created_at` を `String` として取り、複数フォーマットでパースする。

</details>

---

## 6. 実務での使いどころ（目安: 5分）

1. **REST API のレスポンス**: 例として `GET /api/users/1` のレスポンスを `User` でデコードする。`URLSession.data(for: url)` は非同期のため、`async/await` や Combine と組み合わせる。実務ではネットワークエラーとデコードエラーを分けてハンドリングする。規模が大きいと **`*Response` を DTO とし、画面用の Domain に Mapper で渡す** 構成にすることが多い。
2. **設定・キャッシュの永続化**: `UserDefaults` に `JSONEncoder().encode(settings)` で保存し、起動時に `JSONDecoder().decode(Settings.self, from: data)` で読み込む。キーは `"app.settings"` など一意にしておく。
3. **イベント送信**: 分析用イベントを `Encodable` でモデル化し、`JSONEncoder().encode(event)` で JSON 化してバックエンドに POST する。スキーマ変更時はバックエンドと型を合わせておく。

---

## 7. まとめ（目安: 2分）

- **Codable** は `Encodable` と `Decodable` の型エイリアスで、struct/enum のプロパティが Codable なら自動合成される。
- **CodingKeys** で JSON のキーとプロパティをマッピングし、**dateDecodingStrategy** で日付フォーマットを指定する。
- 実務では **デコードエラーのハンドリング** と **想定外の値へのフォールバック** を設計しておくことが重要。
- **DTO は API 形、Domain はアプリの意味** に分け、**Mapper** で `RunResponse` → `Run` のように変換する。**pace などの派生値は Domain で計算** すると変更に強い。

---

## 8. 明日の布石（目安: 1分）

1. **Swift Concurrency (async/await)** — 非同期処理と Codable を組み合わせた API 呼び出し
2. **Swift Generics と Protocol** — Codable を汎用的に扱うリポジトリパターン
