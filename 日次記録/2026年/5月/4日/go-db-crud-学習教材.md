# Go: DB接続とCRUD（1日分の学習教材）

公式ドキュメント: [database/sql パッケージ](https://pkg.go.dev/database/sql)、[Go とデータベースの使い方](https://go.dev/doc/database/open-a-database-connection)

---

## 1. 今日のゴール（1〜2行）

**目安時間（分）:** 1

SQLite に接続し、HTTP ハンドラ経由でレコードを **INSERT / SELECT / UPDATE（`PATCH`）** できる最小 API をローカルで動かし、ハンドラと DB 操作の責務を分けた構成を体験する。**Store のユニットテストが1本通る状態**まで持っていければ、より実務に近い区切りになる。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間（分）:** 5

質問に答えたあと、下の「解答」を見て復習してください。

**Q1.** `database/sql` の `DB` は「接続」そのものではなく、何を表すオブジェクトですか？

- **解答:** 接続プールを管理するオブジェクトです。複数ゴルーチンから **同じ `*sql.DB` を共有して並行利用してよい**（公式にスレッドセーフ）。クエリ実行時に内部で接続を借りて返します。毎回 `Open` し直すのではなく、アプリ起動時に一度 `Open` して使い回すのが一般的です。

**Q2.** `QueryRow` で行が見つからないとき、どんなエラーが返りますか？

- **解答:** `sql.ErrNoRows` です（`Scan` の結果として）。「0件」と「DB障害」を区別したいハンドラでは、`errors.Is(err, sql.ErrNoRows)` で判定します。`fmt.Errorf("...: %w", err)` でラップした場合も、通常は `errors.Is` で追到できます。

**Q3.** HTTP ハンドラ内に SQL を直書きすると、設計上どんな問題が起きやすいですか？

- **解答:** テストがしづらい、SQL と HTTP の責務が混ざる、将来的に DB を差し替えにくい、といった問題が起きやすいです。保存・取得のロジックは関数や型にまとめ、ハンドラは「リクエスト/レスポンス」と「その関数呼び出し」に専念させると整理しやすいです。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間（分）:** 9

重要なポイントと、初学者が陥りやすい誤解です。

1. **`database/sql` は標準、`driver` は別パッケージ**  
   Go の標準ライブラリには SQLite/PostgreSQL の実装が入っていません。`database/sql` に「ドライバ」を匿名インポートで登録します。  
   - **よくある誤解:** 「標準だけで DB まで完結する」→ ドライバは必須です（本教材では SQLite 用に **1つだけ** 追加します）。  
   - **SQL インジェクション:** 値は必ずプレースホルダ `?` にバインドし、文字列連結で SQL を組まない（今回のコードはその形）。

2. **レイヤを分けると境界がはっきりする**  
   「HTTP（入出力）」と「永続化（DB）」の境界を、関数または `struct`（例: `UserStore`）で分離します。ハンドラは Store のメソッドを呼ぶだけにします。  
   - **落とし穴:** ハンドラに SQL をべた書きすると、後からトランザクションやモックテストを入れたくなったときに手戻りが大きくなります。

3. **`Open` だけでは接続確認にならない**  
   `sql.Open` は遅延接続です。接続確認には `db.PingContext(ctx)` などを使います。  
   - **よくある誤解:** `Open` が成功＝DB に届いている、とは限りません。  
   - **初期化と Context:** `NewUserStore` 内の Ping は「起動時チェック」なので `context.Background()` でよいことが多いです。リクエスト由来の期限は、`QueryContext(r.Context(), ...)` 側で効かせます。

4. **コンテキスト・並行・切断**  
   `QueryContext` / `ExecContext` はタイムアウトやキャンセルに対応します。HTTP では `r.Context()` を渡すと、**クライアント切断時に DB 待ちも打ち切りやすく**なります。  
   - **落とし穴:** `Exec` / `Query` の非 Context 版は、切断後もサーバが長くブロックしがちです。  
   **`*sql.DB` は複数ゴルーチンから共有してよい**一方、**`*sql.Tx` や開いた `*sql.Rows` をゴルーチン間で共有しない**のが前提です。`Rows` を回したあとは **`rows.Err()`** を確認するのが定石です（一覧 `Query` で必須。今回の `QueryRow` だけなら教材上は省略可）。

5. **エラーは「呼び出し元が意味を決める」**  
   Store は「DB で起きたこと」を `error` で返す。ハンドラは `sql.ErrNoRows` を 404 にするなど、HTTP の意味にマッピングします。  
   - **よくある誤解:** どの層でも `http.Error` してよい → 原則、**最終的な HTTP ステータスはハンドラ（または薄いミドルウェア）に寄せる**と見通しが良くなります。

6. **比較観点（今日は1つだけ）: SQLite と PostgreSQL**  
   - ローカル・単一ファイル・セットアップが軽いなら **SQLite**。  
   - チームで本番に近い挙動や、複数接続・拡張性を前提にするなら **PostgreSQL**。  
   今日は時間内に完走しやすい **SQLite** を採用します。

---

## 4. ハンズオン（手順）

**目安時間（分）:** 41（ステップ1〜6の合計。ステップ6は本日の「最低1テスト」として推奨）

**作業ディレクトリの約束:** パスに `tutorial` が無い場合は、**Git リポジトリのルート**（「日次記録」など、この教材と並ぶ親フォルダ）に移動してから進めてください。以降、`cd tutorial` と書いたら **常に `tutorial` フォルダの中**という意味です。

作業ルートに `tutorial` フォルダを用意し、そこにプロジェクトを作ります。  
**この教材では `tutorial` 以下にファイルは事前作成しません（学習者がステップで作成します）。**

### 準備: ルートに `.gitignore` を置く（目安: 2分）

プロジェクトのリポジトリ直下（`tutorial` と併存する親ディレクトリ）に `.gitignore` を作成し、次の1行を書きます。

```gitignore
tutorial/
```

**確認方法:** `git status` で `tutorial` 配下が追跡対象にならないこと。

---

### ステップ1: `tutorial` フォルダとモジュール作成（目安: 4分）

リポジトリのルートで:

```bash
mkdir -p tutorial
cd tutorial
go mod init example.com/userapi
```

**確認方法:** `pwd` の末尾が `tutorial` で、`go env GOMOD` に現在の `go.mod` の絶対パスが表示されること。

---

### ステップ2: 依存追加（SQLite ドライバ1つのみ）（目安: 4分）

**（まだ `tutorial` の中にいること）**

原則「外部ライブラリは使わない」に対し、DB は標準だけでは動かないため **ドライバのみ最小追加**します（CGO 不要の pure Go 実装）。

```bash
go get modernc.org/sqlite
```

**確認方法:** `go.mod` に `modernc.org/sqlite` が追加されていること。  
**なぜこの選択か:** ローカルで追加ツールを立てずに SQLite ファイル1つで完結でき、`database/sql` の公式パターンとそのままフィットします。

---

### ステップ3: Store 層（DB の責務）（目安: 10分）

`tutorial` 直下に `store` ディレクトリを用意し、`tutorial/store/user_store.go` を新規作成します。

```bash
mkdir -p store
```

```go
package store

import (
	"context"
	"database/sql"

	_ "modernc.org/sqlite"
)

type UserStore struct {
	db *sql.DB
}

func NewUserStore(dsn string) (*UserStore, error) {
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	if err := db.PingContext(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}
	return &UserStore{db: db}, nil
}

func (s *UserStore) Close() error {
	return s.db.Close()
}

func (s *UserStore) InitSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);`)
	return err
}

func (s *UserStore) InsertUser(ctx context.Context, name string) (int64, error) {
	res, err := s.db.ExecContext(ctx, `INSERT INTO users(name) VALUES(?)`, name)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (s *UserStore) GetUserNameByID(ctx context.Context, id int64) (string, error) {
	var name string
	err := s.db.QueryRowContext(ctx, `SELECT name FROM users WHERE id = ?`, id).Scan(&name)
	if err != nil {
		return "", err
	}
	return name, nil
}

func (s *UserStore) UpdateUserName(ctx context.Context, id int64, name string) error {
	res, err := s.db.ExecContext(ctx, `UPDATE users SET name = ? WHERE id = ?`, name, id)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return sql.ErrNoRows
	}
	return nil
}
```

**確認方法:** まだ `main` が無いので全体の `go build ./...` は **この時点では失敗してもよい**。代わりに `go build -o /dev/null ./store` が成功することを確認する（`tutorial` の中で実行）。  
**補足:** `UPDATE` で0行のときに `sql.ErrNoRows` を返すと、ハンドラ側で `GET` の「存在しない id」と同じ **`errors.Is(err, sql.ErrNoRows)` → 404** の流れにそろえやすい（`RowsAffected` の意味をハンドラに漏らさない）。

---

### ステップ4: ハンドラ層（HTTP の責務）（目安: 11分）

`tutorial/main.go` を作成します（`tutorial` 直下）。ハンドラは JSON とステータスコードのみ担当し、DB は `UserStore` に委譲します。`GET /user` に加え **`PATCH /user?id=…`** で名前を更新します。`/user` へ `GET` と `PATCH` の両方を載せるので、`HandleFunc` 内で **`r.Method` で振り分け**ます（同じパスに `HandleFunc` を2回登録すると後から登録した方だけが有効になるため）。

```go
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"time"

	"example.com/userapi/store"
)

type Server struct {
	store *store.UserStore
}

type createUserReq struct {
	Name string `json:"name"`
}

type createUserResp struct {
	ID int64 `json:"id"`
}

type getUserResp struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
}

type patchUserReq struct {
	Name string `json:"name"`
}

func (s *Server) CreateUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req createUserReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	id, err := s.store.InsertUser(r.Context(), req.Name)
	if err != nil {
		log.Printf("insert: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(createUserResp{ID: id})
}

func (s *Server) GetUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	idStr := r.URL.Query().Get("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil || id <= 0 {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	name, err := s.store.GetUserNameByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		log.Printf("select: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(getUserResp{ID: id, Name: name})
}

func (s *Server) PatchUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPatch {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	idStr := r.URL.Query().Get("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil || id <= 0 {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	var req patchUserReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	if err := s.store.UpdateUserName(r.Context(), id, req.Name); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		log.Printf("update: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func main() {
	st, err := store.NewUserStore("file:app.db?_pragma=foreign_keys(1)")
	if err != nil {
		log.Fatal(err)
	}
	defer st.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := st.InitSchema(ctx); err != nil {
		log.Fatal(err)
	}

	srv := &Server{store: st}
	http.HandleFunc("/users", srv.CreateUser)
	http.HandleFunc("/user", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			srv.GetUser(w, r)
		case http.MethodPatch:
			srv.PatchUser(w, r)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	addr := "127.0.0.1:8080"
	log.Printf("listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
```

**設計の選択肢と理由（1つ）:**  
**「Store を別パッケージにする」** ことを選びました。HTTP を伴わずに `store` パッケージだけを `go test` でき、永続化の境界がコード上もはっきりします。小規模でも、この分け方は実務でもそのまま拡張しやすいです。

**確認方法:** `tutorial` の中で `go build -o api .` が成功すること。

**なぜ `ErrNoRows` をラップしないか:** ハンドラで `errors.Is(err, sql.ErrNoRows)` と書けるようにし、「未登録＝404」と他の DB エラーを分けやすくするためです（ラップする場合は `%w` を使い、同じく `errors.Is` で判定します）。  
**補足（実務）:** ログには **生SQL全文ではなく** プレースホルダ＋安全に出せるパラメータだけを載せる運用が一般的です（PII ・秘密値の漏えい防止）。

---

### ステップ5: 動作確認（目安: 5分）

**ターミナルA** で（`tutorial` にいること）:

```bash
go run .
```

**ターミナルB** で:

```bash
curl -s -i -X POST http://127.0.0.1:8080/users \
  -H "Content-Type: application/json" \
  -d '{"name":"alice"}'
# 期待: HTTP/1.1 201 で、ボディに {"id":1} のような JSON

curl -s -i "http://127.0.0.1:8080/user?id=1"
# 期待: HTTP/1.1 200、{"id":1,"name":"alice"}

curl -s -i -X PATCH "http://127.0.0.1:8080/user?id=1" \
  -H "Content-Type: application/json" \
  -d '{"name":"alice2"}'
# 期待: HTTP/1.1 204 No Content（ボディなし）

curl -s -i "http://127.0.0.1:8080/user?id=1"
# 期待: HTTP/1.1 200、{"id":1,"name":"alice2"}
```

**確認方法:** INSERT で返った `id` で GET すると同じ名前が返ること。`PATCH` のあと GET で名前が更新されていること。存在しない `id` の GET / PATCH は 404 になること。`-i` でステータス行が確認できること。

**トラブルシュート:**

- **`bind: address already in use`:** 別プロセスが 8080 を使用している。`lsof -i :8080` で確認し、終了するか、`main` の `addr` を `8081` などに変更する。  
- **`database is locked`:** SQLite は書き込みを直列化する。複数プロセスから同じ `app.db` を開いていないか確認する。前回の `go run` が残っていないかも確認する（Ctrl+C で止める）。  
- **二回目に `id` が 1 からではない:** `app.db` が残っているため。初期状態にしたい場合は `tutorial` 内で `rm app.db` してからサーバを再起動する（**本番では削除ではなくマイグレーション運用**が前提）。

---

### ステップ6: 最小テスト1本（目安: 5分）

`tutorial/store/user_store_test.go` を作成します。メモリ DSN は **`modernc.org/sqlite` では `file::memory:?cache=shared`** が無難です。

```go
package store_test

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	"example.com/userapi/store"
)

func TestInsertAndGet(t *testing.T) {
	t.Parallel()
	ctx := context.Background()

	s, err := store.NewUserStore("file::memory:?cache=shared")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })

	if err := s.InitSchema(ctx); err != nil {
		t.Fatal(err)
	}

	id, err := s.InsertUser(ctx, "bob")
	if err != nil {
		t.Fatal(err)
	}

	name, err := s.GetUserNameByID(ctx, id)
	if err != nil {
		t.Fatal(err)
	}
	if name != "bob" {
		t.Fatalf("name = %q", name)
	}

	_, err = s.GetUserNameByID(ctx, 99999)
	if err == nil {
		t.Fatal("expected error for missing id")
	}
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("want sql.ErrNoRows, got %v", err)
	}
}

```

**確認方法:** `tutorial` で `go test ./...` が PASS すること。

**このテストで見ている実務的な点:** INSERT→取得の一連、`sql.ErrNoRows` の区別（型・エラー状態）、並行実行に備えた `t.Parallel()`（DB はメモリの独立インスタンスなので衝突しにくい）。

---

**ここまでできれば今日のゴール達成:**  
SQLite に接続し、`UserStore` に INSERT/SELECT/UPDATE を閉じ込め、`main` のハンドラから呼び出せる API（**`PATCH` 含む**）がローカルで動き、**`go test ./...` が通る**状態なら完了です。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）:** 5〜25（Easy だけ 5〜10、Medium/Hard は任意）

### Easy（5〜10分）

**課題:** `GET /user` で `id` が無いとき、400 を返す理由をコメント1行で `GetUser` に書く。  
**回答例:**

```go
// id が無いリクエストは契約違反なので 400。未登録の id は別概念として 404。
```

（コード変更なし・理解確認でも可）

---

### Medium（ハンズオンに含めた場合はスキップ可）

**課題:** ハンズオンで **`UpdateUserName` と `PATCH /user` をまだ入れていない**場合に、ここまでを追いつかせる。すでにステップ3〜4どおり実装済みなら、この節は読み飛ばしてよい。

Store の `UpdateUserName` と、`main` の `PatchUser` および `/user` のメソッド振り分け・`errors.Is(err, sql.ErrNoRows)` による 404 は、**ハンズオンのステップ3〜4と同一**である。**回答例（抜粋）**としてコードだけ再掲する:

```go
func (s *UserStore) UpdateUserName(ctx context.Context, id int64, name string) error {
	res, err := s.db.ExecContext(ctx, `UPDATE users SET name = ? WHERE id = ?`, name, id)
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return sql.ErrNoRows
	}
	return nil
}
```

`PatchUser` と `HandleFunc("/user", …)` の `switch r.Method` は、上記ステップ4の `main` 全文を参照。

---

### Hard

**課題:** `InsertUser` と別操作を **1トランザクション** にまとめる（例: ユーザー追加とログテーブルへの INSERT）。`BeginTx` と `Commit` / `Rollback` を使う。  
**回答例（概念）:**

```go
tx, err := s.db.BeginTx(ctx, nil)
// tx.ExecContext で複数文
// err なら Rollback、成功なら Commit
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）:** 3

1. **社内の「特徴量フラグ」や審査ステータスの記録 API:** 例として、与信審査のワークフローで「申請 ID と現在ステータス」を SQLite に保存し、オペレーション用のダッシュボードから `GET` で参照する。トラフィックが限定的なら SQLite と薄い Store で足り、後から PostgreSQL に移すときもインタフェース境界を切っておけば差し替えやすい。  
2. **開発者向けのマイグレーション検証用 HTTP エンドポイント:** ステージングで「シードデータ投入用 POST」と「整合性確認用 GET」だけを公開し、`database/sql`＋プレースホルダで安全に検証する。本番相当の接続設定は環境変数（DSN）に寄せ、コードは Store に閉じる。  
3. **バッチ（夜間集計）と API（日中照会）のロジック共有:** cron からの集計ジョブと、営業時間中の参照 API が **同じ `UserStore`（または Repository）** を呼ぶことで、SQL の重複と不整合を防ぐ。HTTP の生存期間とバッチの `context.Background()` の違いも、この教材の通り責務分離で説明しやすい。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）:** 2

- `database/sql` とドライバ1つで、接続プール経由の CRUD の基本形が組める。  
- ハンドラと Store に責務を分けると、HTTP と永続化の境界が明確になり、`go test` しやすい。  
- `Context`・`Ping`・`ErrNoRows`（`UPDATE` の0行も `ErrNoRows` に寄せて `errors.Is` で 404 にそろえる）・プレースホルダを最初から入れると、本番コードに近い癖がつく。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）:** 2

1. **トランザクション・リトライ・楽観ロックの入口**（`BeginTx`、競合時の扱い）  
2. **`sqlc` や Repository パターン、インタフェースによるテストダブル**（設計と自動生成の比較の土台）
