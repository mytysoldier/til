# Python cancellation設計 — 1日分の学習教材

**時間配分（合計60分）:** ゴール 2分 / 事前 5分 / 理論 10分 / ハンズオン 30分 / 実務 5分 / まとめ 3分 / 布石 2分 / バッファ 3分

## 1. 今日のゴール（目安: 2分）

非同期処理や長時間タスクにおいて、**安全に処理を中断・キャンセルする設計**ができるようになる。`asyncio.CancelledError` の扱いと、自前のキャンセル機構（フラグ・イベント）の使い分けを理解する。

---

## 2. 事前知識チェック（目安: 5分）

### Q1. `asyncio.Task.cancel()` を呼ぶと、そのタスクは即座に停止するか？

**回答:** いいえ。`cancel()` は `CancelledError` をタスクに送るだけで、タスクがその例外を処理する（または伝播させる）まで停止しない。`await` の境界でしか割り込みが入らない。

### Q2. `threading.Event` と `asyncio.Event` の主な違いは何か？

**回答:** `threading.Event` はスレッド用の同期プリミティブで、`asyncio.Event` は非同期用。`asyncio.Event.wait()` は `await` 可能で、他のコルーチンをブロックしない。用途は似ているが、使う並行モデルが違う。

### Q3. `try/finally` で `CancelledError` を捕捉した場合、クリーンアップ処理は実行されるか？

**回答:** 実行される。`CancelledError` は `BaseException` のサブクラスで、`except Exception` では捕捉されないが、`finally` は必ず実行される。ただし `finally` 内で `await` すると、その時点で再度キャンセルされる可能性がある。

---

## 3. 理論（目安: 10分）

### 重要ポイント1: キャンセルの2つのレイヤー

- **asyncio のキャンセル**: `Task.cancel()` → `CancelledError`。タスク単位で、`await` の境界で割り込み。
- **アプリケーションのキャンセル**: フラグや `Event` で「やめて」を伝え、ループ内でチェックして抜ける。

**よくある誤解:** 「cancel() を呼べばすぐ止まる」と思いがち。実際は、タスクが `await` している最中でないと割り込みが入らない。

### 重要ポイント2: キャンセル可能な設計のパターン

1. **ポーリング型**: ループ内で `cancelled` フラグや `Event.is_set()` を定期的にチェック。
2. **イベント駆動型**: `asyncio.Event` や `asyncio.Condition` で待機し、キャンセル時に `set()` して待機を解除。
3. **タスク委譲型**: 長時間処理を別タスクに切り出し、`Task.cancel()` でまとめてキャンセル。

**落とし穴:** ループ内でチェックしないと、CPU バウンドな処理はキャンセルできない。`await` のない純粋な計算ループは割り込み不可。

### 重要ポイント3: `CancelledError` の伝播と抑制

- デフォルトでは `CancelledError` は伝播し、タスクは `CancelledError` で終了する。
- `except CancelledError:` で捕捉して `raise` し直さないと、キャンセルが「消化」されたとみなされ、タスクは正常終了扱いになる。
- クリーンアップが必要な場合は `try/finally` を使い、`finally` 内でリソース解放。必要なら `raise` で再送出。
- **finally 内の await の危険性**: `finally` 内で `await` すると、その時点で割り込みが入り、親がキャンセルしている場合に再度 `CancelledError` が入る。クリーンアップ途中で例外が飛ぶと、後続の解放処理が実行されない可能性がある。`finally` 内は同期的な処理（ファイルクローズ、ロック解放など）に留めるのが安全。

**よくある誤解:** `except Exception` で `CancelledError` も捕捉してしまうと、キャンセルが正しく伝播しない。`CancelledError` は `Exception` のサブクラスではない（Python 3.8+）。

### 重要ポイント4: Event の再利用と clear()

- `Event.set()` した後、同じ Event を再度使うには `Event.clear()` が必要。忘れると「常にキャンセル済み」のままになる。
- 1回限りのキャンセルなら clear 不要。同じワーカーを再起動する設計なら必須。

**落とし穴:** 再利用時に `clear()` を忘れると、2回目以降のタスクが即座に「キャンセル検知」して終了する。

### 重要ポイント5: スレッドとの併用・gather の注意

- `threading.Event` はスレッド間で使える。asyncio からスレッドを止めたいときは、`Event.set()` で合図し、スレッド側で `Event.is_set()` をポーリングするか、`Event.wait(timeout=0.1)` で短いタイムアウトを繰り返す。
- `asyncio.gather(..., return_exceptions=True)` の場合、`CancelledError` が例外として結果リストに含まれる。`isinstance(r, asyncio.CancelledError)` で判定が必要。
- `concurrent.futures` の `Future.cancel()` は、まだ実行開始前のタスクにしか効かない。

**落とし穴:** 実行中のスレッドを強制停止する API はない。協調的な停止（フラグチェック）が基本。

### 重要ポイント6: 設計の選択肢 — なぜ「ポーリング + Event」を選ぶか

**選択肢:**
- A: `Task.cancel()` のみに頼る
- B: アプリケーション用の `Event` を用意し、ループ内でチェック
- C: 両方組み合わせる（タスクキャンセル + ループ内チェック）

**推奨:** 長時間のループ処理がある場合は B または C。理由: `await` のないループは `cancel()` だけでは止まらない。`Event` で「やめて」を伝え、ループ内で `if event.is_set(): break` する設計が確実。

---

## 4. ハンズオン（目安: 30分）

### 環境準備（事前に済ませておく）

```bash
# この教材のディレクトリ（24日フォルダ）で実行。他環境の場合は教材が置いてあるパスへ cd
cd 24日
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install pytest pytest-asyncio  # テスト用（最小限）
```

既存の `.py` ファイルがある場合は上書きで OK。

### ステップ1: 最小のキャンセル可能ループを作る（6分）

`cancellable_loop.py` を作成:

```python
import asyncio

async def cancellable_count(cancel_event: asyncio.Event, max_count: int = 100):
    """キャンセル可能なカウントループ"""
    for i in range(max_count):
        if cancel_event.is_set():
            print(f"[キャンセル] i={i} で停止")
            return i
        await asyncio.sleep(0.1)  # 割り込みポイント
        print(i)
    return max_count

async def main():
    cancel = asyncio.Event()
    task = asyncio.create_task(cancellable_count(cancel, 50))
    await asyncio.sleep(1.5)  # 約15回カウント後
    cancel.set()
    result = await task
    print(f"結果: {result}")

asyncio.run(main())
```

**実行:** `python cancellable_loop.py`

**確認方法:** 0〜14 が表示され、最後に `[キャンセル] i=15 で停止` と出る。`i=15` の時点でチェックして止まるため、15 は表示されない。`結果: 15` と表示されれば OK。

### ステップ2: Task.cancel() との違いを体験する（6分）

`task_cancel_demo.py` を作成:

```python
import asyncio

async def no_await_loop():
    """await のないループ — cancel() が効きにくい"""
    total = 0
    for _ in range(50_000_000):  # マシン差で数秒かかる
        total += 1
    return total

async def main():
    task = asyncio.create_task(no_await_loop())
    await asyncio.sleep(0.01)
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        print("CancelledError を捕捉")
    print("終了")

asyncio.run(main())
```

**実行:** `python task_cancel_demo.py`

**確認方法:** `cancel()` は 0.01 秒後に呼ばれるが、ループに `await` がないため数秒待たされる（マシン差で 2〜10 秒程度）。その後 `CancelledError を捕捉` → `終了` と出る。ループ中は割り込みが入らないことを体感する。

### ステップ3: クリーンアップ付きキャンセル（6分）

`cleanup_on_cancel.py` を作成:

```python
import asyncio

async def with_cleanup(cancel_event: asyncio.Event):
    resource = []
    try:
        for i in range(20):
            if cancel_event.is_set():
                raise asyncio.CancelledError()
            resource.append(i)
            await asyncio.sleep(0.1)
    finally:
        # 注意: finally 内で await すると再キャンセルされる可能性あり
        print(f"[クリーンアップ] resource 長さ={len(resource)} を解放")

async def main():
    cancel = asyncio.Event()
    task = asyncio.create_task(with_cleanup(cancel))
    await asyncio.sleep(1.0)
    cancel.set()
    try:
        await task
    except asyncio.CancelledError:
        print("タスクがキャンセルされました")

asyncio.run(main())
```

**実行:** `python cleanup_on_cancel.py`

**確認方法:** `[クリーンアップ] resource 長さ=10 を解放` のような出力が出る。`finally` がキャンセル時にも実行されることを確認。

### ステップ4: 複数タスクの一括キャンセル（6分）

`cancel_all.py` を作成:

```python
import asyncio

async def worker(name: str, cancel: asyncio.Event):
    for i in range(100):
        if cancel.is_set():
            print(f"{name}: キャンセル検知")
            return
        await asyncio.sleep(0.1)
        if i % 5 == 0:
            print(f"{name}: {i}")

async def main():
    cancel = asyncio.Event()
    tasks = [asyncio.create_task(worker(f"W{i}", cancel)) for i in range(3)]
    await asyncio.sleep(1.2)
    cancel.set()
    await asyncio.gather(*tasks)
    print("全タスク終了")

asyncio.run(main())
```

**実行:** `python cancel_all.py`

**確認方法:** 3つのワーカーが並行で動き、`cancel.set()` 後にすべてが「キャンセル検知」して終了する。

### ステップ5: テストを書く（6分）

`test_cancellation.py` を作成:

```python
import pytest
import asyncio

async def cancellable_count(cancel_event: asyncio.Event, max_count: int = 100):
    for i in range(max_count):
        if cancel_event.is_set():
            return i
        await asyncio.sleep(0.01)
    return max_count

@pytest.mark.asyncio
async def test_cancel_stops_early():
    """キャンセルで早期終了する"""
    cancel = asyncio.Event()
    task = asyncio.create_task(cancellable_count(cancel, 50))
    await asyncio.sleep(0.05)
    cancel.set()
    result = await task
    assert result < 50, "キャンセルで早期終了するはず"

@pytest.mark.asyncio
async def test_completes_without_cancel():
    """キャンセルなしで max_count まで完了する"""
    cancel = asyncio.Event()
    result = await cancellable_count(cancel, 10)
    assert result == 10
```

`pytest.ini` を作成（pytest-asyncio 用）:

```ini
[pytest]
asyncio_mode = auto
```

**実行:** `pytest test_cancellation.py -v`

**確認方法:** 2 件のテストが PASS する。

### 全ステップ実行確認チェックリスト

- [ ] ステップ1: `cancellable_loop.py` で 0〜14 表示 → `結果: 15`
- [ ] ステップ2: `task_cancel_demo.py` で数秒待機後 `CancelledError を捕捉`
- [ ] ステップ3: `cleanup_on_cancel.py` で `[クリーンアップ]` 表示
- [ ] ステップ4: `cancel_all.py` で 3 ワーカーが `キャンセル検知`
- [ ] ステップ5: `pytest test_cancellation.py -v` で 2 passed

**全チェック完了 = 今日の最小成果物が揃った状態。** 各ステップは独立しているが、これらを一通り動かせれば「キャンセル可能な非同期処理」の設計パターンを体得できている。

---

## 5. 追加課題（時間が余ったら）

### Easy
`cancellable_count` に「キャンセル理由」を文字列で渡せるようにし、停止時にその理由を表示する。

<details>
<summary>回答例</summary>

```python
async def cancellable_count(cancel_event: asyncio.Event, max_count: int = 100, reason: str = ""):
    for i in range(max_count):
        if cancel_event.is_set():
            msg = f"[キャンセル] i={i} で停止"
            if reason:
                msg += f": {reason}"
            print(msg)
            return i
        await asyncio.sleep(0.01)
    return max_count

# 使用例
cancel = asyncio.Event()
task = asyncio.create_task(cancellable_count(cancel, 50, reason="ユーザーが中断"))
await asyncio.sleep(0.05)
cancel.set()
await task  # → [キャンセル] i=5 で停止: ユーザーが中断
```

</details>

### Medium
`asyncio.wait_for(cancellable_count(...), timeout=2.0)` でタイムアウトキャンセルを試す。`TimeoutError` と `CancelledError` の扱いの違いを確認する。

<details>
<summary>回答例</summary>

```python
async def main():
    cancel = asyncio.Event()
    try:
        result = await asyncio.wait_for(cancellable_count(cancel, 100), timeout=2.0)
        print(f"完了: {result}")
    except asyncio.TimeoutError:
        print("タイムアウト: 2秒後に強制終了")
    except asyncio.CancelledError:
        print("キャンセル: Event で停止")

# 違い: wait_for は内部で Task.cancel() を使い、タイムアウト時は CancelledError を
# TimeoutError に変換して再送出する。Event によるキャンセルは CancelledError のまま。
```

</details>

### Hard
`threading.Thread` で重い計算を実行し、`threading.Event` で協調的に停止するサンプルを作成。asyncio のメインループから `Event.set()` で停止を指示する構成にする。

<details>
<summary>回答例</summary>

```python
import asyncio
import threading

def heavy_worker(stopped: threading.Event):
    total = 0
    for i in range(100_000_000):
        if stopped.is_set():
            print(f"[スレッド] キャンセル検知 i={i}")
            return total
        total += 1
    return total

async def main():
    stopped = threading.Event()
    thread = threading.Thread(target=heavy_worker, args=(stopped,))
    thread.start()
    await asyncio.sleep(1.0)
    stopped.set()
    thread.join()
    print("スレッド終了")

asyncio.run(main())
```

</details>

---

## 6. 実務での使いどころ（目安: 5分）

1. **長時間のバッチ処理（Celery/RQ 等）**  
   ジョブ内で `cancel_event.is_set()` を定期的にチェック。デプロイや緊急停止時に安全に止める。例: `for item in queue: if cancel.is_set(): break; process(item)`。

2. **WebSocket / ストリーミング**  
   接続ごとにタスクを起動し、`on_disconnect` で `cancel_event.set()` を呼ぶ。タスク側はループ内でチェックして抜け、リソースリークを防ぐ。

3. **並列ダウンロード（aiohttp 等）**  
   複数 URL を `asyncio.gather` で並列取得。1つ失敗したら共有の `Event.set()` で他タスクに伝え、各タスクは `if cancel.is_set(): return` で早期終了。

---

## 7. まとめ（目安: 3分）

- キャンセルには **asyncio の Task.cancel()** と **アプリケーションの Event/フラグ** の2段階がある。
- `await` のないループは `cancel()` だけでは止まらない。ループ内で `Event.is_set()` をチェックする設計が重要。
- クリーンアップは `try/finally` で行い、`CancelledError` は必要に応じて再送出する。Event を再利用する場合は `clear()` を忘れずに。

---

## 8. 明日の布石（目安: 2分）

1. **asyncio の TaskGroup / 例外グループ**: 複数タスクの一括管理と、`ExceptionGroup` の扱い。
2. **contextvars とキャンセル伝播**: リクエスト単位のコンテキストをキャンセルと組み合わせる設計。
