# Go goroutine + context — 1日分の学習教材

**時間配分（合計60分）:** ゴール 2分 / 事前 5分 / 理論 12分 / ハンズオン 28分 / 追加課題 5分 / 実務 5分 / まとめ 2分 / 布石 1分

## 1. 今日のゴール（目安: 2分）

**goroutine** で並行処理を起動し、**context** を使ってキャンセル・タイムアウト・値の伝播を正しく扱えるようになる。実務で「止まらない goroutine」や「リーク」を防ぐ設計の基礎を身につける。

---

## 2. 事前知識チェック（目安: 5分）

### Q1. goroutine を起動した後、親から子を「強制停止」する API はあるか？

**回答:** ない。Go には goroutine を外部から強制終了する API は存在しない。子 goroutine は協調的に（自分で `return` するか、チャネルや context のシグナルを見て抜ける）停止する必要がある。

### Q2. `context.Background()` と `context.TODO()` の違いは何か？

**回答:** どちらも空の context を返す。`Background()` は「ルート context」として使う標準的なもの。`TODO()` は「まだどの context を使うか決まっていない」ときのプレースホルダーで、静的解析ツールが「TODO が残っている」と検出しやすくするためのもの。実務ではほぼ `Background()` を使う。

### Q3. `context.WithCancel` で得た `cancel` 関数を呼ばずに放置すると何が起きるか？

**回答:** 子 context とその派生 context が GC されない（メモリリーク）。また、キャンセルを期待している goroutine が永遠にブロックし続ける可能性がある。`defer cancel()` を忘れないようにする。

---

## 3. 理論（目安: 12分）

### 重要ポイント1: goroutine は「止められない」

- goroutine は軽量なスレッド。`go f()` で起動するだけ。
- **強制停止 API は存在しない**。子 goroutine は自分で終了する必要がある。
- キャンセルやタイムアウトを伝えるには、**context** か **チャネル** を使う。

**よくある誤解:** 「親が終われば子も止まる」と思いがち。実際は親の `main` が終了するとプロセス全体が終わるので、子 goroutine は強制終了されるが、それは「正常終了」ではなく、クリーンアップもされない。正しくは context で「やめて」を伝え、子が自分で抜ける。

### 重要ポイント2: context の役割（キャンセル・タイムアウト・値）

- **キャンセル**: `WithCancel` → `cancel()` を呼ぶと、その context と派生 context が「キャンセル済み」になる。`ctx.Done()` が閉じる。
- **タイムアウト**: `WithTimeout` / `WithDeadline` → 指定時間経過で自動キャンセル。
- **値の伝播**: `WithValue` → リクエスト ID やトレース情報などを子に渡す。

**落とし穴:** `WithValue` は「リクエストスコープの値」用。設定や DB 接続など、広く共有するデータには使わない。キーは独自型にして衝突を防ぐ。

### 重要ポイント3: context は「第一引数」で渡す

- Go の慣習として、context は関数の第一引数に渡す: `func DoSomething(ctx context.Context, ...)`。
- 既存の API が context を受け取る場合、呼び出し側で `ctx` を渡す。渡さないとキャンセルが伝わらない。

**よくある誤解:** 「context をグローバル変数にしておけばいい」は NG。各リクエスト・各オペレーションごとに context を渡し、キャンセルが正しく伝播するようにする。

### 重要ポイント4: `select` と `ctx.Done()` のパターン

```go
select {
case <-ctx.Done():
    return ctx.Err()  // context.Canceled または context.DeadlineExceeded
case result := <-ch:
    return result
}
```

- ブロックする処理（チャネル受信、HTTP リクエストなど）の前に、`ctx.Done()` を `select` で待つ。
- ループ内では、各イテレーションの最初で `if ctx.Err() != nil { return }` をチェックする。

**落とし穴:** ループ内で `select` を忘れ、チャネル受信だけしていると、キャンセルされてもブロックしたままになる。

### 重要ポイント5: cancel は必ず呼ぶ（defer cancel()）

- `WithCancel` / `WithTimeout` で得た `cancel` 関数は、**必ず** 呼ぶ必要がある。
- リソース解放のため `defer cancel()` を書く。呼ばないと、context のタイマーや内部リソースがリークする。

**よくある誤解:** 「子に渡したから親では呼ばなくていい」は間違い。親が `cancel` を保持している限り、親のスコープが終わるときに `defer cancel()` で解放する。

### 重要ポイント6: 設計の選択肢 — context とチャネルの使い分け

**選択肢:**
- A: キャンセル用に `chan struct{}` を自前で渡す
- B: `context.Context` を渡し、`ctx.Done()` でキャンセルを検知する

**推奨:** B（context）。理由: 標準ライブラリの多くの API（`http.Request`、`database/sql`、`grpc` など）が context を受け取る。一貫して context を使うと、既存コードとの連携が容易で、タイムアウト・デッドラインも `WithTimeout` で統一できる。

---

## 4. ハンズオン（目安: 28分）

### 環境準備（事前に済ませておく）

- Go 1.21 以上をインストール（`go version` で確認）
- 教材の `25日/tutorial` ディレクトリで作業。各ステップは `step1/`, `step2/`, ... のサブディレクトリに分かれている。

```bash
cd 25日/tutorial
go mod init tutorial   # 初回のみ（既に go.mod がある場合は不要）
```

### ステップ1: 最小の goroutine を動かす（4分）

`step1/main.go` を作成（または既存を確認）:

```go
package main

import (
	"fmt"
	"time"
)

func main() {
	go func() {
		for i := 0; i < 5; i++ {
			fmt.Println("goroutine:", i)
			time.Sleep(200 * time.Millisecond)
		}
	}()
	time.Sleep(1500 * time.Millisecond)
	fmt.Println("main 終了")
}
```

**実行:** `go run step1/main.go`

**確認方法:** `goroutine: 0` 〜 `goroutine: 4` が表示され、最後に `main 終了` が出る。goroutine が並行で動いていることを確認。

### ステップ2: context でキャンセルを伝える（6分）

`step2/main.go` を作成（または既存を確認）:

```go
package main

import (
	"context"
	"fmt"
	"time"
)

func worker(ctx context.Context, name string) {
	for i := 0; ; i++ {
		select {
		case <-ctx.Done():
			fmt.Printf("%s: キャンセル検知 (%v)\n", name, ctx.Err())
			return
		default:
			fmt.Printf("%s: %d\n", name, i)
			time.Sleep(300 * time.Millisecond)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go worker(ctx, "A")
	go worker(ctx, "B")

	time.Sleep(1 * time.Second)
	cancel()
	time.Sleep(500 * time.Millisecond)
	fmt.Println("main 終了")
}
```

**実行:** `go run step2/main.go`

**確認方法:** A と B が交互に数字を出力し、約1秒後に `キャンセル検知 (context canceled)` が2回出て、`main 終了` となる。

### ステップ3: WithTimeout でタイムアウト（6分）

`step3/main.go` を作成（または既存を確認）:

```go
package main

import (
	"context"
	"fmt"
	"time"
)

func slowTask(ctx context.Context) error {
	select {
	case <-time.After(3 * time.Second):
		fmt.Println("タスク完了")
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	err := slowTask(ctx)
	if err != nil {
		fmt.Printf("エラー: %v\n", err)
	}
}
```

**実行:** `go run step3/main.go`

**確認方法:** 1秒後に `エラー: context deadline exceeded` と出る。`slowTask` は3秒待つが、context のタイムアウトで早期に抜ける。

### ステップ4: WithValue で値を伝播（6分）

`step4/main.go` を作成（または既存を確認）:

```go
package main

import (
	"context"
	"fmt"
)

type key string

const requestIDKey key = "requestID"

func handler(ctx context.Context, reqID string) {
	ctx = context.WithValue(ctx, requestIDKey, reqID)
	doWork(ctx)
}

func doWork(ctx context.Context) {
	id := ctx.Value(requestIDKey)
	fmt.Printf("requestID: %v\n", id)
}

func main() {
	ctx := context.Background()
	handler(ctx, "req-123")
	handler(ctx, "req-456")
}
```

**実行:** `go run step4/main.go`

**確認方法:** `requestID: req-123` と `requestID: req-456` が順に表示される。context 経由で値が子に渡っていることを確認。

### ステップ5: テストを書く（6分）

`step2/context_test.go` に `TestCancelStopsWorker`、`step3/context_test.go` に `TestTimeoutReturnsError` を追加（または既存を確認）。

**step2/context_test.go:**
```go
func TestCancelStopsWorker(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		worker(ctx, "test")
		close(done)
	}()
	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("worker が2秒以内に終了しなかった")
	}
}
```

**step3/context_test.go:**
```go
func TestTimeoutReturnsError(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	err := slowTask(ctx)
	if err != context.DeadlineExceeded {
		t.Errorf("DeadlineExceeded を期待したが got %v", err)
	}
}
```

**実行:** `go test ./step2/... -v` と `go test ./step3/... -v`（または `go test ./... -v` で一括）

**確認方法:** `TestCancelStopsWorker` と `TestTimeoutReturnsError` が PASS する。

### 全ステップ実行確認チェックリスト

- [ ] ステップ1: `go run step1/main.go` で goroutine の出力を確認
- [ ] ステップ2: `go run step2/main.go` でキャンセル検知を確認
- [ ] ステップ3: `go run step3/main.go` で `context deadline exceeded` を確認
- [ ] ステップ4: `go run step4/main.go` で requestID の伝播を確認
- [ ] ステップ5: `go test ./... -v` で 2 passed

**全チェック完了 = 今日の最小成果物が揃った状態。**

---

## 5. 追加課題（時間が余ったら）

### Easy
`worker` に「最大ループ回数」を渡し、キャンセルされなくてもその回数で終了するようにする。

<details>
<summary>回答例</summary>

```go
func worker(ctx context.Context, name string, max int) {
	for i := 0; i < max; i++ {
		select {
		case <-ctx.Done():
			fmt.Printf("%s: キャンセル (%v)\n", name, ctx.Err())
			return
		default:
			fmt.Printf("%s: %d\n", name, i)
			time.Sleep(100 * time.Millisecond)
		}
	}
	fmt.Printf("%s: 完了\n", name)
}
```

</details>

### Medium
`context.WithTimeout` の親に `WithCancel` を使い、タイムアウト前に手動で `cancel()` を呼んだ場合の挙動を確認する。`ctx.Err()` が `context.Canceled` になることを確認。

<details>
<summary>回答例</summary>

```go
func main() {
	ctx, cancel := context.WithCancel(context.Background())
	ctx, _ = context.WithTimeout(ctx, 5*time.Second)
	// 親の cancel を使う（WithTimeout の cancel は使わない）
	go func() {
		time.Sleep(500 * time.Millisecond)
		cancel()
	}()
	<-ctx.Done()
	fmt.Println(ctx.Err()) // context canceled
}
```

</details>

### Hard
3つの goroutine を起動し、1つがエラーを返したら残り2つも `cancel()` で一括停止するパターンを実装する。`errgroup` を使わず、手動で実装する。

<details>
<summary>回答例</summary>

```go
func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan error, 3)
	for i := 0; i < 3; i++ {
		go func(id int) {
			// シミュレーション: id==1 がエラー
			time.Sleep(time.Duration(id*500) * time.Millisecond)
			if id == 1 {
				done <- fmt.Errorf("worker %d failed", id)
				return
			}
			<-ctx.Done()
			done <- nil
		}(i)
	}

	err := <-done
	if err != nil {
		cancel()
		fmt.Println("エラーで全停止:", err)
	}
	time.Sleep(500 * time.Millisecond)
}
```

</details>

---

## 6. 実務での使いどころ（目安: 5分）

1. **HTTP サーバー**  
   `http.Request` に `Context()` が含まれる。ハンドラ内で DB クエリや外部 API 呼び出しに `req.Context()` を渡す。クライアントが切断すると context がキャンセルされ、不要な処理を早期に止められる。

2. **バッチ / ジョブ**  
   長時間処理のループ内で `ctx.Err() != nil` をチェック。デプロイや緊急停止時に、ジョブを安全に中断できる。

3. **gRPC / マイクロサービス**  
   各 RPC 呼び出しに context を渡す。タイムアウトやトレース ID を context で伝播し、分散トレーシングと連携できる。

---

## 7. まとめ（目安: 2分）

- goroutine は強制停止できない。**context** で「やめて」を伝え、子が協調的に抜ける設計にする。
- `WithCancel` / `WithTimeout` の `cancel` は **必ず** `defer cancel()` で呼ぶ。
- ブロックする処理では `select` で `ctx.Done()` を待ち、ループ内では `ctx.Err()` をチェックする。

---

## 8. 明日の布石（目安: 1分）

1. **errgroup**: 複数 goroutine のエラー集約と、1つ失敗したら他をキャンセルするパターン。
2. **channel と select**: context 以外のチャネルパターン（fan-out、fan-in、pipeline）との組み合わせ。
