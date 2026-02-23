# Python asyncio 基礎 — 1日分学習教材（最終版）

---

## 前提

**作業環境**:
- 作業ディレクトリ: 本教材のフォルダ（`日次記録/2026年/2月/23日`）
- Python: 3.7 以上
- venv: `python -m venv .venv` で作成後、`source .venv/bin/activate`（Windows は `.venv\Scripts\activate`）で有効化

**ファイルについて**: 各ステップのファイルは教材フォルダに同梱されている。初回は手順に沿って作成し、既にある場合は実行のみでよい。

---

## 1. 今日のゴール（1〜2行）【目安: 2分】

**asyncio の基本構文（async/await）を理解し、複数の I/O 待ちタスクを並行実行する最小プログラムを動かせるようになる。** 設計の選択肢とよくある罠を知り、実務で「いつ使うか」を判断できるレベルを目指す。

---

## 2. 事前知識チェック（3問）※回答も付ける【目安: 5分】

**Q1.** Python で「I/O バウンド」と「CPU バウンド」の違いを一言で説明せよ。

<details>
<summary>回答</summary>

- **I/O バウンド**: ネットワーク・ファイル・DB など、待ち時間が主なボトルネック
- **CPU バウンド**: 計算処理が主なボトルネック（asyncio の恩恵は小さい）
</details>

---

**Q2.** `async def` で定義した関数を呼び出しただけでは実行されない。なぜか？

<details>
<summary>回答</summary>

コルーチンオブジェクトが返るだけで、イベントループ上でスケジュールされていないため。`asyncio.run()` や `await` によって初めて実行される。
</details>

---

**Q3.** 非同期関数内で `time.sleep(1)` を使うと何が問題か？

<details>
<summary>回答</summary>

イベントループ全体をブロックする。その間、他のタスクが一切動かず、非同期のメリットが消える。代わりに `await asyncio.sleep(1)` を使う。
</details>

---

## 3. 理論（重要ポイント3〜6個）【目安: 8分】

各ポイントに「よくある誤解/落とし穴」を添える。

### 3.1 コルーチンと await

- **ポイント**: `async def` はコルーチンを定義する。`await` で「待機」し、その間にイベントループは他のタスクを実行できる。
- **落とし穴**: コルーチンを `func()` とだけ呼ぶと「実行されない」。`await func()` か `asyncio.run(func())` が必要。

### 3.2 イベントループ

- **ポイント**: 1 スレッド内で複数タスクを切り替えながら実行する仕組み。`asyncio.run()` がループを起動・終了する。
- **落とし穴**: `asyncio.run()` は 1 プロセス内で 1 回だけ起動する想定。ネストして呼ぶ（例: 同期的に呼ばれた関数内で `asyncio.run()` を再度呼ぶ）と `RuntimeError: asyncio.run() cannot be called from a running event loop` になる。

### 3.3 並行と並列の違い

- **ポイント**: asyncio は「並行（concurrent）」であり「並列（parallel）」ではない。1 スレッドで I/O 待ちを有効活用する。
- **落とし穴**: CPU バウンドな処理を asyncio に載せても速くならない。その場合は `ProcessPoolExecutor` を検討。

### 3.4 asyncio.gather の役割

- **ポイント**: 複数コルーチンを同時にスケジュールし、すべての結果をまとめて取得する。I/O 待ちの並行実行に最適。
- **落とし穴**: `return_exceptions=True` を付けないと、1 つでも例外が出ると他がキャンセルされる。失敗を許容するなら `return_exceptions=True` を検討。

### 3.5 ブロッキング呼び出しの禁止

- **ポイント**: 非同期関数内では `time.sleep`、同期的な `requests`、同期的な DB 呼び出しなどは避ける。
- **落とし穴**: 既存の同期ライブラリをそのまま使うと、イベントループをブロックする。非同期対応版（aiohttp, asyncpg など）を使う。

### 3.6 設計の選択肢: gather vs create_task

- **選択肢**: 複数タスクを並行実行するとき、`asyncio.gather()` か `asyncio.create_task()` のどちらを使うか。
- **gather**: タスク群をまとめて起動し、結果をリストで受け取る。シンプルで、失敗時の扱い（`return_exceptions`）も明示的。
- **create_task**: 個別にタスクを作り、後から `await` する。タスクのライフサイクルを細かく制御したいときに使う。
- **本教材の選択**: 入門では `gather` を採用。理由は「複数タスクを一括で扱う」というユースケースが多く、コードが読みやすいため。

### 3.7 共有状態と競合

- **ポイント**: 複数タスクが同じ mutable オブジェクト（リスト、辞書など）を書き換えると競合する。asyncio は GIL 内だが、await の前後で切り替わるため、一見アトミックに見える操作も割り込まれる。
- **落とし穴**: グローバル変数や共有リストを「つい」使いたくなるが、実務では引数で渡し、戻り値で返す設計を心がける。

---

## 4. ハンズオン（手順）【目安: 42分】

環境: 上記「前提」を確認したうえで、`venv` を有効化し、**教材フォルダ（23日）をカレントディレクトリにして**実行する。外部ライブラリは使わない。

### ステップ 1: 最小コルーチンの実行（目安: 5分）

**手順**:
1. `hello_async.py` を作成する（既にあれば上書き）
2. 以下を書いて保存する

```python
import asyncio

async def main():
    print("Hello, asyncio!", flush=True)
    await asyncio.sleep(1)
    print("Done.", flush=True)

if __name__ == "__main__":
    asyncio.run(main())
```

3. 教材フォルダで `python hello_async.py` を実行する

**確認方法**: 1 秒間隔で `Hello, asyncio!` → `Done.` が表示される。

**❌ うまくいかない場合**:
- `ModuleNotFoundError` が出る → カレントディレクトリが教材フォルダか確認する
- 何も表示されない → Python の標準出力がバッファリングされている。`print(..., flush=True)` を付けるか、`python -u hello_async.py` で実行する

---

### ステップ 2: 複数タスクの並行実行（目安: 8分）

**手順**:
1. `parallel_tasks.py` を作成する（既にあれば上書き）
2. 以下を書く

```python
import asyncio
import time

async def task(name: str, sec: float) -> str:
    print(f"[{time.strftime('%H:%M:%S')}] {name} 開始")
    await asyncio.sleep(sec)
    print(f"[{time.strftime('%H:%M:%S')}] {name} 完了")
    return name

async def main():
    start = time.perf_counter()
    results = await asyncio.gather(
        task("A", 2.0),
        task("B", 1.0),
        task("C", 1.5),
    )
    elapsed = time.perf_counter() - start
    print(f"結果: {results}, 所要時間: {elapsed:.2f}秒")

if __name__ == "__main__":
    asyncio.run(main())
```

3. 教材フォルダで `python parallel_tasks.py` を実行する

**確認方法**: 合計約 2 秒で終了する（直列なら 4.5 秒）。`結果: ['A', 'B', 'C'], 所要時間: 2.0x秒` のような出力になる。

---

### ステップ 3: 擬似 API の並行呼び出し（目安: 10分）

**手順**:
1. `fake_api.py` を作成する（既にあれば上書き）
2. 擬似 API を 3 本並行で呼び、結果をリストで受け取る

```python
import asyncio

async def fetch(id: int, delay: float) -> dict:
    await asyncio.sleep(delay)
    return {"id": id, "data": f"item_{id}"}

async def main():
    results = await asyncio.gather(
        fetch(1, 1.0),
        fetch(2, 0.5),
        fetch(3, 1.5),
    )
    for r in results:
        print(r)

if __name__ == "__main__":
    asyncio.run(main())
```

3. 教材フォルダで `python fake_api.py` を実行する

**確認方法**: 約 1.5 秒で終了し、`{'id': 1, 'data': 'item_1'}` など 3 件が表示される。

---

### ステップ 4: 例外処理の確認（目安: 7分）

**手順**:
1. `error_handling.py` を作成する（既にあれば上書き）
2. `return_exceptions=True` で、1 つ失敗しても他は続行する例を書く

```python
import asyncio

async def may_fail(n: int):
    await asyncio.sleep(0.3)
    if n == 2:
        raise ValueError(f"Error at {n}")
    return n

async def main():
    results = await asyncio.gather(
        may_fail(1), may_fail(2), may_fail(3),
        return_exceptions=True
    )
    for i, r in enumerate(results):
        status = "例外" if isinstance(r, Exception) else "成功"
        print(f"タスク{i+1}: {status} -> {r}")

if __name__ == "__main__":
    asyncio.run(main())
```

3. 教材フォルダで `python error_handling.py` を実行する

**確認方法**: タスク 2 のみ例外、他は成功。3 件とも結果が表示される。`return_exceptions=True` のとき、結果リストには「成功時は戻り値（int）、失敗時は Exception オブジェクト」が混在する。実務では `isinstance(r, Exception)` で分岐して処理する。

---

### ステップ 5: 最小成果物 + テスト（目安: 10分）

**手順**:
1. `async_utils.py` に以下のコードを書く（既にあれば上書き）
2. `test_async_utils.py` に以下のコードを書く（既にあれば上書き）

**async_utils.py**:

```python
import asyncio
from typing import List

async def run_delays(delays: List[float]) -> List[float]:
    """各 delay 秒待ってから delay を返す（並行実行）"""
    async def wait_and_return(d: float):
        await asyncio.sleep(d)
        return d

    return list(await asyncio.gather(*[wait_and_return(d) for d in delays]))
```

**test_async_utils.py**:

```python
import asyncio
import unittest
from async_utils import run_delays

class TestRunDelays(unittest.TestCase):
    def test_returns_same_order(self):
        result = asyncio.run(run_delays([0.1, 0.2, 0.1]))
        self.assertEqual(result, [0.1, 0.2, 0.1])

    def test_concurrent_not_sequential(self):
        import time
        start = time.perf_counter()
        asyncio.run(run_delays([0.2, 0.2, 0.2]))
        elapsed = time.perf_counter() - start
        # 直列なら 0.6 秒。並行なら約 0.2 秒。マシン差を考慮し 0.55 秒未満を期待
        self.assertLess(elapsed, 0.55)

if __name__ == "__main__":
    unittest.main()
```

3. 教材フォルダで `python -m unittest test_async_utils -v` を実行する

**確認方法**: 2 テストともパスする。`test_concurrent_not_sequential` で、並行実行により 0.55 秒未満で終わることを確認する。

**❌ うまくいかない場合**: `test_concurrent_not_sequential` が落ちる場合、マシンが重いと 0.55 秒を超えることがある。そのときは閾値を `0.6` に変更して再実行し、直列（0.6 秒）より短いことを確認する。

---

## 5. 追加課題（時間が余ったら）【目安: 余裕時】

- **Easy**: `asyncio.wait_for` で 2 秒タイムアウトを設定し、3 秒かかるタスクが `TimeoutError` になることを確認する
- **Medium**: `create_task` で 3 つのタスクを個別に起動し、`as_completed` で「完了した順」に結果を表示する
- **Hard**: 擬似 API を 5 本呼び、`Semaphore(2)` で同時実行数を 2 に制限する（スロットリングのシミュレーション）

<details>
<summary>追加課題の回答</summary>

**Easy**

```python
import asyncio

async def slow_task():
    await asyncio.sleep(3)
    return "done"

async def main():
    try:
        await asyncio.wait_for(slow_task(), timeout=2.0)
    except asyncio.TimeoutError:
        print("TimeoutError になりました")

asyncio.run(main())
```

**Medium**

```python
import asyncio

async def task(name: str, sec: float) -> str:
    await asyncio.sleep(sec)
    return name

async def main():
    t1 = asyncio.create_task(task("A", 2.0))
    t2 = asyncio.create_task(task("B", 0.5))
    t3 = asyncio.create_task(task("C", 1.0))
    for coro in asyncio.as_completed([t1, t2, t3]):
        result = await coro
        print(result)

asyncio.run(main())
# 出力例: B → C → A（完了した順）
```

**Hard**

```python
import asyncio

async def fetch(sem: asyncio.Semaphore, id: int, delay: float) -> dict:
    async with sem:
        await asyncio.sleep(delay)
        return {"id": id, "data": f"item_{id}"}

async def main():
    sem = asyncio.Semaphore(2)
    tasks = [fetch(sem, i, 1.0) for i in range(5)]
    results = await asyncio.gather(*tasks)
    for r in results:
        print(r)

asyncio.run(main())
```

</details>

---

## 6. 実務での使いどころ（具体例3つ）【目安: 3分】

1. **マイクロサービス間の並行呼び出し**: 認証 API・ユーザー API・在庫 API を同時に呼び、結果をマージしてレスポンスを返す。
   ```python
   # イメージ
   auth, user, stock = await asyncio.gather(
       auth_client.get_token(),
       user_client.get_profile(user_id),
       stock_client.get_inventory(item_id),
   )
   ```
2. **バッチ処理の I/O 最適化**: 大量の URL をスクレイピングするとき、同時接続数を制限しつつ並行で取得する。（`Semaphore` で同時実行数を制限。追加課題 Hard を参照）
3. **WebSocket / 長時間接続**: 1 プロセスで多数の WebSocket 接続を扱う。FastAPI の `async def` エンドポイントで `await websocket.receive()` のように待機する。

---

## 7. まとめ（今日の学び3行）【目安: 2分】

- **async/await** と **asyncio.run** で、I/O 待ちを有効活用する並行処理が書ける
- **gather** で複数タスクを一括実行し、`return_exceptions=True` で部分的な失敗を許容できる
- 非同期関数内では **ブロッキング呼び出し（time.sleep など）を避け**、`asyncio.sleep` や非同期対応ライブラリを使う

---

## 8. 明日の布石（次のテーマ候補を2つ）【目安: 1分】

1. **aiohttp で非同期 HTTP クライアント** — 実 API を並行で叩き、レスポンスを扱う
2. **FastAPI の非同期エンドポイント** — `async def` のルートハンドラで DB や外部 API を await する設計

---

## 付録: レビュー（実務目線）

本教材は実務目線でレビューし、以下の問題点・改善案を反映した最終版である。

### 問題点（レビュー時）

| 観点 | 内容 |
|------|------|
| **時間配分** | 理論 10 分で 6 ポイントは詰め込み気味。ハンズオン 38 分は手順不明瞭だと 45 分超えるリスク |
| **手順** | 作業ディレクトリ・venv 手順・カレントの前提が不足。pytest 案内が外部ライブラリ不使用方針と矛盾 |
| **落とし穴** | ネストした asyncio.run() のエラー例、共有状態の競合、return_exceptions の型混在、テストのフレーク性 |
| **動くもの** | ファイル同梱と「作成」手順の両対応が不明瞭 |
| **テスト** | test_concurrent_not_sequential が時刻依存でフレークしうる。閾値の根拠が不明 |
| **実務例** | コード例がなく抽象的な説明のみ |

### 改善案（反映済み）

| 観点 | 反映内容 |
|------|----------|
| **時間配分** | 理論 8 分、ハンズオン 42 分に調整。合計 60 分前後 |
| **手順** | 冒頭に「前提」を追加（作業 Dir、venv、Python 3.7+）。各ステップに「教材フォルダで」を明記。pytest 削除、unittest のみ |
| **落とし穴** | 3.2 に RuntimeError の具体例を追加。3.7「共有状態と競合」を新設。ステップ 4 に isinstance 分岐の補足。テスト閾値を 0.55 秒にしコメントで根拠を明示 |
| **動くもの** | 「既にあれば上書き」を全ステップに追加。❌ トラブルシュートをステップ 1・5 に追加 |
| **テスト** | 閾値 0.55 秒、コメントで「直列 0.6 秒 vs 並行 0.2 秒」を明記。落ちた場合の対処を記載 |
| **実務例** | 例 1 に疑似コード追加。例 2・3 を Semaphore・WebSocket で具体化 |

---

*教材作成: 2026年2月23日 | レビュー反映・最終版: 2026年2月23日*
