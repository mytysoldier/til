# Go: error / interface / 責務分離（1日分教材）

## 1. 今日のゴール

**目安時間: 1分**

`error` の扱いと小さな `interface` を使って、リポジトリ抽象とサービス実装を分離した最小モジュールを `tutorial/` 以下に作る。`go run ./cmd/app` と `go test ./...` が通り、**成功系と `errors.Is` による NotFound 判定**をテストで押さえる。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間: 5分**

**Q1.** `if err != nil` のあとに `return err` だけすると、呼び出し元は「どこで失敗したか」を追いにくくなることがある。Go 1.13 以降で文脈を足しつつ連鎖させる代表的な書き方は何か。

**A1.** `fmt.Errorf("...: %w", err)` でラップする。呼び出し側は `errors.Is` / `errors.As` で元のエラーを判定できる。

**Q2.** `interface` を「先に全部定義してから実装する」ことが多い言語もあるが、Go のイディオムとして推奨されるのはどちらか。

**A2.** **実装側が必要なメソッド集合を満たし、利用側が小さなインターフェースとして受け取る**（consumer が interface を定義する／またはその場で必要最小限だけ切る）。巨大な「上帝インターフェース」は避ける。

**Q3.** 依存方向の原則として、ビジネスロジック（ドメイン／サービス）がインフラ（DB・HTTP・外部API）に直接依存すると何が困るか。

**A3.** テストが重くなり、差し替えが効かず、変更の影響が広がる。**上位のポリシーが下位の詳細に引っ張られる**ため、抽象（インターフェース）への依存に反転させるとよい。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間: 12分**

### ポイント1: `error` は値であり、比較可能性とラップの両立に注意する

- `errors.New` や `fmt.Errorf` で作った値は文脈を足せるが、**同じメッセージでも別インスタンス**になり得る。
- **よくある誤解/落とし穴:** `err == io.EOF` はラップ後に偽になりやすい。判定は `errors.Is(err, io.EOF)` を使う。型の抽出は `errors.As`。**`%w` でラップしたあとも `errors.Is` で中身を辿れる**のが実務上の前提になる。

### ポイント2: センチネルエラーとカスタム型を使い分ける

- ドメイン固有の失敗（例: `ErrNotFound`）はパッケージレベルの変数や、必要なら `Unwrap` を持つ型で表現する。
- **よくある誤解/落とし穴:** 文字列の `Contains` だけで判定すると、メッセージ変更で壊れる。**シンボル（`errors.Is`）か型（`errors.As`）で契約**する。

### ポイント3: `interface` は「振る舞いの束」であり、メソッドが増えるほど実装コストが上がる

- 呼び出し側が本当に使うメソッドだけを載せた**小さなインターフェース**がテスト容易性と変更耐性に効く。
- **よくある誤解/落とし穴:** 「将来のため」にメソッドを並べた巨大 `interface` は、モックや fake の実装が膨らみ、**YAGNI で負債化**しやすい。

### ポイント4: 「どこで `interface` を切るか」＝依存の境界

- 例: `UserRepository` は永続化の抽象。`UserService` はユースケースの調停役。
- **よくある誤解/落とし穴:** すべてを `interface{}` や汎用 `DoSomething` に逃がすと、**型安全さと読みやすさを失う**。境界は明確な語彙（メソッド名）で切る。

### ポイント5: 依存方向（クリーンアーキテクチャでいう内向き）

- **サービス／ドメインは抽象（インターフェース）に依存**し、**インフラ実装はそのインターフェースを満たす**。
- **よくある誤解/落とし穴:** `service` パッケージが `database/sql` を直接 import すると、単体テストが DB 必須になる。**インフラは外側**に置く。

### ポイント6: `context`・状態・非同期まわりの実務的な落とし穴

- **Context:** 上位で付けた `WithTimeout` / `WithCancel` は、**リポジトリや DB 呼び出しまで伝播させる**のが基本。サービスだけ `context.Background()` に差し替えると、タイムアウトが効かない。
- **状態:** `map` を複数ゴルーチンから触るインメモリ実装は**競合する**。教材の `MemoryUserRepo` は単一スレッド想定。本番の共有キャッシュは `sync.Map` や DB／外部ストアに寄せる。
- **非同期:** ゴルーチン内の失敗は `err` をチャネルで返すか、`errgroup` 等で集約する。放置すると**失敗が握り潰される**。本ハンズオンは同期のみだが、境界の `error` 設計は同じ考え方が効く。

### 設計の選択肢と、この教材での選択

- **選択肢A:** インターフェースを `repository` パッケージに置く。  
- **選択肢B:** インターフェースを `service` 側（利用側）に置き、実装だけ別パッケージにする。  
- **この教材では B を推奨:** 「サービスが必要とする振る舞い」に合わせて境界を切ると、**余計なメソッドをリポジトリに押し付けにくい**。小規模なら同一パッケージ内 `user_service.go` に `type UserRepository interface { ... }` を置いてもよい。

---

## 4. ハンズオン（手順）

**目安時間: 30分**

作業ディレクトリは **`日次記録/2026年/3月/29日/tutorial/`**（このフォルダは当日 `mkdir` で作成。リポジトリでは `.gitignore` で除外済み）。

**完成時のディレクトリ構成（目安）:**

```text
tutorial/
├── go.mod
├── domain/
│   └── user.go
├── service/
│   ├── user_service.go
│   └── user_service_test.go
├── repository/
│   └── memory.go
└── cmd/
    └── app/
        └── main.go
```

**モジュールパス:** 手順では `example.com/userdemo` とする。`go mod init` で別名にした場合は、以降の `import` をすべてそのモジュール名に合わせる。

### ステップ0: フォルダと `.gitignore` の確認

1. 教材と同じ階層に `29日/.gitignore` があり `tutorial/` が無視対象になっていることを確認する（手元の検証用コードを誤コミットしないため）。
2. `mkdir -p tutorial && cd tutorial` を実行する。

**確認方法:** `pwd` で `.../29日/tutorial` にいること。

---

### ステップ1: モジュール初期化

1. `go mod init example.com/userdemo`（モジュールパスは任意でよい。変えたら後続の import をすべてその名前に統一する）。
2. `go env GOMOD` で `go.mod` のパスが表示されることを確認。

**確認方法:** `cat go.mod` に `module example.com/userdemo`（または選んだ名前）が出る。

---

### ステップ2: ドメインとエラー（センチネル）

`domain/user.go` を作成する。

```go
package domain

import "errors"

var ErrNotFound = errors.New("not found")

type User struct {
	ID   string
	Name string
}
```

**確認方法:** `go build ./domain` がエラーなく通る（`tutorial` がカレントディレクトリであること）。

---

### ステップ3: サービス・インターフェース（責務分離）

`service/user_service.go` を作成する（**リポジトリはインターフェース、サービスがそれに依存**）。

```go
package service

import (
	"context"
	"fmt"

	"example.com/userdemo/domain"
)

// UserRepository は永続化の抽象（実装は別パッケージ／別ファイル）
type UserRepository interface {
	GetByID(ctx context.Context, id string) (domain.User, error)
}

type UserService struct {
	repo UserRepository
}

func NewUserService(r UserRepository) *UserService {
	return &UserService{repo: r}
}

// GetDisplayName はユースケース例：名前取得に失敗理由をラップして返す
func (s *UserService) GetDisplayName(ctx context.Context, id string) (string, error) {
	u, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return "", fmt.Errorf("get display name: %w", err)
	}
	return u.Name, nil
}
```

**確認方法:** `go build ./service` が通る。

---

### ステップ4: フェイク実装と `main`（動くもの）

`repository/memory.go`（インメモリ実装の例。**複数ゴルーチンから同時に触らない**前提）:

```go
package repository

import (
	"context"

	"example.com/userdemo/domain"
)

type MemoryUserRepo struct {
	data map[string]domain.User
}

func NewMemoryUserRepo() *MemoryUserRepo {
	return &MemoryUserRepo{data: map[string]domain.User{
		"1": {ID: "1", Name: "Alice"},
	}}
}

func (m *MemoryUserRepo) GetByID(_ context.Context, id string) (domain.User, error) {
	u, ok := m.data[id]
	if !ok {
		return domain.User{}, domain.ErrNotFound
	}
	return u, nil
}
```

`cmd/app/main.go`:

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"log"

	"example.com/userdemo/domain"
	"example.com/userdemo/repository"
	"example.com/userdemo/service"
)

func main() {
	ctx := context.Background()
	repo := repository.NewMemoryUserRepo()
	svc := service.NewUserService(repo)

	name, err := svc.GetDisplayName(ctx, "1")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(name)

	_, err = svc.GetDisplayName(ctx, "999")
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			fmt.Println("expected not found")
			return
		}
		log.Fatal(err)
	}
}
```

**確認方法:**

```bash
go run ./cmd/app
```

**期待される出力/挙動:** 先に `Alice` が表示され、その後 `expected not found` が表示される（ラップされたエラーでも `errors.Is` で `ErrNotFound` を検出できている）。

---

### ステップ5: テスト（成功と NotFound の2本）

`service/user_service_test.go`:

```go
package service

import (
	"context"
	"errors"
	"testing"

	"example.com/userdemo/domain"
)

type fakeRepo struct {
	u   domain.User
	err error
}

func (f *fakeRepo) GetByID(ctx context.Context, id string) (domain.User, error) {
	if f.err != nil {
		return domain.User{}, f.err
	}
	return f.u, nil
}

func TestUserService_GetDisplayName_OK(t *testing.T) {
	svc := NewUserService(&fakeRepo{u: domain.User{ID: "1", Name: "Bob"}})
	name, err := svc.GetDisplayName(context.Background(), "1")
	if err != nil {
		t.Fatal(err)
	}
	if name != "Bob" {
		t.Fatalf("got %q", name)
	}
}

func TestUserService_GetDisplayName_NotFound_IsWrapped(t *testing.T) {
	svc := NewUserService(&fakeRepo{err: domain.ErrNotFound})
	_, err := svc.GetDisplayName(context.Background(), "missing")
	if err == nil {
		t.Fatal("expected error")
	}
	if !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("errors.Is should see ErrNotFound through wrap: %v", err)
	}
}
```

**確認方法:**

```bash
go test ./...
```

**期待される出力:** すべてのパッケージで `PASS`（外部ライブラリなし）。

---

### つまずいたとき（短いチェックリスト）

- **`go: cannot find module` / import が解決しない:** `tutorial` で `go mod init` 済みか、`import` のプレフィックスが `go.mod` の `module` 行と一致しているか確認する。
- **`go build ./...` が main を含めず失敗する:** ステップ2〜3では `go build ./domain` のように**パッケージ単位**でよい。最終的に `go build ./...` で全体を確認する。
- **`errors.Is` が偽になる:** ラップに `%w` を使っているか、`return fmt.Errorf(...: %v", err)` になっていないか確認する（`%v` だと `Is` で辿れない）。

---

## 5. 追加課題（時間が余ったら）

**目安時間: 5分（余裕時）**

### Easy

**課題:** `GetDisplayName` で `id == ""` のときは `errors.New("empty id")` を返すようにする。テストを1つ追加する。

**回答の要点:** サービス層で入力検証し、リポジトリを呼ばない。テストで `fakeRepo` が呼ばれないことまで確認するとより堅い。

**回答例（`service/user_service.go` の先頭付近に `errors` を import、`GetDisplayName` の先頭に追加）:**

```go
// import に "errors" を追加したうえで、GetDisplayName の先頭を次のようにする。

func (s *UserService) GetDisplayName(ctx context.Context, id string) (string, error) {
	if id == "" {
		return "", errors.New("empty id")
	}
	u, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return "", fmt.Errorf("get display name: %w", err)
	}
	return u.Name, nil
}
```

**回答例（テスト。空 ID ではリポジトリに行かないことを、`fakeRepo` が成功データを返す設定でも失敗で検出）:**

```go
func TestUserService_GetDisplayName_EmptyID(t *testing.T) {
	// バグで repo が呼ばれると "Leaked" が返ってしまう
	svc := NewUserService(&fakeRepo{u: domain.User{Name: "Leaked"}})
	_, err := svc.GetDisplayName(context.Background(), "")
	if err == nil {
		t.Fatal("expected error")
	}
	if err.Error() != "empty id" {
		t.Fatalf("got %v", err)
	}
}
```

**より厳密に呼び出し回数を見たい場合（スパイ）の例:**

```go
type spyRepo struct {
	calls int
	fakeRepo
}

func (s *spyRepo) GetByID(ctx context.Context, id string) (domain.User, error) {
	s.calls++
	return s.fakeRepo.GetByID(ctx, id)
}

func TestUserService_GetDisplayName_EmptyID_DoesNotCallRepo(t *testing.T) {
	spy := &spyRepo{fakeRepo: fakeRepo{u: domain.User{Name: "x"}}}
	svc := NewUserService(spy)
	_, err := svc.GetDisplayName(context.Background(), "")
	if err == nil || err.Error() != "empty id" {
		t.Fatalf("got %v", err)
	}
	if spy.calls != 0 {
		t.Fatalf("repo GetByID called %d times", spy.calls)
	}
}
```

---

### Medium

**課題:** カスタム型 `type NotFoundError struct { Resource string }` を定義し、`Error()` と `Unwrap()` で `domain.ErrNotFound` と連携させ、`errors.As` の例をテストに書く。

**回答の要点:** 文脈を型で運びつつ、センチネルと `Is`/`As` の橋渡しを行うパターン。

**回答例（`domain/user.go` の `import` に `fmt` を足し、次を追加）:**

```go
import (
	"errors"
	"fmt"
)

// 既存の ErrNotFound 等の下あたりに:

type NotFoundError struct {
	Resource string
}

func (e *NotFoundError) Error() string {
	return fmt.Sprintf("%s not found", e.Resource)
}

func (e *NotFoundError) Unwrap() error {
	return ErrNotFound
}
```

**回答例（`fakeRepo` が `*domain.NotFoundError` を返すケースのテスト）:**

```go
func TestUserService_GetDisplayName_NotFoundError_As(t *testing.T) {
	nfe := &domain.NotFoundError{Resource: "user"}
	svc := NewUserService(&fakeRepo{err: nfe})
	_, err := svc.GetDisplayName(context.Background(), "1")
	if err == nil {
		t.Fatal("expected error")
	}
	var as *domain.NotFoundError
	if !errors.As(err, &as) {
		t.Fatalf("errors.As: %v", err)
	}
	if as.Resource != "user" {
		t.Fatalf("resource: %q", as.Resource)
	}
	// Unwrap 連鎖によりセンチネルでも判定可能
	if !errors.Is(err, domain.ErrNotFound) {
		t.Fatal("expected errors.Is ErrNotFound")
	}
}
```

---

### Hard

**課題:** `UserRepository` を満たす別実装として、`GetByID` が常にタイムアウト風のエラーを返す `flakyRepo` を用意し、`GetDisplayName` のエラーラップがログにスタックを残しやすい形か検討する（ログ出力は `testing.T.Log` でよい）。

**回答の要点:** **ラップの深さとログの粒度**のトレードオフ。実務では `zap` 等のスタック取得と組み合わせることが多いが、本課題では方針の言語化まででよい。

**回答例（テストファイル内に `flakyRepo` と検証）:**

```go
type flakyRepo struct{}

func (flakyRepo) GetByID(ctx context.Context, id string) (domain.User, error) {
	return domain.User{}, context.DeadlineExceeded
}

func TestUserService_GetDisplayName_DeadlineWrapped(t *testing.T) {
	svc := NewUserService(flakyRepo{})
	ctx := context.Background()
	_, err := svc.GetDisplayName(ctx, "1")
	if err == nil {
		t.Fatal("expected error")
	}
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Logf("wrap chain: %v", err)
		t.Fatal("errors.Is DeadlineExceeded")
	}
	t.Logf("ログ用の一行例: %v", err)
	// 考察: fmt.Errorf("get display name: %w", err) により
	// 文字列は "get display name: context deadline exceeded" のようになり、
	// 原因は errors.Is で辿れる。ログに全文を出すと文脈は分かりやすいが、
	// ラップが深いと行が長くなる → 構造化ログで err フィールドにチェーンを載せる、などが実務では検討される。
}
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間: 4分**

1. **HTTP ハンドラとドメインの間:** `UserService` が `ErrNotFound` を返したら **404**、認可失敗なら **403** のように**エラーの種類からステータスをマップ**する層を置く。ラップを `%w` で統一しておくと、`errors.Is` で分岐しやすい。
2. **ユースケース層と永続化の分離:** RDB・Redis・社内API を切り替えるとき、`Repository` インターフェースをサービスが握り、実装を `infra/persistence` に閉じる。**トランザクション境界**は「ユースケース1操作＝1トランザクション」など、チームで決めた単位でリポジトリメソッドを設計する。
3. **CI を速く保つフェイク注入:** DB コンテナを立てずに、`fakeRepo` で戻り値と `ErrNotFound` を固定し、**契約（ラップ後も `Is` が効くか）**を単体テストで担保する。結合テストは別ジョブに分ける、という運用と相性がよい。

---

## 7. まとめ（今日の学び3行）

**目安時間: 2分**

- `fmt.Errorf` の `%w` と `errors.Is`/`errors.As` で、**失敗の意味を壊さず文脈を足す**ことができる。  
- **小さなインターフェース**はテストと差し替えを楽にし、巨大化させない。  
- **サービスは抽象に依存し、インフラは実装として外側**に置くと、依存方向が揃い変更に強い。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間: 1分**

1. **コンテキスト（`context.Context`）:** キャンセル・デッドライン・値伝播をサービス境界でどう扱うか。  
2. **DI（手動ワイヤ vs `wire` 等）:** コンストラクタ注入のパターンと、生成コード導入の判断基準。

---

**目安時間の合計:** 1 + 5 + 12 + 30 + 5 + 4 + 2 + 1 = **60分**（±10分の範囲内）

**最小成果物:** `tutorial/` 以下で `go run ./cmd/app` と `go test ./...` が成功すること（テストは成功系と `ErrNotFound` の `errors.Is` を含む）。

**外部ライブラリ:** 使用しない（標準ライブラリのみ）。
