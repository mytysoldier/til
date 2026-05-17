# Go: handler / service / repository 分離（1日教材）

## 1. 今日のゴール

**目安時間: 2分**

`handler → service → repository` の3層に責務を分けた最小の HTTP API をローカルで起動し、`service` 層の **table-driven テストがすべて成功**する状態まで持っていく。公式の `net/http` と標準の `testing` のみを使う。

---

## 2. 事前知識チェック

**目安時間: 5分**

以下は「思い出せればOK / 分からなければ教材の該当箇所を優先」である。

1. **Go モジュールの初期化コマンドは何か。**  
   **回答:** `go mod init <module-path>`（例: `go mod init example.com/userapi`）。参考: [Go Modules Reference](https://go.dev/ref/mod)

2. **`net/http` でルーティングを足すとき、多くの教材で使う登録関数は何か。**  
   **回答:** `http.HandleFunc` または `ServeMux` の `HandleFunc`。参考: [`net/http` パッケージ](https://pkg.go.dev/net/http)

3. **インターフェースを「実装側」が宣言する必要があるか。**  
   **回答:** ない。満たせば暗黙的に実装される（構造的サブタイピング）。参考: [Type system / Interfaces](https://go.dev/ref/spec#Interface_types)

---

## 3. 理論

**目安時間: 10分**

### 重要ポイント1: レイヤーは「依存の向き」を固定するための箱である

- **要点:** `handler` は HTTP の入出力に、`service` はユースケース（ビジネスルール）に、`repository` は永続化の詳細に責務を閉じる。上位は下位の「抽象（インターフェース）」にだけ依存する。
- **よくある誤解/落とし穴:** 「フォルダを分けたから終わり」になりがち。依存が `handler` から `sql.DB` へ直に伸びているなら、まだレイヤー分離になっていない。

### 重要ポイント2: `service` に寄せるのは「協調するルール」、単純な1行取得だけとは限らない

- **要点:** 入力検証、権限の前提、複数リポジトリの組み合わせ、「存在しないときどうするか」など、**アプリとしての意味**を `service` に置く。
- **よくある誤解/落とし穴:** `service` が `repository` の薄いラッパーになると、テストの価値が上がりにくい。まずは小さなルール（空ID禁止など）を1つ入れて差を作る。

### 重要ポイント3: `repository` はインターフェース越しに差し替え可能にするのが目的

- **要点:** 本番は DB、テストはメモリ実装（フェイク）に切り替える。`service` のテストが速く安定しやすい。
- **よくある誤解/落とし穴:** インターフェースを乱発すると探索性が下がる。**最初は「`service` が必要とする最小のメソッドだけ」**に絞るのが安全。

### 重要ポイント4: `handler` は整形とステータスコード、本文変換に専念する

- **要点:** JSON の decode/encode、400/404/500 の対応、ログの出し方（本文では最小）など。ドメインの意味判断は `service` へ委譲する。
- **よくある誤解/落とし穴:** `handler` に「ビジネス用語でない分岐」（例: 同姓同名の扱い）が増えると、HTTP 以外の入出力を追加したときにコピペ地獄になりやすい。

### 重要ポイント5: 比較観点（今日は1つだけ）—「肥満ハンドラ」対「3層」

- **要点:** 小規模プロトタイプでは1ファイルに寄せた方が速いことがある。一方、**要件が増えたときに“どこを直せば壊れにくいか”**が課題になる。今日の形は「壊れにくさの土台」を優先した選択である。
- **なぜこの教材では3層か:** 実務で頻出の責務境界に触れつつ、標準ライブラリだけで**テスト可能**な最小構造を自作できるため。

### 重要ポイント6: 共有状態・ポインタ・エラー比較（詰まりどころの予防）

- **要点:** プロセス内キャッシュのように **複数リクエストから触る map** はミューテックスで守る。`Save(ctx, *User)` が **ポインタ先の `ID` を書き換える**のは「採番を永続化層に閉じる」ための典型で、呼び出し元は `Save` 後の `u.ID` を読んでもよい。HTTP 層では `errors.Is(err, domain.ErrNotFound)` のように **sentinel（固定の変数）で分岐**する。
- **よくある誤解/落とし穴:** `err.Error() == "not found"` の文字列比較はラップで破れる。I/O で `Context` がキャンセルされたら下位で `ctx.Err()` を返すのが基本だが、本教材ではメモリ実装のため省略している。**巨大 JSON** を無制限に `Decode` しない（実務では [`http.MaxBytesReader`](https://pkg.go.dev/net/http#MaxBytesReader) などで上限を付ける）。

### 重要ポイント7: 公式ドキュメントで確認すべき落とし穴（入口）

- **`Context`:** キャンセルや期限は I/O の境界で扱う。[`context` パッケージ](https://pkg.go.dev/context)
- **エラー:** 呼び出し元が分岐できる情報を返す（本文では `errors.Is` まで触れる程度）。[`errors` パッケージ](https://pkg.go.dev/errors)
- **`ServeMux`:** Go 1.22 からパターンマッチが拡張されている。挙動が気になるときは [Routing enhancements](https://go.dev/blog/routing-enhancements) と [`ServeMux` ドキュメント](https://pkg.go.dev/net/http#ServeMux) を読む（本教材は `HandleFunc` の最小例に留める）。

---

## 4. ハンズオン（手順）

**目安時間: 33分**

作業の親ディレクトリは本日の学習フォルダ（このファイルと同じ階層）とする。ここでは `TUTORIAL_ROOT` と書く。

**はじめに（詰まり予防）**

- `go version` で **1.21 以上**を確認する（それ未満ならアップグレードしてから続行）。
- `:8080` が既に使われている場合は `main.go` の `":8080"` を `":8081"` などに変え、以降の `curl` も合わせる。
- Windows の PowerShell では `mkdir -p` が無い場合がある。そのときはエクスプローラでフォルダを作るか、`New-Item -ItemType Directory` を使う。

### ステップ0: `tutorial` 用の `.gitignore` を用意する

**やること**

1. `TUTORIAL_ROOT` に `.gitignore` を作成する（日次フォルダ直下で演習する想定。リポジトリ直下にすでに `.gitignore` がある場合は、**そちらに追記してもよい**）。
2. 次の1行を書く（演習成果をコミット対象外にする）。

```gitignore
tutorial/
```

**確認方法（期待される出力/挙動）**

- `TUTORIAL_ROOT/.gitignore` が存在し、`tutorial/` が含まれる。
- 参考: [.gitignore の書き方（Git 公式）](https://git-scm.com/docs/gitignore)

### ステップ1: モジュール作成とディレクトリ骨格

**やること**

```bash
cd "$TUTORIAL_ROOT"
mkdir -p tutorial
cd tutorial
go mod init example.com/userapi

mkdir -p cmd/api \
  internal/domain \
  internal/repository/memory \
  internal/service \
  internal/handler
```

**確認方法**

- `tutorial/go.mod` が存在する。
- `tutorial` ディレクトリで `go env GOMOD` を実行すると、その `go.mod` の絶対パスが出る。

### ステップ2: ドメインモデルとリポジトリ抽象を置く

**やること:** `internal/domain/user.go` を作成する。

```go
package domain

import (
	"context"
	"errors"
)

// ErrNotFound は取得対象が存在しないときに repository 実装が返すことを想定したシンボルである。
var ErrNotFound = errors.New("not found")

type User struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type UserRepository interface {
	FindByID(ctx context.Context, id string) (*User, error)
	Save(ctx context.Context, u *User) error
}
```

**確認方法**

- `tutorial` で `go build ./...` を実行しても、まだ `main` が無ければビルド対象が空で **エラーにならない**（または次ステップまで置いてもよい）。

### ステップ3: メモリ実装（`repository`）を作る

**やること:** `internal/repository/memory/user_repository.go`

```go
package memory

import (
	"context"
	"errors"
	"strconv"
	"sync"

	"example.com/userapi/internal/domain"
)

type UserRepository struct {
	mu    sync.RWMutex
	byID  map[string]domain.User
	nextN int
}

func NewUserRepository() *UserRepository {
	return &UserRepository{byID: make(map[string]domain.User)}
}

func (r *UserRepository) FindByID(ctx context.Context, id string) (*domain.User, error) {
	_ = ctx // 本教材では未使用だが、I/O 境界の標準形として受け取る

	r.mu.RLock()
	defer r.mu.RUnlock()

	u, ok := r.byID[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	cp := u
	return &cp, nil
}

func (r *UserRepository) Save(ctx context.Context, u *domain.User) error {
	_ = ctx

	if u == nil {
		return errors.New("user is nil")
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	if u.ID == "" {
		r.nextN++
		u.ID = "auto-" + strconv.Itoa(r.nextN) // 教材用の連番ID（実務では ULID 等へ）
	}
	cp := *u
	r.byID[cp.ID] = cp
	return nil
}
```

**すみ分け（なぜこうするか）:** 連番は衝突しやすいが、本文では「永続化の詳細」を最短で示すために採用する。実務では ULID/UUID、DB のシーケンスなどに置き換える。**`Save` が `u.ID` を書き換える**ので、`CreateUser` は `Save` 後に同じポインタの `ID` をそのまま返せる。

**確認方法**

- `go vet ./...` が通る。

### ステップ4: `service` にビジネスルールを置く

**やること:** `internal/service/user_service.go`

```go
package service

import (
	"context"
	"errors"
	"strings"

	"example.com/userapi/internal/domain"
)

var ErrInvalidInput = errors.New("invalid input")

type UserService struct {
	Repo domain.UserRepository
}

func (s *UserService) GetUser(ctx context.Context, id string) (*domain.User, error) {
	id = strings.TrimSpace(id)
	if id == "" {
		return nil, ErrInvalidInput
	}
	return s.Repo.FindByID(ctx, id)
}

func (s *UserService) CreateUser(ctx context.Context, name string) (*domain.User, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, ErrInvalidInput
	}

	u := &domain.User{ID: "", Name: name}
	if err := s.Repo.Save(ctx, u); err != nil {
		return nil, err
	}
	return u, nil
}
```

**確認方法**

- `go build ./...` でコンパイルが通る（この時点では `main` が未作成でもよい）。
- `UserService` は `domain.UserRepository` だけに依存し、`memory` などの具体実装を import していない。

### ステップ5: `handler` を薄くする

**やること:** `internal/handler/user_handler.go`

```go
package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"example.com/userapi/internal/domain"
	"example.com/userapi/internal/service"
)

type UserHandler struct {
	Svc *service.UserService
}

type createUserRequest struct {
	Name string `json:"name"`
}

func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// 例: /users/{id} を雑に切り出す（教材最小。実務ではルータを検討するが本教材は標準のみ）
	if !strings.HasPrefix(r.URL.Path, "/users/") {
		http.NotFound(w, r)
		return
	}
	id := strings.TrimPrefix(r.URL.Path, "/users/")
	id = strings.TrimSpace(id)
	if id == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	u, err := h.Svc.GetUser(r.Context(), id)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidInput):
			http.Error(w, "bad request", http.StatusBadRequest)
		case errors.Is(err, domain.ErrNotFound):
			http.Error(w, "not found", http.StatusNotFound)
		default:
			http.Error(w, "internal error", http.StatusInternalServerError)
		}
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(u)
}

func (h *UserHandler) PostUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	defer r.Body.Close()

	var req createUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}

	u, err := h.Svc.CreateUser(r.Context(), req.Name)
	if err != nil {
		if errors.Is(err, service.ErrInvalidInput) {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(u)
}
```

**確認方法**

- `go build ./...` が通る（`main` 追加前でも、パッケージ単体の構文エラーがない）。

### ステップ6: `main` で配線して起動する

**やること:** `cmd/api/main.go`

```go
package main

import (
	"log"
	"net/http"

	"example.com/userapi/internal/handler"
	"example.com/userapi/internal/repository/memory"
	"example.com/userapi/internal/service"
)

func main() {
	repo := memory.NewUserRepository()
	svc := &service.UserService{Repo: repo}
	h := &handler.UserHandler{Svc: svc}

	mux := http.NewServeMux()
	// 末尾スラッシュ付きは /users/{id} 向け。POST /users は別ルート。
	mux.HandleFunc("/users/", h.GetUser)
	mux.HandleFunc("/users", h.PostUsers)

	log.Println("listening on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatal(err)
	}
}
```

**起動と手動確認**

ターミナル A:

```bash
cd tutorial
go run ./cmd/api
```

ターミナル B:

```bash
curl -s -X POST localhost:8080/users -H 'Content-Type: application/json' -d '{"name":"alice"}'
```

**確認のしかた（重要）:** 応答 JSON の `"id":"..."` を**目で確認**し、その文字列を次の `<ID>` にそのまま substitute する（`<ID>` という字面を curl に貼らない）。

```bash
curl -s localhost:8080/users/<ID>
```

例（応答が `{"id":"auto-1","name":"alice"}` だった場合）:

```bash
curl -s localhost:8080/users/auto-1
```

初回起動直後なら、教材の実装ではしばしば `auto-1` になるが、**プロセスを再起動すると連番は再び 1 から**になり得るため、安易に暗記に頼らない。

**確認方法**

- POST が **201** で JSON が返り、GET が **200** で同じユーザーが取れる。
- `curl -i -X POST localhost:8080/users/...` のように **間違ったパス**を叩いたとき、**405 や 404 が想定どおり**になることをざっくり見ておくとよい。

### ステップ7: テスト（`service` をフェイクで table-driven 検証）

**やること:** `internal/service/user_service_test.go`

```go
package service

import (
	"context"
	"errors"
	"strconv"
	"testing"

	"example.com/userapi/internal/domain"
)

type fakeUserRepo struct {
	byID  map[string]domain.User
	err   error
	nextN int
}

func (f *fakeUserRepo) FindByID(ctx context.Context, id string) (*domain.User, error) {
	if f.err != nil {
		return nil, f.err
	}
	if f.byID == nil {
		f.byID = make(map[string]domain.User)
	}
	u, ok := f.byID[id]
	if !ok {
		return nil, domain.ErrNotFound
	}
	cp := u
	return &cp, nil
}

func (f *fakeUserRepo) Save(ctx context.Context, u *domain.User) error {
	if f.err != nil {
		return f.err
	}
	if f.byID == nil {
		f.byID = make(map[string]domain.User)
	}
	if u.ID == "" {
		f.nextN++
		u.ID = "fake-" + strconv.Itoa(f.nextN) // 常に同じ固定IDにしない（複数Saveでも壊れない）
	}
	f.byID[u.ID] = *u
	return nil
}

func TestUserService_GetUser(t *testing.T) {
	tests := []struct {
		name    string
		repo    *fakeUserRepo
		id      string
		wantErr error
	}{
		{
			name:    "invalid id",
			repo:    &fakeUserRepo{},
			id:      "   ",
			wantErr: ErrInvalidInput,
		},
		{
			name:    "not found",
			repo:    &fakeUserRepo{},
			id:      "missing",
			wantErr: domain.ErrNotFound,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &UserService{Repo: tt.repo}
			_, err := svc.GetUser(context.Background(), tt.id)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("errors.Is: want %v, got %v", tt.wantErr, err)
			}
		})
	}
}
```

**確認方法**

```bash
cd tutorial
go test ./...
```

**期待される挙動:** `ok` が表示され、**サブテストが2件とも**成功する。

---

**ここまでできれば今日のゴール達成**

---

## 5. 追加課題（時間が余ったら）

**目安時間: 余裕があれば合計 10〜25分（段階により異なる）**

### Easy（5〜10分）

**課題:** `CreateUser` で名前の最大長（例: 20 文字）を `service` 側で拒否する。

**回答コード例（`user_service.go` に追記・調整のイメージ）**

```go
const maxNameLen = 20

func (s *UserService) CreateUser(ctx context.Context, name string) (*domain.User, error) {
	name = strings.TrimSpace(name)
	if name == "" || len([]rune(name)) > maxNameLen {
		return nil, ErrInvalidInput
	}
	u := &domain.User{ID: "", Name: name}
	if err := s.Repo.Save(ctx, u); err != nil {
		return nil, err
	}
	return u, nil
}
```

### Medium（発展）

**課題:** `PostUsers` で `json.NewDecoder` を [`http.MaxBytesReader`](https://pkg.go.dev/net/http#MaxBytesReader) で包み、本文上限を **1MiB** に制限する（標準ライブラリのみ）。

**回答コード例（抜粋）**

```go
r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
defer r.Body.Close()
```

### Hard（発展）

**課題:** 「`Save` と別操作を原子的に行いたい」要件が来たとき、トランザクション境界はどこ（`service` vs `repository`）に置くのが自然か、200字程度でメモを書く。  
**回答例（文章）:** ユースケース単位で整合性を保証する責務は `service` に置き、`repository` はトランザクションを表す **単位（例: `Tx`、または `UnitOfWork`）**を抽象化して `service` が開始・コミットを制御する、が一般的に分かりやすい（詳細は ORM/ドライバに依存するため、まずは入口理解まで）。

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間: 5分**

1. **SaaS の「組織に紐づくメンバー一覧」:** パスとJWTの `org_id` を突き合わせ、`service` で「この `org_id` に所属していなければ 404（または 403）」を決める。SQLは `repository` に閉じ、**監査ログに残す文面**は `handler` で整形だけ、という切り分けがしやすい。

2. **EC の注文確定（在庫引当 + 決済オーソリ + 注文行 INSERT）:** 失敗時に **どこまでロールバックするか・リトライ可能か**を `service` が命令し、`repository` は「在庫」「注文」の保存をインターフェース化する。HTTP は「202 で受け付け」か「同期で 409」などをステータスに写像するだけに寄せられる。

3. **オンコール中のインシデント時:** DB が落ちているとわかったら、`repository` の実装を **読み取り専用レプリカ**や **キャッシュ**に差し替える、といった運用変更を **`main` の配線**で吸収しやすい（`handler` や `service` の分岐を最小化できる）。

---

## 7. まとめ（今日の学び3行）

**目安時間: 3分**

- 依存の向きを揃えると、HTTP を増やしてもドメインルールの置き場所がブレにくい。  
- `repository` は交換可能な境界として切り出すと、`service` のテストが現実的になる。  
- 比較の軸は「速度」より先に「変更が来たときにどこを直すか」だと判断がブレにくい。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間: 2分**

1. **エラー設計の一段上:** `fmt.Errorf` と `%w`、`errors.Is` / `errors.As`、ドメイン固有エラーをどこに置くか。参考: [`errors` パッケージ](https://pkg.go.dev/errors)
2. **HTTP サーバ構成:** `http.Server` のタイムアウト、`ListenAndServe` と `Shutdown`（Graceful shutdown）を `context` とセットで扱う。参考: [`http.Server` ドキュメント](https://pkg.go.dev/net/http#Server)
