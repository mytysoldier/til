# Go: DB / Repository の入口（1日分教材）

**目安所要時間（コア）: 約60分**（追加課題は別）

---

## 1. 今日のゴール

**目安時間（分）: 2**

ローカルで SQLite に接続し、`database/sql` と **Repository 層**を分けた最小の HTTP 直呼び出し（GET）が動く状態にする。API（ハンドラ）は SQL を書かない。永続化ファイル（`app.db`）が生成され、同じ手順を繰り返しても起動できること（冪等に近い seed）を確認する。

---

## 2. 事前知識チェック（3問）

**目安時間（分）: 5**

### Q1. `database/sql` の `sql.DB` は何を表すか

- **問い**: 接続1本？ プール？  
- **答え**: **接続プール**の抽象。`Open` 直後は必ずしも TCP 接続が張られているとは限らず、初回の `Ping` やクエリで実際の接続が使われる（ドライバ依存）。公式の注意点として「Open は接続エラーを返さないことがある」ため、本番では `PingContext` 等で検証するパターンが推奨される（[database/sql Overview](https://pkg.go.dev/database/sql)）。

### Q2. Repository パターンで「薄くしたい」のはどこか

- **問い**: HTTP の Status Code を決めるのは Repository？  
- **答え**: 原則 **HTTP / ユースケース側**。Repository は永続化の責務（クエリ・トランザクション）に集中し、「見つからない」を `sql.ErrNoRows` や独自エラーで返す。404 かどうかはハンドラやサービスが判断する。

### Q3. なぜ API ハンドラに `sql.DB` を渡さないのがよいことが多いか

- **問い**: 依存を減らす理由は？  
- **答え**: **テスト可能性**と**置き換え**（インメモリ実装や別ストレージ）。ハンドラは「ユーザーを取得する関数（インターフェース）」だけ知ればよい。

---

## 3. 理論（重要ポイント）

**目安時間（分）: 12**

### 3.1 `database/sql` は「ドライバとセット」で使う

公式: *The sql package must be used in conjunction with a database driver.*（[database/sql](https://pkg.go.dev/database/sql)）  
標準ライブラリだけでは DB に話せないため、**ドライバは最低1つ**必要。今回はローカル完結のため **SQLite + ドライバ1パッケージ**に限定する。

- **よくある誤解**: `import "database/sql"` だけで SQLite に繋がる。  
- **落とし穴**: `_ "modernc.org/sqlite"` の**匿名 import**でドライバを登録し忘れると `sql: unknown driver` になる。

### 3.2 `sql.Open` のエラーは「設定ミス寄り」、接続可否は `PingContext` で

- **よくある誤解**: `Open` が nil err なら DB に届いている。  
- **落とし穴**: **まず err を見る**。DSN が壊れていれば `Open` で分かる一方、**疎通不可**（ファイル権限・ディスク・ネットワーク）は `Ping` / 初回クエリまで表面化しないことがある。

### 3.3 Repository は「永続化の境界」

- **役割**: テーブルに対応する読み書き、トランザクション境界の一部。  
- **よくある誤解**: Repository = 全部のビジネスロジック。  
- **落とし穴**: Repository が HTTP やログの詳細に踏み込むと、層が溶けてテストが重くなる。

### 3.4 比較観点（今日は1つだけ）: **依存の向き**

| 選択 | 内容 |
|------|------|
| **A. ハンドラが `*sql.DB` を持つ** | 早いが、SQL が handler に散らばりやすい |
| **B. handler → interface（Repository）← 実装** | ひとまわり増えるが、**API 層が SQL を知らない**状態を維持しやすい |

**今日の進め方**: 思想は **B**（責務分離）だが、コード量を抑えるため **ハンドラは具象の `*repo.UserRepository` に依存**して始める。テストは実 DB（インメモリ SQLite）を使うので、**最初から interface が無くても**置き換えの旨味を味わえる。規模が増えたら `type UserReader interface { GetByID(...) }` のように切り出すのが実務では一般的。

### 3.5 コンテキスト付きメソッドを優先

`QueryRowContext` / `PingContext` など、**キャンセル・タイムアウトを伝搬**できる。HTTP ハンドラでは **`r.Context()` を起点**に、Repository へ同じ系統の `ctx` を渡す（クライアント切断で下流も打ち切れるようにする）。キャンセル非対応ドライバでは完了まで待つ場合がある、という注意が公式にもある（[database/sql](https://pkg.go.dev/database/sql)）。

### 3.6 エラーと `sql.ErrNoRows`（型・比較）

- **落とし穴**: `err == repo.ErrNotFound` だけに頼ると、`fmt.Errorf("%w", repo.ErrNotFound)` で包んだ場合に失敗する。Repository 境界では **`errors.Is(err, repo.ErrNoRows)` / `errors.Is(err, repo.ErrNotFound)`** を使う。  
- **落とし穴**: `QueryRow` は行が無いとき **`sql.ErrNoRows`**。`Scan` の先の型が合わない・列数が違う場合は別エラーになり、どちらも「not found」と混同しない。

### 3.7 並行と状態（`*sql.DB` / テスト）

- `*sql.DB` は**複数ゴルーチンからの利用に耐える**設計だが、アプリ側の**可変カウンタや map を Repository で共有する**とデータ競合になる（今回は触れない）。  
- `go test -parallel` と**同じインメモリ DB 名**を複数テストで使うと壊れるため、テストでは **DSN をテスト名ベースで一意**にするか、並列を避ける。

---

## 4. ハンズオン（手順）

**目安時間（分）: 35**

**成果物**: `tutorial/` 以下に、「HTTP GET `/users/{id}` → Repository → SQLite」の**動く最小構成**と、**テスト1本**。

**前提**: Go 1.21+ 推奨。作業ディレクトリは教材を置いた日のフォルダ（例: 本ファイルと同じ階層）を想定。**すでに Git 管理下なら**ステップ0の `.gitignore` はそのリポジトリのルート、**個人用のメモだけなら**教材と同じディレクトリに置けばよい（迷ったら教材と並べる）。

### ステップ0: `tutorial` 用の `.gitignore`（学習用をリポジトリに混ぜない）

**やること**

1. `tutorial` フォルダは**まだ作らなくてよい**。**Git で管理しているディレクトリ**のうち、教材の `tutorial/` を置く場所の親に `.gitignore` を置く（多くの場合、教材ファイルと同じ階層でよい）。  
2. 中身に次を書く（`tutorial/` 配下を丸ごと除外）。

```gitignore
# 学習用ハンズオン（教材手順で生成）
tutorial/
```

**確認方法（期待される挙動）**

- `tutorial/` を作成したあと、`git check-ignore -v tutorial/go.mod` のようにパスが無視対象になる（Git を使っていない場合はスキップしてよい）。

---

### ステップ1: モジュールとフォルダ作成

**やること**

```bash
mkdir -p tutorial/cmd/server tutorial/internal/repo
cd tutorial
go mod init example.com/userapp
```

**確認方法**

- `go env GOMOD` が `.../tutorial/go.mod` を指す（絶対パスでよい）。
- `ls` で `cmd/server` と `internal/repo` がある。

---

### ステップ2: SQLite ドライバを追加する（標準のみでは DB に届かないため）

[`database/sql` はドライバ必須](https://pkg.go.dev/database/sql)。ローカルで **CGO なし**で扱いやすい **`modernc.org/sqlite`** を1つだけ使う。

```bash
go get modernc.org/sqlite@latest
go mod tidy
```

コード側ではブランケット import でドライバ名を登録する。

**よくあるつまずき**

- `verifying module: ... sum.golang.org: ... operation not permitted` や企業プロキシで失敗する場合は、`GOPROXY`（例: `https://proxy.golang.org,direct`）や社内ドキュメントを確認する。  
- オフラインでも、一度成功した `go.sum` があれば再現しやすい。

**確認方法**

- `go.mod` に `require modernc.org/sqlite` が追加されている。

---

### ステップ3: Repository 実装（SQL はここだけ）

`tutorial/internal/repo/user_repo.go` を作成。

```go
package repo

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
)

var ErrNotFound = errors.New("user not found")

type User struct {
	ID   int64
	Name string
}

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) GetByID(ctx context.Context, id int64) (User, error) {
	const q = `SELECT id, name FROM users WHERE id = ?`
	var u User
	err := r.db.QueryRowContext(ctx, q, id).Scan(&u.ID, &u.Name)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, fmt.Errorf("%w", ErrNotFound)
	}
	if err != nil {
		return User{}, err
	}
	return u, nil
}
```

**確認方法**

- `go build ./internal/repo/` が通る（この時点では `cmd/server` は未作成でもよい）。

---

### ステップ4: `main` で DB 初期化・HTTP・Repository 注入

`tutorial/cmd/server/main.go` を作成。DSN は **`app.db`**（カレントディレクトリに SQLite ファイルができる）。初回検証後に壊れたと思ったら **`rm app.db` で消して再実行**できる。

```go
package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"example.com/userapp/internal/repo"

	_ "modernc.org/sqlite" // ドライバ登録
)

func main() {
	const dsn = "app.db"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		log.Fatal("ping:", err)
	}

	if _, err := db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL
	);`); err != nil {
		log.Fatal("schema:", err)
	}
	// 何度実行しても同じ状態に寄せる（既にあれば無視）
	if _, err := db.ExecContext(ctx, `INSERT OR IGNORE INTO users(id, name) VALUES (1,'Alice'),(2,'Bob');`); err != nil {
		log.Fatal("seed:", err)
	}

	users := repo.NewUserRepository(db)
	mux := http.NewServeMux()
	mux.HandleFunc("/users/", func(w http.ResponseWriter, r *http.Request) {
		idStr := strings.TrimPrefix(r.URL.Path, "/users/")
		idStr = strings.Trim(idStr, "/")
		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil {
			http.Error(w, "bad id", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
		defer cancel()
		u, err := users.GetByID(ctx, id)
		if errors.Is(err, repo.ErrNotFound) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		if err != nil {
			http.Error(w, "internal", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		if _, err := w.Write([]byte(u.Name)); err != nil {
			log.Printf("write: %v", err)
		}
	})

	addr := ":8080"
	if v := os.Getenv("PORT"); v != "" {
		addr = ":" + v
	}
	log.Println("listen", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
```

**確認方法**

```bash
cd tutorial
go run ./cmd/server
```

別ターミナルで:

```bash
curl -s http://localhost:8080/users/1
# 期待: Alice

curl -i http://localhost:8080/users/99
# 期待: HTTP/1.1 404 かつ not found のようなボディ

curl -i http://localhost:8080/users/bad
# 期待: 400 系（数値以外）
```

**動かないとき（初心者が詰まりやすい箇所）**

- **`address already in use`**: 8080 が他プロセスに取られている。`PORT=18080 go run ./cmd/server` とし、`curl localhost:18080/users/1` とするか、競合プロセスを止める。  
- **二重起動**: 同じ `app.db` を掴んだままロックで詰まることがある。その場合もプロセスを一つにする。

**設計メモ（なぜこの形か）**: `sql.DB` の生成は `main`、**問い合わせの手続きは Repository**、**HTTP の意味（404 等）は handler**。`Write` の失敗はクライアント切断などで起こり得るため **ログに残す**（実務ではメトリクスやレベル付きログに接続する）。

---

### ステップ5: テスト1本（インメモリ SQLite）

`go test` に **外部モックライブラリは使わず**、インメモリ DB で Repository を検証する。DSN のファイル名部分を **テスト名から生成**し、将来 `t.Parallel()` を付けても衝突しにくくする（サブテスト名の `/` は `_` に置換）。

`tutorial/internal/repo/user_repo_test.go` を作成。

```go
package repo_test

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"testing"

	"example.com/userapp/internal/repo"

	_ "modernc.org/sqlite"
)

func TestUserRepository_GetByID(t *testing.T) {
	ctx := context.Background()
	memName := strings.ReplaceAll(t.Name(), "/", "_")
	dsn := fmt.Sprintf("file:%s?mode=memory&cache=shared", memName)

	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })

	if _, err := db.ExecContext(ctx, `CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, `INSERT INTO users(id,name) VALUES (1,'Alice');`); err != nil {
		t.Fatal(err)
	}

	r := repo.NewUserRepository(db)
	u, err := r.GetByID(ctx, 1)
	if err != nil {
		t.Fatal(err)
	}
	if u.ID != 1 || u.Name != "Alice" {
		t.Fatalf("got %+v", u)
	}

	_, err = r.GetByID(ctx, 404)
	if err == nil {
		t.Fatal("expected error")
	}
	if !errors.Is(err, repo.ErrNotFound) {
		t.Fatalf("expected ErrNotFound wrap, got %v", err)
	}
}
```

**確認方法**

```bash
cd tutorial
go test ./internal/repo -v -count=1
# 期待: PASS
```

---

### ここまでできれば今日のゴール達成

- SQLite に接続し `PingContext` で疎通確認できている  
- Repository に SQL が閉じ、HTTP ハンドラは Repository だけ呼ぶ  
- `go test` が1つ通る  
- 失敗時に **ポート競合**や **`app.db` のリセット**を疑える

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）: 5〜15（任意）**

### Easy（5〜10分）

**課題**: `GET /health` を追加し、`PingContext` で疎通を返す。

**回答例**

```go
mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 1*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		http.Error(w, "down", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
})
```

---

### Medium

**課題**: `Create(ctx context.Context, name string) (int64, error)` を Repository に追加し、`POST /users` で受け取る（本文はプレーン `name` 文字列だけでよい）。

**回答例（要点）**

```go
// repo
func (r *UserRepository) Create(ctx context.Context, name string) (int64, error) {
	res, err := r.db.ExecContext(ctx, `INSERT INTO users(name) VALUES (?)`, name)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}
```

```go
// main: POST /users は最大読み取りサイズを決めて io.ReadAll し、 strconv.ParseInt 不要なら strings.TrimSpace のみでもよい（エラー処理は省略しないこと）
```

---

### Hard

**課題**: `GetByID` をトランザクション内で呼ぶ必要が**ない**理由と、逆に **`sql.Tx` が必要になる例** を1つずつ短文で書く（実装不要）。

**回答例（文章）**

- **不要な理由**: 単一 `SELECT` は原子性が保たれ、`sql.ErrNoRows` の扱いもシンプル。  
- **`Tx` が必要な例**: 口座間送金で `UPDATE` を2回行う場合など、複文を **まとめてコミット/ロールバック**したいとき（`BEGIN`〜`COMMIT`）。読取分離レベルを揃えたい読み取り専用トランザクションもあるが、それは別日の論点。

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）: 4**

1. **社内向けツールの CRUD**: 認可は上流、Repository はユーザ・部署テーブルを **ID で引く処理**だけに閉じ、ハンドラは JSON とステータスに専念する。  
2. **バッチ／ワーカー**: HTTP が無くても、同じ Repository を cron や SQS ワーカーから呼び出し、**ドメイン関数は共通化**しやすい。  
3. **観運用**: 「DB が遅い・落ちている」は `/health` の `Ping` と、Repository レイヤーでの **クエリレイテンシメトリクス**（サービス側で計測）を分離して見る、`sql.Rows`/`rows.Close()` 漏れを静的解析やレビューで拾う、といった運用に接続する。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）: 2**

1. `database/sql` は**ドライバとセット**で、`*sql.DB` 上で `PingContext` と `QueryRowContext` により **Context を通した打ち切り**を設計する。  
2. Repository は SQL と `Scan` を閉じ、HTTP は **`errors.Is` で業務エラー/not found を解釈**する。具象型からでも責務分離は学べ、成長したら interface に切り出せる。  
3. **テストはインメモリ SQLite + 一意 DSN**で、並行テストにも備えやすくする。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）: 1**

1. **`sql.Tx` と Unit of Work**: 複数テーブル更新を1トランザクションにまとめるリポジトリ設計。  
2. **マイグレーション（`goose` / `golang-migrate` など）**: 手書き `CREATE TABLE` から、バージョン管理されたスキーマへ（※明日はライブラリ導入の是非も含めて比較してよい）。

---

## 参考（公式）

- [package database/sql](https://pkg.go.dev/database/sql)  
- [SQL Drivers 一覧へのリンク（公式 short link）](https://golang.org/s/sqldrivers)  
- [SQL の使い方例（Wiki）](https://golang.org/s/sqlwiki)
