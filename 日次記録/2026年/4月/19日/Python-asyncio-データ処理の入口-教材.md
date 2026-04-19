# Python: asyncio とデータ処理の入口（1日教材）

参照: [asyncio — Asynchronous I/O](https://docs.python.org/3/library/asyncio.html)、[asyncio — タスクとコルーチン](https://docs.python.org/3/library/asyncio-task.html)、[asyncio キュー](https://docs.python.org/3/library/asyncio-queue.html)、[unittest.IsolatedAsyncioTestCase](https://docs.python.org/3/library/unittest.html#unittest.IsolatedAsyncioTestCase)、[Running an asyncio Program](https://docs.python.org/3/library/asyncio-runner.html#asyncio.run)

---

## 1. 今日のゴール（1〜2行）

**目安時間（分）:** 1

`async` / `await` と `asyncio.run()` で非同期処理を動かし、`asyncio.gather` と `asyncio.Queue` を使って「データが流れる」最小パイプラインを自分の手で再現できる状態になる。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間（分）:** 3

**Q1. 同期処理で `time.sleep(1)` を呼ぶと、その間スレッドはどうなる？**  
**A.** そのスレッドはブロックされ、同じスレッド上で他の処理は進みません（CPU を他スレッドに譲ることはあっても、**同じスレッド内の別タスクは進みません**）。

**Q2. `async def` で定義した関数を普通に `foo()` と呼ぶと、何が返る？**  
**A.** **コルーチンオブジェクト**が返ります。中身を実行するには `await foo()`（他の `async` 関数内）か、`asyncio.run(foo())` のようにイベントループに渡す必要があります。

**Q3. 「I/O 待ちが多い処理」と「CPU を延々占有する計算」のどちらが、まず asyncio の主戦場に向きやすい？**  
**A.** **I/O 待ちが多い処理**です。asyncio は単一スレッド上で協調的マルチタスクを回すモデルであり、重い計算はイベントループを占有しやすく、別の対策（オフロード等）が必要になります。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間（分）:** 11

重要ポイントは「イベントループ」「コルーチン」「I/O バウンド」「キューでのデータフロー」「失敗と境界」に絞ります。

1. **イベントループ**  
   公式の説明どおり、asyncio は **`async` / `await` 構文で並行コードを書くための基盤**です。`asyncio.run()` は「メインの非同期 `main` を走らせ、終了までループを回す」ための高水準 API です。  
   - **よくある誤解:** 「asyncio = マルチスレッドで速くなる」→ **単一スレッド上の協調的切り替え**が基本。スレッド並列とは役割が違います。  
   - **落とし穴:** **`asyncio.run()` の中から、さらに `asyncio.run()` を呼ばない**（ネストはエラーになる。既にループが動いている環境では別の入り方が必要）。

2. **`await` は「待つ」が、ブロックではない**  
   `await asyncio.sleep(0.1)` のような待ちでは、イベントループは**他のタスクに制御を渡せます**。  
   - **落とし穴:** ループ内で **`time.sleep()` や重い同期処理・巨大な同期ライブラリ呼び出し**をすると、**イベントループ全体が止まり**、他のコルーチンも進みません。I/O の代わりに **`asyncio.sleep` で待ち時間を模倣**するのは学習・テストでは定番です。

3. **`asyncio.gather` で複数コルーチンを「同時進行っぽく」**  
   `gather(*coros)` は複数のコルーチンをスケジュールし、完了をまとめて待ちます。  
   - **よくある誤解:** 「`gather` がスレッドプール」→ **あくまで同一イベントループ上のタスク**です。  
   - **落とし穴（エラー）:** デフォルトでは **どれか 1 つでも例外が出ると、その例外が `gather` 側に伝播**します（他のタスクの結果は取りこぼしやすい）。大量ジョブでは **`return_exceptions=True`** で結果に例外を載せる、**`TaskGroup`（3.11+）** でグルーピングする、などが現場では検討されます（今日は「起きうる」ことの認識まで）。

4. **`asyncio.Queue` でデータフロー（入口）**  
   生産者が `put`、消費者が `get` する**非同期キュー**です。複数コルーチン間で「次の仕事」を安全に渡すのに向きます。  
   - **落とし穴（状態）:** 普通の `list` に複数タスクから append すると、**競合や取りこぼし**が起きやすいです。まずは **`Queue` で境界をはっきり**させるのが安全です。  
   - **落とし穴（終了シグナル）:** 「もうデータはない」を表す値（センチネル）は、**本物のデータと値が衝突しない**ように選ぶ（例: `None`、専用のオブジェクト）。**`-1` のような数値**はドメイン次第で衝突しうる、と頭に置いておく。

5. **比較観点（今日は 1 つだけ）: I/O バウンドなら「スレッド」と「asyncio」のどちらを最初に選ぶ？**  
   - **asyncio:** HTTP クライアントや DB ドライバが **async 対応**しており、単一プロセスで大量の待ちをさばきたいとき。  
   - **`threading` / プロセスプール:** 既存コードが同期 API のみ、**ブロッキング I/O を並列に投げたい**ときや、**CPU バウンドを並列化**したいとき（役割が異なる）。  
   **今日のハンズオンでの選択:** 学習用に依存を増やさないため **`asyncio` + `asyncio.sleep` で I/O を模倣**します。実務では「ライブラリが async かどうか」と「処理が I/O か CPU か」が最初の分岐点になります。

---

## 4. ハンズオン（手順）

**目安時間（分）:** 33

作業ディレクトリは **本日のフォルダ**（この教材と `Python-asyncio-データ処理の入口-教材.md` と同じ階層）を想定します。**その直下に `.venv` を作り**、**`tutorial/` 配下に** Python ファイルを置きます（`cd tutorial` してから実行・テストする想定）。  
ルートに **`tutorial/` を除外する `.gitignore`** を置いてあります。

### ステップ 1: venv と `tutorial` フォルダ

1. ターミナルで **本日のフォルダ**（教材のあるディレクトリ）へ `cd` する。  
2. `python3 -m venv .venv`（Windows で `python3` が無い場合は `py -3 -m venv .venv` や `python -m venv .venv`）で仮想環境を作る。  
3. 有効化: `source .venv/bin/activate`（Windows は `.venv\Scripts\activate`）。  
4. `mkdir -p tutorial`（Windows は `mkdir tutorial`）し、**`cd tutorial`**。以降の `python` / `python -m unittest` は **この `tutorial` 内**で実行する。

**確認方法:** `python -c "import sys; print(sys.prefix)"` の出力に **`.venv`** が含まれること。`pwd`（Windows は `cd`）でカレントが **`.../19日/tutorial`** になっていること。

---

### ステップ 2: `async_io.py` と最小の `main.py`（`asyncio.run` と `await`）

**なぜファイルを分けるか:** テストで **`fake_io` を import** するため（`main.py` はエントリ用に差し替えやすくする）。実務でも「ロジックとエントリ分離」はよくある選択です。

`tutorial/async_io.py` を新規作成:

```python
# tutorial/async_io.py
import asyncio


async def fake_io(name: str, delay: float) -> str:
    """ブロッキングの代わりに asyncio.sleep で I/O を模倣する。"""
    await asyncio.sleep(delay)
    return f"{name}:ok"
```

`tutorial/main.py` を新規作成:

```python
# tutorial/main.py
import asyncio

from async_io import fake_io


async def main() -> None:
    result = await fake_io("step2", 0.05)
    print(result)


if __name__ == "__main__":
    asyncio.run(main())
```

実行: `python main.py`（`tutorial` 内）

**確認方法（期待される出力）:**  
`step2:ok` が 1 行表示される。

---

### ステップ 3: `asyncio.gather` で複数件を同時に待つ

`main.py` を次のように置き換える（`async_io.py` はそのまま）。

```python
# tutorial/main.py
import asyncio

from async_io import fake_io


async def main() -> None:
    results = await asyncio.gather(
        fake_io("a", 0.08),
        fake_io("b", 0.08),
        fake_io("c", 0.08),
    )
    for line in results:
        print(line)


if __name__ == "__main__":
    asyncio.run(main())
```

**確認方法:** 3 行 `a:ok` `b:ok` `c:ok` が出ること。  
**ざっくり計測:** `time.perf_counter()` で囲むと、直列なら約 0.24s、**gather なら最大に近い 0.08s 前後**（環境により多少の差はあってよい）。「同時に待てた」が体感できれば OK。

---

### ステップ 4: `asyncio.Queue` で「投入 → 処理」のデータフロー

`main.py` をキュー版に差し替える。終了は **`None` をセンチネル**にし、**`Queue[Optional[int]]`** で「整数か終了」を表す（`typing.Optional` を使用）。

```python
# tutorial/main.py
from __future__ import annotations

import asyncio
from typing import Optional


async def producer(q: asyncio.Queue[Optional[int]], items: list[int]) -> None:
    for x in items:
        await q.put(x)
    await q.put(None)  # 終了シグナル


async def worker(name: str, q: asyncio.Queue[Optional[int]]) -> None:
    while True:
        item = await q.get()
        try:
            if item is None:
                break
            await asyncio.sleep(0.02)  # 処理の代わり
            print(f"{name} processed {item}")
        finally:
            q.task_done()


async def main() -> None:
    q: asyncio.Queue[Optional[int]] = asyncio.Queue()
    items = [1, 2, 3, 4, 5]
    p = asyncio.create_task(producer(q, items))
    w = asyncio.create_task(worker("W1", q))
    await p
    await q.join()
    await w


if __name__ == "__main__":
    asyncio.run(main())
```

**確認方法:** `W1 processed 1` … `5` が出て、エラーなく終了する。  
**なぜ `task_done` / `join` か:** **`get` した側が `task_done` を呼び、`join` で「未処理の put が残っていない」**のを待てる、という公式の使い方の流れを学ぶためです。

---

### ステップ 5: テスト 1 本（`unittest.IsolatedAsyncioTestCase`）

**ハンズオンで書いた `fake_io` をテストする**（孤立した `double` だけだと本日のコードと繋がらないため）。`tutorial/test_pipeline.py` を作成。

```python
# tutorial/test_pipeline.py
import unittest

from async_io import fake_io


class TestFakeIo(unittest.IsolatedAsyncioTestCase):
    async def test_fake_io_zero_delay(self) -> None:
        self.assertEqual(await fake_io("ping", 0), "ping:ok")


if __name__ == "__main__":
    unittest.main()
```

実行: `python -m unittest test_pipeline.py`（**`tutorial` ディレクトリ内**）

**確認方法:** `Ran 1 test ... OK` のように **1 テスト成功**。

---

### 設計メモ（補助ツールの考え方）

- **同期の `list` で共有**せず、**`asyncio.Queue` で「次の仕事」を渡す**ようにすると、責務（誰が投入し、誰が処理するか）が線として追いやすいです。  
- 本格的なパイプラインではチャンク化・バックプレッシャー・**例外の扱い方針**などが増えますが、**今日は「Queue がデータの受け渡し口」**と捉えれば十分です。

---

**ここまでできれば今日のゴール達成**（`run` / `gather` / `Queue` / 本日の `fake_io` を検証する非同期テスト 1 本が一通り動く）。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）:** 5

### Easy（5〜10 分）

**課題:** `fake_io` の遅延を変え、`gather` の所要時間が **最長の遅延に近い**ことを print で確認する（`main.py` を一時的に gather 版に戻してよい）。

**回答例:**

```python
import asyncio
import time

from async_io import fake_io


async def main() -> None:
    t0 = time.perf_counter()
    await asyncio.gather(fake_io("a", 0.1), fake_io("b", 0.05))
    print("elapsed:", time.perf_counter() - t0)


if __name__ == "__main__":
    asyncio.run(main())
```

---

### Medium

**課題:** `producer` を 1、`worker` を 2 本にし、**同じ Queue から取り合う**簡易ワーカープールにする。終了は **`None` をワーカー数だけ `put`** する。

**回答例（一例）:**

```python
from __future__ import annotations

import asyncio
from typing import Optional


async def producer(q: asyncio.Queue[Optional[int]], items: list[int], workers: int) -> None:
    for x in items:
        await q.put(x)
    for _ in range(workers):
        await q.put(None)


async def worker(name: str, q: asyncio.Queue[Optional[int]]) -> None:
    while True:
        item = await q.get()
        try:
            if item is None:
                break
            await asyncio.sleep(0.01)
            print(f"{name} processed {item}")
        finally:
            q.task_done()


async def main() -> None:
    q: asyncio.Queue[Optional[int]] = asyncio.Queue()
    items = list(range(10))
    wn = 2
    await asyncio.gather(
        producer(q, items, wn),
        *[worker(f"W{i}", q) for i in range(wn)],
    )
    await q.join()


if __name__ == "__main__":
    asyncio.run(main())
```

---

### Hard

**課題:** `asyncio.Semaphore` で **同時に動く処理を最大 N に制限**する（HTTP の同時接続数制限のイメージ）。

**回答例:**

```python
import asyncio


async def limited_job(sem: asyncio.Semaphore, name: int) -> None:
    async with sem:
        await asyncio.sleep(0.05)
        print("done", name)


async def main() -> None:
    sem = asyncio.Semaphore(2)
    await asyncio.gather(*[limited_job(sem, i) for i in range(6)])


if __name__ == "__main__":
    asyncio.run(main())
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）:** 5

1. **非同期 Web / API（例: FastAPI + async エンドポイント）:** リクエスト処理の中で **複数の I/O（DB・外部 API）を `gather` で並行**し、レイテンシを抑える。ここでは **フレームワークがイベントループを用意**し、アプリは `async def` ハンドラを書くイメージ。  
2. **大量 URL のヘルスチェックや一覧取得（例: `aiohttp` 等の async クライアント）:** 「待ち」が支配的なら、**同期で直列に叩くよりスループットが伸びやすい**（ただし相手先のレート制限・同時接続数は **`Semaphore` や接続プール**で制御することが多い）。  
3. **社内のジョブ処理:** メッセージキュー（Redis / SQS 等）からタスクを受け取り、**ワーカープロセス内で `asyncio.Queue` に流し込み、複数コルーチンで消化**する、という構成は今日の `producer` / `worker` の延長（実際のキューはプロセス外になることが多い）。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）:** 1

- `asyncio.run` と `await` で、**単一スレッド上の並行（協調的）**として非同期処理を書ける。  
- **`gather` は複数の待ちを束ねる**、`Queue` はコルーチン間のデータ受け渡しの入口として使える。  
- I/O の代わりに **`asyncio.sleep` で挙動を模倣**し、**`IsolatedAsyncioTestCase` で本日の `fake_io` をテスト**できる。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）:** 1

1. **`asyncio` とファイル・サブプロセス**（`asyncio.create_subprocess_exec` や `asyncio.to_thread` でブロッキングを逃がす入口）  
2. **ストリーム処理・バックプレッシャ**（`asyncio.Queue` の `maxsize` や、キャンセル・タイムアウト `asyncio.wait_for` の基礎）
