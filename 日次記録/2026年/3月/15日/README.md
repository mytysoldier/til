# Go struct 1日分学習教材

**テーマ**: struct / json tag / marshal-unmarshal  
**想定時間**: 60分（±10分）  
**対象レベル**: 中級

| セクション | 目安時間 |
|------------|----------|
| 1. 今日のゴール | 1分 |
| 2. 事前知識チェック | 5分 |
| 3. 理論 | 12分 |
| 4. ハンズオン | 35分 |
| 5. 追加課題（余裕があれば） | 5分 |
| 6. 実務での使いどころ | 3分 |
| 7. まとめ・8. 明日の布石 | 4分 |

---

## 1. 今日のゴール（1〜2行）

Goのstructを定義し、`encoding/json`でJSONとの相互変換（marshal/unmarshal）ができるようになる。json tagによる制御と、よくある落とし穴を理解する。

---

## 2. 事前知識チェック（3問）

### Q1. 次のコードの出力は？

```go
type User struct {
    Name string
    Age  int
}
u := User{Name: "Alice", Age: 30}
fmt.Printf("%+v", u)
```

**A1.** `{Name:Alice Age:30}`  
`%+v`はフィールド名付きで構造体を表示する。

---

### Q2. 小文字で始まるフィールドはJSONに含まれるか？

```go
type Config struct {
    Public  string
    private string
}
```

**A2.** `private`は**含まれない**。Goでは小文字始まりはパッケージ外から非公開（unexported）となり、`encoding/json`もそのフィールドを無視する。

---

### Q3. `omitempty`タグの意味は？

**A3.** そのフィールドがゼロ値（空文字、0、nilなど）のとき、JSON出力から**省略**する。APIで不要な`null`や`0`を出したくないときに使う。

---

## 3. 理論（重要ポイント3〜6個）

### 3.1 structの基本とゼロ値

- structはフィールドの集まり。型を組み合わせてドメインモデルを表現する。
- 宣言時に値を指定しないフィールドは**ゼロ値**になる（string→`""`、int→`0`、ポインタ→`nil`など）。
- **よくある誤解**: 「未初期化」と「ゼロ値」は別。ゼロ値は有効な値であり、`nil`チェックが必要なのはポインタ・スライス・マップなど。

---

### 3.2 json tagの役割

- `json:"fieldname"` でJSONのキー名を指定。指定しないとフィールド名がそのまま使われる。
- `json:"-"` でJSONから完全に除外。
- `json:"fieldname,omitempty"` でゼロ値のとき省略。
- **よくある落とし穴**: `omitempty`をポインタに使うと、`nil`のとき省略される。ゼロ値と「未設定」を区別したいときはポインタが有効。

---

### 3.3 Marshal（構造体 → JSON）

- `json.Marshal(v)` で `[]byte` と `error` を返す。
- 失敗例: 循環参照、Marshaler未実装のチャネル型など。
- **よくある誤解**: エラーを無視するとpanicではなく、不正なJSONや空の結果になる。必ず`err`をチェックする。

---

### 3.4 Unmarshal（JSON → 構造体）

- `json.Unmarshal(data, &v)` で`v`に上書き。**ポインタ**を渡す必要がある。
- JSONにないフィールドは既存の値が残る（上書きされない）。
- **よくある落とし穴**: `Unmarshal(data, v)` と値渡しにするとコンパイルは通るが、何も書き込まれない。必ず`&v`で渡す。

---

### 3.5 型の対応関係

| Go型 | JSON型 |
|------|--------|
| string | string |
| int, int64, float64 | number |
| bool | boolean |
| nil | null |
| []T | array |
| map[string]T | object |
| struct | object |

- **よくある落とし穴**: JSONの数値は`float64`として解釈される。`int`フィールドに`Unmarshal`すると、内部的に`float64`→`int`変換が行われるが、巨大な数では精度落ちの可能性がある。`json.Number`や`encoding/json`の`UseNumber()`で制御できる。
- **型不一致のエラー**: JSONの`"name": 123`（数値）を`string`フィールドにUnmarshalすると、**エラーではなく空文字になる**。`json.Unmarshal`は型が合わないと無視する。デバッグに困るので、API仕様とstructの型を一致させること。

---

### 3.6 設計の選択肢: ポインタ vs 値

- **値型**: シンプルでコピーが発生。小さいstruct向け。
- **ポインタ型**: 大きなstructや「未設定」を区別したいとき（`omitempty`と組み合わせ）に有効。

**今回の選択**: ハンズオンでは基本的に値型を使い、`omitempty`で「未設定」を表現する場面ではポインタを導入する。実務では「APIレスポンスでnullを出したくない」ケースでポインタ+`omitempty`がよく使われる。

---

## 4. ハンズオン（手順）

**作業ディレクトリ**: 教材のルート（このREADMEがあるフォルダ）で、`tutorial` を作成し、`tutorial` 内で作業する。

### ステップ1: プロジェクト準備（5分）

1. `tutorial` フォルダを作成し、その中に移動する。
2. `main.go` を作成し、以下を書く（`main` の前に定義する場所は後で使う）:

```go
package main

func main() {
}
```

3. **tutorial フォルダ内で** `go mod init tutorial` を実行する。

**確認方法**: `cd tutorial && go build` が成功する。

**得られる知見**: `go mod init` はモジュールルート（go.mod があるフォルダ）で実行する。`go build` は依存関係を解決し、コンパイル可能な状態か検証する。

---

### ステップ2: 基本structの定義（6分）

1. `main.go` の `func main()` の**直前に** `User` を定義する。
2. `main` 内で `User` を生成し、`fmt.Printf` で表示する。

**コード例**（`main.go`）:

```go
package main

import "fmt"

type User struct {
    Name  string
    Age   int
    Email string
}

func main() {
    u := User{Name: "Alice", Age: 30, Email: "alice@example.com"}
    fmt.Printf("%+v\n", u)
}
```

**確認方法**: `go run .` で `{Name:Alice Age:30 Email:alice@example.com}` が出力される。

**得られる知見**: struct は `type 名前 struct { フィールド }` で定義する。`%+v` はフィールド名付きで表示するのでデバッグに便利。複合リテラル `User{Name: "Alice", ...}` でフィールド名指定の初期化ができる。

---

### ステップ3: json tagの追加とMarshal（8分）

1. `User` の各フィールドに `json:"name"` などのタグを付ける。
2. `json.Marshal(u)` を呼び、エラーチェック後に `string(data)` で表示する。

**コード例**（`main.go`）:

```go
package main

import (
    "encoding/json"
    "fmt"
    "log"
)

type User struct {
    Name  string `json:"name"`
    Age   int    `json:"age"`
    Email string `json:"email"`
}

func main() {
    u := User{Name: "Alice", Age: 30, Email: "alice@example.com"}
    data, err := json.Marshal(u)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println(string(data))
}
```

**確認方法**: `{"name":"Alice","age":30,"email":"alice@example.com"}` のようなJSONが出力される。

**得られる知見**: json tag で JSON のキー名を制御できる。タグなしだと Go のフィールド名がそのまま使われる（PascalCase のまま）。Marshal は `[]byte` を返すので、文字列表示には `string(data)` が必要。エラーを無視すると不正な JSON や空の結果になる。

---

### ステップ4: UnmarshalでJSONを構造体に戻す（8分）

1. `data`（Marshal結果）を `json.Unmarshal(data, &u2)` で `u2` に格納する。**`&u2` を渡すこと**。
2. エラーチェック後、`u2` を表示して `u` と一致するか確認する。

**コード例**（`main.go`）:

```go
package main

import (
    "encoding/json"
    "fmt"
    "log"
)

type User struct {
    Name  string `json:"name"`
    Age   int    `json:"age"`
    Email string `json:"email"`
}

func main() {
    u := User{Name: "Alice", Age: 30, Email: "alice@example.com"}
    data, err := json.Marshal(u)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("Marshal:", string(data))

    var u2 User
    err = json.Unmarshal(data, &u2)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Unmarshal: %+v\n", u2)
}
```

**確認方法**: `u2` の内容が `u` と一致する（`{Name:Alice Age:30 Email:alice@example.com}`）。

**得られる知見**: Unmarshal は**ポインタ**（`&u2`）を渡す必要がある。値渡しだとコピーに書き込むだけで元の変数は変わらない。JSON にないキーは既存の値が残る（上書きされない）。struct → JSON → struct の往復で、データの永続化や API 通信の基礎ができる。

---

### ステップ5: omitemptyとテスト（8分）

1. `Email` のタグを `json:"email,omitempty"` に変更する。
2. `User{Name: "Bob", Age: 25, Email: ""}` をMarshalし、出力に `"email"` が含まれないことを確認する。
3. `user_test.go` を作成し、テストを書く。

**コード例**（`main.go`）:

```go
package main

import (
    "encoding/json"
    "fmt"
    "log"
)

type User struct {
    Name  string `json:"name"`
    Age   int    `json:"age"`
    Email string `json:"email,omitempty"`
}

func main() {
    u := User{Name: "Alice", Age: 30, Email: "alice@example.com"}
    data, err := json.Marshal(u)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("Alice:", string(data))

    // omitempty: 空のEmailはJSONに含まれない
    bob := User{Name: "Bob", Age: 25, Email: ""}
    dataBob, err = json.Marshal(bob)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("Bob:", string(dataBob))
}
```

**コード例**（`user_test.go`）:

```go
package main

import (
    "encoding/json"
    "strings"
    "testing"
)

func TestUserMarshalOmitEmpty(t *testing.T) {
    u := User{Name: "Bob", Age: 25, Email: ""}
    data, err := json.Marshal(u)
    if err != nil {
        t.Fatal(err)
    }
    if strings.Contains(string(data), `"email"`) {
        t.Errorf("omitempty: email should be omitted, got %s", string(data))
    }
}
```

**確認方法**: `cd tutorial && go test -v` が成功する。`go run .` で Bob のJSONに `"email"` が含まれないことを確認できる。

**得られる知見**: `omitempty` はゼロ値のとき JSON からキーを省略する。API で `null` や空文字を出したくないときに使う。`*testing.T` の `t.Fatal` はテストを即終了、`t.Errorf` は失敗を記録して続行。`go test -v` で各テストの実行結果が表示される。

---

## 5. 追加課題（時間が余ったら）

### Easy: ネストしたstructのMarshal/Unmarshal

`User` に `Address struct { City, Zip string }` を追加し、JSONとの往復が正しく動くことを確認する。

**回答例**:
```go
type Address struct {
    City string `json:"city"`
    Zip  string `json:"zip"`
}
type User struct {
    Name    string  `json:"name"`
    Age     int     `json:"age"`
    Email   string  `json:"email,omitempty"`
    Address Address `json:"address,omitempty"`
}
```

---

### Medium: `json:"-"` で除外

パスワードのような機密フィールドを `json:"-"` でJSONから完全に除外する。Marshal/Unmarshalの両方で無視されることを確認する。

**回答例**:
```go
type User struct {
    Name     string `json:"name"`
    Password string `json:"-"`  // 常に除外
}
```

---

### Hard: カスタムMarshal/Unmarshal

`time.Time` を `"2006-01-02"` 形式の文字列としてJSONに出すため、ラッパー型を作り `json.Marshaler` / `json.Unmarshaler` を実装する。

**回答例**:
```go
type Date time.Time

func (d Date) MarshalJSON() ([]byte, error) {
    t := time.Time(d)
    return json.Marshal(t.Format("2006-01-02"))
}

func (d *Date) UnmarshalJSON(data []byte) error {
    var s string
    if err := json.Unmarshal(data, &s); err != nil {
        return err
    }
    t, err := time.Parse("2006-01-02", s)
    if err != nil {
        return err
    }
    *d = Date(t)
    return nil
}

// String を実装しないと %+v で {wall:0 ext:... loc:<nil>} と内部表現が出る
func (d Date) String() string {
    return time.Time(d).Format("2006-01-02")
}
```

**呼び出し例**:
```go
type Event struct {
    Name string `json:"name"`
    Date Date   `json:"date"`
}

func main() {
    // Marshal: Date が "2006-01-02" 形式の文字列になる
    e := Event{Name: "誕生日", Date: Date(time.Date(1990, 3, 15, 0, 0, 0, 0, time.UTC))}
    data, _ := json.Marshal(e)
    fmt.Println(string(data)) // {"name":"誕生日","date":"1990-03-15"}

    // Unmarshal: JSON の "2025-12-31" を Date に変換
    var e2 Event
    json.Unmarshal([]byte(`{"name":"記念日","date":"2025-12-31"}`), &e2)
    fmt.Printf("%+v\n", e2) // {Name:記念日 Date:2025-12-31}（String() により見やすく表示）
}
```

---

## 6. 実務での使いどころ（具体例3つ）

1. **REST APIのレスポンス**: `GET /users/1` のレスポンスを `UserResponse` struct（`json:"id"`, `json:"name"`, `json:"email"` タグ付き）で定義し、`json.Unmarshal(respBody, &user)` でパース。キー名がsnake_caseのAPI仕様に合わせてタグで対応する。
2. **設定ファイル**: `config.json` を `os.ReadFile` で読み、`var cfg Config` に `json.Unmarshal`。`omitempty` でオプション項目（例: ログレベル未指定時はデフォルト）を扱う。
3. **構造化ログ**: 監査イベントを `AuditEvent{UserID: 1, Action: "login", Timestamp: time.Now()}` のようにstructで表現し、`json.Marshal` で1行JSONとして出力。ElasticsearchやCloudWatch Logsで検索・集計しやすい。

---

## 7. まとめ（今日の学び3行）

- structとjson tagで、Goの型とJSONのキーを対応づけられる。
- Marshal/Unmarshalではエラーチェックとポインタ渡しを忘れずに。
- `omitempty`や`json:"-"`で、APIや設定の表現を柔軟に制御できる。

---

## 8. 明日の布石（次のテーマ候補を2つ）

1. **interfaceと型アサーション**: structを抽象化し、テストや差し替え可能な設計にする。
2. **embedding（埋め込み）**: structの組み合わせで継承に近い再利用を実現する。
