# Go: APIの入口（1日教材）

> **参照先（公式）**: [net/http.ServeMux](https://pkg.go.dev/net/http#ServeMux) · [Request.PathValue](https://pkg.go.dev/net/http#Request.PathValue) · [encoding/json](https://pkg.go.dev/encoding/json) · [ルーティング改善（Go 1.22）](https://go.dev/blog/routing-enhancements) · [httptest](https://pkg.go.dev/net/http/httptest)

---

## 1. 今日のゴール

**目安時間（分）: 2**

`net/http` だけで「ルーティング → ハンドラ → JSON 応答」まで通し、API の外側に DTO（転送用の形）の境界を意識したミニ API を起動できるようにする（**コア手順 約 50 分 + 余白 約 10 分**、合計 **60 分前後** の想定）。

---

## 2. 事前知識チェック（3問）※回答付き

**目安時間（分）: 3**

1. **Q. Go で HTTP サーバを起動する代表的な関数は？**  
   **A.** `http.ListenAndServe(addr, handler)`。第2引数が `nil` のときは `DefaultServeMux` が使われる（[ListenAndServe](https://pkg.go.dev/net/http#ListenAndServe)）。

2. **Q. `json.Marshal` と `json.NewEncoder(w).Encode(v)` の主な違いは？**  
   **A.** 前者は `[]byte` を返し、後者は `io.Writer` に直接流す。HTTP では **先に `[]byte` 化（Marshal）してから書く**と、**ステータス確定前に失敗**を捕捉しやすい、という区別が実務では効く場面が多い（[Marshal](https://pkg.go.dev/encoding/json#Marshal)）。

3. **Q. 「DTO」と聞いて、API の文脈でまず想定する役割は？**  
   **A.** **クライアントとの契約**（入出力の形）。ドメイン内部のモデル（DB・ロジック用）と **同じ型を無理に共有しない** ほうが、変更の影響を切り分けやすい、という入り口の理解で十分。

---

## 3. 理論（重要ポイント）

**目安時間（分）: 12**

1. **ルーティング（`ServeMux`）は「表に出る設計図」**  
   どの URL・メソッドをどの関数に配るかが読み手に伝わる。Go 1.22 以降の `http.ServeMux` は `GET /items/{id}` のように **メソッド** と **パス値** をパターンに書ける（[ServeMux](https://pkg.go.dev/net/http#ServeMux)）。  
   - **よくある誤解**: 「ハンドラ内で毎回 `r.Method` を if するのが定番」→ **パターン側で分けられる**なら、HTTP 的にも読みもスッキリする。

2. **ハンドラ（`http.Handler` / `HandlerFunc`）の責務は「HTTP の入口」**  
   主に: リクエスト解釈（パス・クエリ・（必要なら）ボディ）→ **応答用のデータを組み立てる** → ステータスとボディを返す。  
   - **落とし穴**: **ハンドラに**ドメインの複雑なルールを全部詰め込むと、テストも再利用もしづらい。**小さなプロジェクトでも「抜き出し可能」な一歩**を意識しておく。

3. **JSON: `WriteHeader` より前に失敗を握る**  
   実務で多い形は、**`json.Marshal` で失敗 → まだ何も返していなければ 500 へ分岐**、成功したら `Content-Type` → `WriteHeader` → `Write`。**先に 200 の `WriteHeader` を呼んでから `Encode` に失敗**すると、クライアントには不整合が残り、**正しい 500 も返しにくい**（[ResponseWriter](https://pkg.go.dev/net/http#ResponseWriter)）。

4. **並発の前提（`net/http` の事実知識）**  
   サーバは**リクエストごとに別 goroutine**でハンドラを動かしうる。だから**ハンドラ内で共有変数（カウンタ・キャッシュ等）をそのまま素朴に触る**とデータ競合の原因になる。  
   - **落とし穴（状態）**: 「小さいから大丈夫」は禁物。**並行アクセスを伴う可変のグローバル**をハンドラから直接触らない。今日のコードは `mux` 登録の読み取り専用で、リクエスト横断の可変を置かない。

5. **DTO の境界: 「外に見せる形」と「中の形」を分ける候補**  
   例: 内部 `Item` のフィールド名や JSON 名が将来変わるとき、API 用 `ItemResponse` だけ `json` タグを固定できる。  
   - **今日の比較観点（1 つに絞る）**: *「1 型ですべて表現」か「レスポンス専用型を切る」か* → 小さな API では 1 型でも動くが、**拡張や外部公開**を考えると **レスポンス用を分ける**と変更に強い。今日は意識のため **別名の Response 型**を置く。

6. **設計上の「なぜこの選択か」（今日の 1 例）**  
   **選択**: `http.NewServeMux()` を**明示**し、`DefaultServeMux` を使わない。  
   **理由**: テストで同じ `mux` を差し替えたり、登録箇所が追いやすい（グローバル登録の散在を避ける）。

7. **`PathValue` と Go のバージョン**  
   `GET /items/{id}` なら `r.PathValue("id")`（[PathValue](https://pkg.go.dev/net/http#Request.PathValue)）。  
   - **落とし穴**: ローカルで `go` のバージョンが **1.22 未満**だと、新パターンや `PathValue` の挙動が期待とずれる。`go 1.22` 以上のツールチェーンを使う。

8. **テスト: `NewServer` と `ResponseRecorder` の使い分け**  
   - `httptest.NewServer`: **実 HTTP**で結合度が上がる（ポート開く）。  
   - `httptest.NewRecorder` + `ServeHTTP`:**ゼロ**で**速く**、ルーティングとハンドラの単体寄り。今日は**両方**触る（下記手順参照）。

---

## 4. ハンズオン（手順）

**目安時間（分）: 32**

**成果物（最小）**: `GET /api/health` が JSON、`GET /api/items/{id}` が DTO ベースの JSON を返す HTTP サーバ。**モジュールは `tutorial` 配下**に作る。外部ライブラリは使わない。

**先に 1 分だけ**（リポジトリのルート想定）: `tutorial` を作業用に置くなら、誤コミットを防ぐ **`.gitignore` をルートに追加**する。

```gitignore
# 学習用ハンズオンワークスペース
tutorial/
```

**トラブルシューティング（先に目を通す）**

- **`go version` が 1.22 未満** → ハンズオン外でツールチェーンを上げる（[Install](https://go.dev/doc/install)）。この教材の `ServeMux` パターンは **1.22+ 前提**。
- **`bind: address already in use`（:8080 使用中）** → 別ターミナルで起動中の `go run` を止めるか、`addr := ":18080"` などに変え、以降の `curl` もポートを揃える。
- **`cd` 忘れ** → 次の `go` コマンドは **必ず** `.../tutorial/api-mini` をカレントにしてから。迷ったら `pwd` でパスを確認。

---

### ステップ1: ディレクトリと go.mod

**やること**

```bash
mkdir -p tutorial/api-mini
cd tutorial/api-mini
go version
# go version go1.22.x 以上であることを確認
go mod init example.com/api-mini
go mod edit -go=1.22
```

**確認方法**

- `go mod edit -print` または `cat go.mod` に `go 1.22` 以上の行があり、`module example.com/api-mini` がある。

---

### ステップ2: DTO（レスポンス専用）を `dto.go` に定義

**やること**  
`tutorial/api-mini/dto.go` を新規作成。JSON のキー名を API 契約として固定する。

```go
package main

// HealthResponse はヘルスチェック用 DTO
type HealthResponse struct {
	Status string `json:"status"`
}

// ItemResponse はクライアント向けの Item 表現
type ItemResponse struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}
```

**確認方法**

- ファイルが保存され、`gofmt` 済み（`gofmt -w dto.go` 可）。

---

### ステップ3: JSON 書き出し用ヘルパ `writeJSON`（`json.go`）

**やること**  
`tutorial/api-mini/json.go` を追加。**`Marshal` → `WriteHeader` → `Write`**の順にし、JSON 化に失敗した時点でまだレスポンスを送っていない扱いにできる（上記理論3）。

```go
package main

import (
	"encoding/json"
	"log"
	"net/http"
)

func writeJSON(w http.ResponseWriter, status int, v any) {
	b, err := json.Marshal(v)
	if err != nil {
		log.Printf("json marshal: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if _, err := w.Write(b); err != nil {
		log.Printf("write body: %v", err)
	}
}
```

**確認方法**

- ステップ4の `main.go` を置いた**後**に `go vet ./...`（パッケージ `main` に `func main` が揃うまで、vet は後回しでよい）。

---

### ステップ4: ルーティングとハンドラ `main.go`

**やること**  
`tutorial/api-mini/main.go` を作成。`http.NewServeMux()` に **メソッド付きパターン**で登録。`/api/items/{id}` は `PathValue` で取得。

```go
package main

import (
	"log"
	"net/http"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/health", handleHealth)
	mux.HandleFunc("GET /api/items/{id}", handleGetItem)

	addr := ":8080"
	log.Printf("listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, HealthResponse{Status: "ok"})
}

func handleGetItem(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	// 例: 明らかに不正なプレースホルダだけ弾く（DTO に進む前の入力ガード）
	if id == "invalid" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}
	// 実務では DB 取得など。ここでは DTO 組み立てのデモ
	writeJSON(w, http.StatusOK, ItemResponse{ID: id, Name: "sample"})
}
```

**確認方法**

- カレントが `tutorial/api-mini` であることを確認してから: `go run .`（別ターミナルで次を実行）:

```bash
curl -sS http://127.0.0.1:8080/api/health
# 期待: {"status":"ok"}（末尾に改行が付くことがあるが問題ない）

curl -sS http://127.0.0.1:8080/api/items/abc-123
# 期待: {"id":"abc-123","name":"sample"}

curl -i -sS http://127.0.0.1:8080/api/items/invalid
# 期待: 400 かつ JSON（error: invalid id）
```

- **補足**: パスパラメータが必ず存在するルートの場合、空 `id` は来にくい。上記は **DTO を返す前の入力ガード**をハンドラに置く、という意図の例。  
- **補足（型 / 一貫性）**: エラー用に `map[string]string` を直書きした。拡張するなら、**エラー専用の struct** に `json:"error"` などを付けて揃えるとクライアント向け形が一貫しやすい（今日は入り口のため省略可）。

---

### ステップ5: テスト（`httptest`、最低 2 本）

**やること**  
`tutorial/api-mini/main_test.go` を追加。

- **`TestHealth`**: `httptest.NewServer` で**実接続**に近い形を確認。  
- **`TestGetItem`**: `httptest.NewRequest` + `httptest.NewRecorder` で、**同じ `mux` に対して**ルートと DTO、ステータスを**高速に**検証（[NewRecorder](https://pkg.go.dev/net/http/httptest#NewRecorder)）。

```go
package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealth(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", handleHealth)
	ts := httptest.NewServer(mux)
	defer ts.Close()

	res, err := http.Get(ts.URL + "/api/health")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status = %d", res.StatusCode)
	}
	if ct := res.Header.Get("Content-Type"); ct != "application/json; charset=utf-8" {
		t.Fatalf("Content-Type = %q", ct)
	}
	var got HealthResponse
	if err := json.NewDecoder(res.Body).Decode(&got); err != nil {
		t.Fatal(err)
	}
	if got.Status != "ok" {
		t.Fatalf("unexpected body: %#v", got)
	}
}

func TestGetItem_ByRecorder(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/items/{id}", handleGetItem)

	req := httptest.NewRequest(http.MethodGet, "/api/items/abc-123", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %q", rec.Code, rec.Body.String())
	}
	var got ItemResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got.ID != "abc-123" || got.Name != "sample" {
		t.Fatalf("unexpected: %#v", got)
	}
}
```

**確認方法**

```bash
cd tutorial/api-mini
go test -race ./...
# 期待: PASS（-race は共有状態の有無の実務的な安心材料。今日のコードは競合源なし想定）
```

**落とし穴（テスト）**  
`NewRequest` の URL は**パスだけ**（`?` は付けてよいが、**ホスト有りのフル URL は避ける**）。`ServeHTTP` には **`*http.Request` がそのまま**渡る。

---

### 本日のゴール達成ライン

**ここまでできれば今日のゴール達成**

- [ ] ルートに `.gitignore` で `tutorial/` を除外した  
- [ ] `go run .` で JSON API が返る  
- [ ] DTO として `ItemResponse` / `HealthResponse` を置いた  
- [ ] `go test -race ./...` が通る  

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）: 5**（難度に応じて **Easy 5〜10 分**、それ以外は参考）

### Easy（5〜10 分）

`POST /api/echo` で JSON ボディ `{"message":"hi"}` を受け、同じ形で返す。`json.Decoder` の `DisallowUnknownFields()` は任意。**`r.Body` は `defer r.Body.Close()` しない**（[*Request* の契約: `Server` 側のハンドラは Body を閉じない](https://pkg.go.dev/net/http#Request)）が基本。

**回答例**（新規/追記のイメージ）

```go
// dto に追加
type EchoRequest struct {
	Message string `json:"message"`
}
type EchoResponse struct {
	Message string `json:"message"`
}
```

```go
func handleEcho(w http.ResponseWriter, r *http.Request) {
	var req EchoRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bad json"})
		return
	}
	writeJSON(w, http.StatusOK, EchoResponse{Message: req.Message})
}
// mux.HandleFunc("POST /api/echo", handleEcho)
```

### Medium

`handleGetItem` 内の「仮データ」を `func findItem(id string) (ItemResponse, bool)` に切り出し、ハンドラは **HTTP のみ**にする。`bool` を 404 にマッピング。

**回答例（抜粋）**

```go
func findItem(id string) (ItemResponse, bool) {
	if id == "unknown" {
		return ItemResponse{}, false
	}
	return ItemResponse{ID: id, Name: "sample"}, true
}

func handleGetItem(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	item, ok := findItem(id)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	writeJSON(w, http.StatusOK, item)
}
```

### Hard

`http.Handler` を返す高階関数 `withLogging(next http.Handler) http.Handler` を書き、メソッドとパスを 1 行ログに出す。`main` では `mux` を *ラップ*するか、特定ルートだけに適用する、のどちらかを選び理由を 1 行メモ。

**回答例（抜粋）**

```go
func withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s", r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
	})
}
// 例: log.Fatal(http.ListenAndServe(addr, withLogging(mux)))
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）: 3**

1. **Kubernetes / ALB 向けの生存確認**  
   デプロイ先が **liveness** / **readiness** なら、パスはチーム慣習（`/healthz` / `/readyz` 等）に合わせ、**本番**では依存（DB など）の有無で **ready だけ厳しめ**、という分離が典型。今日の DTO 固定・JSON は「プローブが JSON 前提の監視基盤」にもそのまま流用できる。

2. **社内外に公開する REST の「契約の先出し」**  
   フロントや連携先と **OpenAPI 以前に**、ルート＋`json` タグ付き DTO を先に固めると、**破壻的変更**の有無の議論がしやすい（フィールド名が契約の中心）。

3. **モノリス前の“境界の薄い”マイクロサービス**  
   ドメインを切り出す前に **`net/http` だけ**で境界APIを切り、あとから **ミドルウェア（認証・トレース）**や **永続**を足す。外部フレームワーク無しのまま、**`httptest` で契約を回帰**しやすい足場になる。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）: 2**

- `ServeMux` のメソッド付きルートと `PathValue` で、**入口の意図をパターンに表現**できる。  
- **DTO は「外との契約」**として切り、ハンドラは HTTP とデータ組み立ての境界に置く。**並行**では共有可変に注意。  
- **`Marshal` 成功後に** `Header` / `WriteHeader` / `Write` とし、**テストは Server と Recorder の両方**で形を保証する。

---

## 8. 明日の布石（次のテーマ候補2つ）

**目安時間（分）: 1**

1. **ミドルウェア（`Handler` の合成）** — ロギング、`Recover`、リクエスト ID、CORS（必要な範囲）の導入。  
2. **永続層の入口** — `database/sql` か軽量ドライバで、`findItem` を DB 参照に置き換え、**interface 越しにテスト**する道筋。

---

**合計目安: 2 + 3 + 12 + 32 + 5 + 3 + 2 + 1 = 60 分**
