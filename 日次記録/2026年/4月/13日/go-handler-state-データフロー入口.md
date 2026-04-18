# Go: State / handler / データフローの入口（1日教材）

参考（公式・標準ライブラリ）: [net/http](https://pkg.go.dev/net/http)（`Handler` / `ServeHTTP`）、[net/http/httptest](https://pkg.go.dev/net/http/httptest)、[context](https://pkg.go.dev/context)。ルーティングは Go 1.22 以降で強化された [`http.ServeMux`](https://pkg.go.dev/net/http#ServeMux) のパターン記法も利用可能。

**前提:** ローカルに Go **1.22 以上**を推奨（`go version` で確認）。1.21 以下の場合はステップ 4 の代替ルート（メソッドなしのパターン）に従う。

---

## 1. 今日のゴール

**目安時間（分）: 1**

HTTP の入口である `handler` の責務を言語化し、DTO による境界と「状態を持たない層／持つ層」を切り分けたうえで、`net/http` と `httptest` だけで動く最小サーバ＋**少なくとも 1 本のユニットテスト**を `tutorial/handler-mini/` に作れること。

---

## 2. 事前知識チェック（3問）※回答付き

**目安時間（分）: 3**

1. **`http.Handler` と `http.HandlerFunc` の違いは？**  
   **回答:** `Handler` は `ServeHTTP(ResponseWriter, *Request)` を実装するインターフェース。`HandlerFunc` は関数型で、`ServeHTTP` をレシーバ実装として持ち、普通の関数を `Handler` として扱えるアダプタ（[公式](https://pkg.go.dev/net/http#HandlerFunc)）。

2. **リクエストごとにキャンセルや期限を伝える標準の仕組みは？**  
   **回答:** `*http.Request` の `Context()` が返す `context.Context`。ハンドラ内では `r.Context()` を下位処理に渡し、タイムアウトやクライアント切断に合わせて処理を止める。

3. **「ハンドラにビジネスルールを全部書く」と何が辛くなりやすい？**  
   **回答:** HTTP 詳細（ヘッダ・クエリ・JSON）とドメインが混ざり、テストが重くなり、再利用しづらくなる。境界で DTO に変換し、ドメイン層は HTTP を知らない形にすると改善しやすい。

---

## 3. 理論（重要ポイント 3〜6 個）

**目安時間（分）: 14**

### 3.1 `handler`（HTTP 層）の責務

- **要点:** ルーティングに合わせてリクエストを解釈し、認証・バリデーション・シリアライズ（JSON 等）を担い、**適切なステータスとボディ**を `ResponseWriter` に書く。ドメインの「意味」は下位に委譲し、HTTP の細部だけをここに閉じ込めるのが理想。
- **よくある誤解/落とし穴:** 「handler = 全部入りコントローラ」にすると、DB 直叩きと JSON が一箇所に集まり、変更に弱い。薄い入口に留める意識が必要。

### 3.2 DTO（Data Transfer Object）で境界を切る

- **要点:** 入出力用の構造体（JSON タグ付きなど）を **HTTP 層専用**とし、内部では別型（ドメインモデル）にマッピングする。名前も `CreateUserRequest` / `UserResponse` のように **用途が分かる**ものにする。
- **よくある誤解/落とし穴:** ドメインの `User` をそのまま JSON にして公開すると、フィールド追加がそのまま API 互換性問題になる。DTO を分けると「公開スキーマ」と「内部モデル」を分離しやすい。

### 3.3 状態を持たない層と持つ層

- **要点:**
  - **持たない:** リクエスト処理の純粋な変換（バイト列→DTO、DTO→ドメイン入力）は、可能なら **引数と戻り値だけ**で表現しテストしやすくする。
  - **持つ:** DB 接続、設定、ロガー、メトリクス用クライアントなどは **`struct` のフィールド**や **コンストラクタ注入**で明示的に持つ。リクエスト間で共有する「長寿命」なものはここ。
- **よくある誤解/落とし穴:** グローバル変数に依存を置くとテストで差し替えにくい。`Server` や `UserHandler` のような型に閉じると、`httptest` で小さく組み立てられる。**複数リクエストで共有する `map` など可変状態**にロックをかけ忘れるとデータ競合になる（実務では `go test -race` で検知）。

### 3.4 データフローの入口としての一方向性

- **要点:** 典型的には `HTTP →（parse）DTO →（map）ドメイン入力 → ユースケース → ドメイン結果 →（map）DTO → JSON`。**下位から `http.ResponseWriter` を見せない**と層の依存がきれいになる。
- **よくある誤解/落とし穴:** `context.Context` を引数で渡すのを忘れると、キャンセルが伝播せずゴルーチンや DB 待ちが残りやすい。**ハンドラ内で `go func()` したとき**、`r.Context()` をそのまま長時間保持すると、リクエスト終了後にキャンセル済みコンテキストを触る・逆にゴルーチンが止まらない、の両方が起きやすい。非同期に回すなら **コンテキストの意図**（キャンセル付きコピーか、バックグラウンド用の分離か）を決めてから渡す。

### 3.5 `ResponseWriter`・JSON・エラー（実務で踏みがち）

- **要点:** JSON API では `w.Header().Set("Content-Type", "application/json; charset=utf-8")` を書き出し前に設定する。`json.NewEncoder(w).Encode(v)` の **戻り値 `error` は無視しにくい**（ログか `http.Error` に繋ぐ）。`WriteHeader` を明示呼び出しした後にヘッダを変えても効かない点に注意。
- **よくある誤解/落とし穴:** `Encode` 失敗後にステータスを変えようとして二重に書き込む。`panic` を握りつぶさない（本番ではトップで `recover` する構成もあるが、まずはテストで異常系を見る）。

### 3.6 設計の選択肢と、この教材での選択

- **選択肢 A:** トップレベルの `func(w,r)` だけで完結させる。
- **選択肢 B:** `type App struct { /* deps */ }` とし、メソッドで `GetHealth(w,r)` のように実装し、`main` で `ServeMux` に登録する。
- **この教材での選択:** **B を採用**。依存（例: `prefix string`）をフィールドに持ち、**テスト時に `&App{...}` を組み立て**やすくするため。ルート登録を `func (a *App) Register(mux *http.ServeMux)` にまとめると、`main` が薄くなり実務の「組み立てコード」と同じ形になる。

---

## 4. ハンズオン（手順）

**目安時間（分）: 31**

作業ディレクトリは **`tutorial/handler-mini/`**（日付フォルダ直下の `tutorial` 配下）。**外部ライブラリは使わない**（標準の `net/http` と `encoding/json` のみ）。

**完成イメージ（ファイル一覧）:**

| ファイル           | 役割                              |
| ------------------ | --------------------------------- |
| `go.mod`           | モジュール名                      |
| `dto.go`           | DTO と純関数 `NormalizeHello`     |
| `handlers.go`      | `App` と `GetHealth` / `GetHello` |
| `main.go`          | `mux` 登録と `ListenAndServe`     |
| `handlers_test.go` | `httptest` によるテスト           |

### ステップ 1: ディレクトリとモジュール初期化

- **やること:** `tutorial/handler-mini/` を作成し、カレントをそこにして `go mod init example.com/handler-mini` を実行する。続けて `go version` を実行し、**1.22 未満**ならステップ 4 の「代替」に目を通す。
- **確認方法:** `go.mod` が生成され、`go env GOMOD` でそのパスが表示される。

### ステップ 2: DTO と最小の `main.go`（コンパイル可能にする）

- **やること:**
  1. `dto.go` を作成（`package main`）。`HealthResponse`、`HelloRequest`、`NormalizeHello` をステップ 2 のコード例どおり定義する。
  2. **同じステップ内で** `main.go` を作成し、`func main() {}` だけ置く（中身は空でよい）。  
     `package main` で `func main` が無いと **`go build` は通らない**ため、この順序を守る。
- **確認方法:** `go build -o /dev/null .` または `go build .` が成功する。

```go
// dto.go
package main

type HealthResponse struct {
	Status string `json:"status"`
}

type HelloRequest struct {
	Name string
}

func NormalizeHello(in HelloRequest) HelloRequest {
	if in.Name == "" {
		in.Name = "world"
	}
	return in
}
```

```go
// main.go（このステップではプレースホルダ）
package main

func main() {}
```

### ステップ 3: 依存を持つ `App` とハンドラ実装

- **やること:** `handlers.go` に以下を実装する。
  - `type App struct { Prefix string }`
  - `func (a *App) GetHealth(w http.ResponseWriter, r *http.Request)` … `HealthResponse{Status: "ok"}` を JSON で返す。**書き出し前に** `Content-Type` を設定する。
  - `func (a *App) GetHello(w http.ResponseWriter, r *http.Request)` … クエリ `name` から `HelloRequest` を作り、`NormalizeHello` 経由でメッセージを組み立てて JSON で返す（例: `{"message":"hello, world"}` の形式。`Prefix` は任意で本文に含めてもよい）。
  - `json.NewEncoder(w).Encode(...)` の **`error` を返したら** `http.Error` かログ＋500 など一貫した失敗パスにする（教材では最小でも `if err := ...; err != nil { http.Error(w, ..., 500); return }`）。

**コード例（`handlers.go`）:**

```go
package main

import (
	"encoding/json"
	"fmt"
	"net/http"
)

// App はリクエスト間で共有する依存（設定など）を保持する。
type App struct {
	Prefix string
}

// helloResponse は /hello の JSON 本文用（ステップ2の DTO に載せてもよい）。
type helloResponse struct {
	Message string `json:"message"`
}

func (a *App) GetHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	if err := json.NewEncoder(w).Encode(HealthResponse{Status: "ok"}); err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (a *App) GetHello(w http.ResponseWriter, r *http.Request) {
	name := r.URL.Query().Get("name")
	in := HelloRequest{Name: name}
	norm := NormalizeHello(in)

	msg := fmt.Sprintf("hello, %s", norm.Name)
	if a.Prefix != "" {
		msg = fmt.Sprintf("%s %s", a.Prefix, msg)
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	if err := json.NewEncoder(w).Encode(helloResponse{Message: msg}); err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}
```

- **確認方法:** `go build .` が通る。`App` のフィールドが **リクエスト間で共有される状態**、`r` と DTO が **リクエスト固有**であることがコード上で区別できる。

### ステップ 4: `main.go` で `ServeMux` に登録してサーバ起動

- **やること:** `main` を次のように置き換える（**Go 1.22+**）:

```go
package main

import "net/http"

func main() {
	app := &App{Prefix: "[demo]"}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", app.GetHealth)
	mux.HandleFunc("GET /hello", app.GetHello)
	if err := http.ListenAndServe(":8080", mux); err != nil {
		panic(err)
	}
}
```

- **Go 1.21 以下の代替:** メソッド付きパターンが使えないため、例として次のようにする。

```go
mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	app.GetHealth(w, r)
})
// /hello も同様
```

- **確認方法:** `go run .` のあと、別ターミナルで  
  `curl -s -i http://127.0.0.1:8080/health` … ステータス 200、`Content-Type` に `application/json` が含まれる。  
  `curl -s "http://127.0.0.1:8080/hello?name=Go"` … メッセージが `name` を反映する。

### ステップ 5: `httptest` でハンドラを直接テストする

- **やること:** `handlers_test.go`（`package main`）を追加。`TestGetHealth` で `httptest.NewRecorder` と `httptest.NewRequest(http.MethodGet, "/health", nil)` を使い、`app.GetHealth(rec, req)` を呼ぶ。`rec.Code == 200` と、`json.Decoder` で `HealthResponse` が `status: ok` になることを検証する。**任意:** `TestGetHello` でクエリ付き URL を渡し、`NormalizeHello` 経由の結果が期待どおりか確認すると、データフローのテストが強くなる。
- **確認方法:** `go test ./...` がパスする。共有状態を触る実装にした場合は `go test -race ./...` も試す。
- **テストの妥当性:** ネットワークにバインドせず、**ハンドラの入出力（ステータス・JSON）**だけを検証するのは、実務のハンドラ単体テストと同型（[httptest](https://pkg.go.dev/net/http/httptest)）。

```go
func TestGetHealth(t *testing.T) {
	t.Parallel()
	app := &App{Prefix: "[test]"}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	app.GetHealth(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	var got HealthResponse
	if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
		t.Fatal(err)
	}
	if got.Status != "ok" {
		t.Fatalf("got %+v", got)
	}
}
```

**本日の最小成果物:** `GET /health` と `GET /hello` が `curl` で動き、`go test` が**少なくとも 1 件**パスする。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）: 4**

### Easy

- **内容:** `/hello` の応答 JSON に `prefix` フィールドを追加し、`app.Prefix` を載せる。`TestGetHello` を 1 本追加して `prefix` を検証する。

**回答例:** `HelloResponse` を `dto.go` に置くか `handlers.go` に置くかはどちらでもよい。以下は **`dto.go` に型を足し、`GetHello` で両フィールドを埋める**例。

`dto.go` に追加:

```go
type HelloResponse struct {
	Message string `json:"message"`
	Prefix  string `json:"prefix"`
}
```

`handlers.go` の `GetHello`（ステップ3と同様に **本文の `message` にも `Prefix` を前置**しつつ、JSON の **`prefix` フィールドにも `app.Prefix` を載せる**）:

```go
func (a *App) GetHello(w http.ResponseWriter, r *http.Request) {
	name := r.URL.Query().Get("name")
	in := HelloRequest{Name: name}
	norm := NormalizeHello(in)

	msg := fmt.Sprintf("hello, %s", norm.Name)
	if a.Prefix != "" {
		msg = fmt.Sprintf("%s %s", a.Prefix, msg)
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	if err := json.NewEncoder(w).Encode(HelloResponse{
		Message: msg,
		Prefix:  a.Prefix,
	}); err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
		return
	}
}
```

`handlers_test.go` に `TestGetHello` を 1 本追加する例:

```go
func TestGetHello(t *testing.T) {
	t.Parallel()
	app := &App{Prefix: "[test]"}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/hello?name=Go", nil)
	app.GetHello(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	var got HelloResponse
	if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
		t.Fatal(err)
	}
	if got.Prefix != "[test]" {
		t.Fatalf("prefix = %q", got.Prefix)
	}
	if got.Message != "[test] hello, Go" {
		t.Fatalf("message = %q", got.Message)
	}
}
```

（`handlers.go` に `HelloResponse` を置いた場合は、テストと同じパッケージなのでそのまま `HelloResponse` を参照できる。）

### Medium

- **内容:** `context.WithTimeout(r.Context(), 50*time.Millisecond)` を張ったコンテキストを下位の「重い処理」を模した関数に渡し、タイムアウト時は 503 を返す疑似ハンドラを追加する。

**回答例:** `handlers.go` に次を追加し（先頭の `import` に `context` と `time` を足す）、`main.go` でルートを登録する。

```go
func slowWork(ctx context.Context) error {
	select {
	case <-time.After(100 * time.Millisecond):
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (a *App) Slow(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 50*time.Millisecond)
	defer cancel()
	if err := slowWork(ctx); err != nil {
		http.Error(w, "timeout", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
}
```

`main.go`（Go 1.22+ のパターン記法の例）:

```go
mux.HandleFunc("GET /slow", app.Slow)
```

**任意の確認:** `curl -i http://127.0.0.1:8080/slow` で **503** と本文 `timeout` が返れば、`slowWork` が 50ms より長いためタイムアウトした挙動になっている。

**任意のテスト例**（`handlers_test.go`）:

```go
func TestSlowTimeout(t *testing.T) {
	t.Parallel()
	app := &App{}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/slow", nil)
	app.Slow(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503", rec.Code)
	}
}
```

### Hard

- **内容:** `middleware` として `func(http.Handler) http.Handler` を 1 つ定義し、全ハンドラの前にリクエスト ID（`X-Request-ID` がなければ生成）をログ出力する。`mux.Handle` に `middleware(http.HandlerFunc(app.GetHealth))` のように渡す。

**回答例:** 新規 `middleware.go` に置いても、既存ファイルの末尾に追加してもよい。`import` に `fmt`, `log`, `time` が必要。

```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
)

func withRequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-ID")
		if id == "" {
			id = fmt.Sprintf("%d", time.Now().UnixNano())
		}
		log.Printf("rid=%s %s %s", id, r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
	})
}
```

`main.go` で **ハンドラをラップしてから** `ServeMux` に渡す例（Go 1.22+）:

```go
func main() {
	app := &App{Prefix: "[demo]"}
	mux := http.NewServeMux()
	mux.Handle("GET /health", withRequestID(http.HandlerFunc(app.GetHealth)))
	mux.Handle("GET /hello", withRequestID(http.HandlerFunc(app.GetHello)))
	if err := http.ListenAndServe(":8080", mux); err != nil {
		panic(err)
	}
}
```

`HandleFunc` ではなく `Handle` を使う点に注意する（ラップ後は `http.Handler` になるため）。`go run .` 後に `curl -s -i http://127.0.0.1:8080/health` を実行し、サーバの標準出力に `rid=...` のログが出ればよい。

---

## 6. 実務での使いどころ（具体例 3 つ）

**目安時間（分）: 3**

1. **Kubernetes 上のサービス:** コンテナの **liveness/readiness** 用に `GET /healthz`（プロセス生存）と `GET /readyz`（DB やキャッシュへの `Ping` を `r.Context()` 付きで）を分け、オーケストレータがトラフィックを切る判断材料にする。handler は **タイムアウトとステータスコード**（503 vs 200）を揃えるのが責務。
2. **BFF / 公開 API:** モバイル向け JSON のスキーマ（フィールド名・省略ルール）を **DTO だけ**に閉じ、内部のドメインモデル変更をクライアントに直に露出させない。レビュー時も「この struct が契約」で議論しやすい。
3. **インシデント対応・SLO:** 同じ handler 層で **リクエスト ID**（ミドルウェア）と **構造化ログ**を揃え、トレース ID を `Context` で下流の `http.Client` / DB に渡す。テストでは `httptest` でステータスと本文の契約を先に固め、本番の変化を検知しやすくする。

---

## 7. まとめ（今日の学び 3 行）

**目安時間（分）: 2**

- `handler` は HTTP の解釈と応答に専念し、ドメインは DTO 越しに呼ぶと責務が分かれ、テストも書きやすい。
- リクエストごとのデータは `Request` と DTO に、サーバ全体の依存は `struct` のフィールドに分けると「状態」の所在が明確になる。非同期や共有ミュータブル状態は **コンテキストと競合**に注意。
- `httptest` と小さな `App` 型で、ネットワークなしで入口の振る舞いを固められる。

---

## 8. 明日の布石（次のテーマ候補を 2 つ）

**目安時間（分）: 2**

1. **ミドルウェアの合成と `context` 値の受け渡し**（認可・ロギング・リカバリの順序とテスト）
2. **`database/sql` またはリポジトリ層との境界**（トランザクション、`Context` キャンセル、handler からはインターフェースのみ見せる）

---

## 付録: `.gitignore` について

本日のフォルダでは `tutorial/` をリポジトリ管理対象外にする `.gitignore` を置く（ハンズオン生成物用）。ルートの `.gitignore` に `tutorial/` がある場合も、日付フォルダ単体での教材再現のために同様の記述を置いておくとよい。
