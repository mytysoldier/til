# Python asyncio 基礎 教材レビュー（実務目線）

---

## 1) 問題点（箇条書き）

### 時間配分
- 理論 10 分で 6 ポイントは詰め込み気味。初見だと 12〜15 分かかる可能性
- ハンズオン 38 分は、手順が不明瞭だと 45 分超えるリスクあり
- 合計 61 分は許容範囲だが、余裕がない

### 手順の不明瞭点（初心者が迷う箇所）
- **作業ディレクトリ**: 「23日フォルダで実行する」などの前提が書かれていない
- **venv**: 「有効化した状態で」とあるが、`python -m venv .venv` や `source .venv/bin/activate` の手順がない
- **ステップ 5**: 「実装する」とあるがコード全文が載っており、実装 vs コピペが曖昧
- **テスト実行**: `python -m unittest test_async_utils` はカレントが 23 日フォルダである必要があるが記載なし
- **pytest**: 教材では `pytest` を案内しているが、外部ライブラリは原則使わない方針と矛盾

### 落とし穴の不足
- **非同期**: 「ネストした asyncio.run()」の具体例・エラーメッセージがなく、遭遇時に気づきにくい
- **状態**: 共有状態（グローバル変数など）を非同期で扱う危険性に触れていない
- **エラー**: `return_exceptions=True` のとき、結果リストに例外オブジェクトが混ざる。`isinstance(r, Exception)` で分岐する実務パターンがハンズオンにない
- **型**: `run_delays` の戻り値 `List[float]` は型ヒントがあるが、gather の結果が「Union[T, BaseException]」になり得る点に触れていない
- **テスト**: `test_concurrent_not_sequential` が時刻に依存し、CI や負荷時にフレークする可能性。0.5 秒の閾値の根拠も不明

### ハンズオンが「動くもの」に確実につながるか
- ファイルは既に用意されているが、教材だけ読む人向けに「作成」手順になっている。両対応の説明がない
- ステップ 5 の「最小成果物」が `run_delays` のみで、実務でイメージしづらい

### テストの妥当性
- `test_returns_same_order`: 妥当。gather の順序保証を検証している
- `test_concurrent_not_sequential`: 時刻依存でフレークしうる。閾値 0.5 秒の根拠（0.2×3=0.6 直列 vs 0.2 並行）はコメントにあるが、マシン性能で変動する

### 実務での使いどころの具体性
- 「認証 API・ユーザー API・在庫 API」はイメージしやすいが、コード例がない
- 「同時接続数を制限」は Semaphore に触れているが、ハンズオンでは扱っていない
- WebSocket は抽象的な説明のみ

---

## 2) 改善案（箇条書き）

### 時間配分
- 理論: 8 分に短縮し、落とし穴を「読むだけ」に。深掘りは追加課題へ
- ハンズオン: 各ステップに「既にファイルがある場合は実行のみで OK」と注記。初回 40 分、再実行 25 分の目安を併記
- 合計: 60 分に収める（理論 8 + 事前 5 + ハンズオン 42 + 実務 3 + まとめ 2）

### 手順の明確化
- 冒頭に「前提」セクションを追加: 作業ディレクトリ（23日フォルダ）、venv の有効化手順、Python 3.7+
- 各ステップに「実行コマンドは 23 日フォルダで」と明記
- ステップ 5: 「実装する」→「以下のコードで async_utils.py / test_async_utils.py を作成する（既にあれば上書き）」に変更
- pytest の案内を削除し、unittest のみに統一（外部ライブラリ不使用の方針）

### 落とし穴の追加
- 理論 3.2: `asyncio.run()` のネストで出る `RuntimeError` の例を 1 行追加
- 理論に「3.7 共有状態」を追加: 非同期タスク間で mutable を共有すると競合する。実務ではなるべく引数で渡す
- エラー: ステップ 4 の確認方法に「結果の型が混在する（成功時は int、失敗時は Exception）ので、isinstance で分岐する」と補足
- テスト: `test_concurrent_not_sequential` の閾値を 0.6 秒に緩和し、「直列なら 0.6 秒以上」のコメントを明確化。または「並行なら 0.4 秒以下であること」を期待するなど、マシン差を考慮した表現に

### ハンズオンと動くもの
- ステップ 5 の成果物を「run_delays + テスト 2 本」と明示し、「これが今日の最小成果物」と断言
- 各ステップの確認方法に「❌ こうなったら」のトラブルシュートを 1 つずつ追加

### テスト
- `test_concurrent_not_sequential`: 閾値を 0.55 秒にし、「0.2×3=0.6 秒の直列実行より明らかに短い」ことを検証。または `asyncio.sleep(0.01)` で短くし、閾値 0.05 秒で並行を検証（フレークリスク低減）

### 実務での使いどころ
- 各例に「どんなコードになるか」の疑似コード（5 行程度）を追加
- 例 2 の「同時接続数制限」は、追加課題の Semaphore と紐づけて記載

---

## 3) 修正版教材（セクション構成は元のまま、必要箇所だけ差し替え）

以下、差し替え対象セクションのみ記載する。記載のないセクションは元のまま。

---

### 【追加】前提（教材冒頭、目次直後）

**作業環境**:
- 作業ディレクトリ: 本教材のフォルダ（`日次記録/2026年/2月/23日`）
- Python: 3.7 以上
- venv: `python -m venv .venv` で作成後、`source .venv/bin/activate`（Windows は `.venv\Scripts\activate`）で有効化

**ファイルについて**: 各ステップのファイルは教材フォルダに同梱されている。初回は手順に沿って作成し、既にある場合は実行のみでよい。

---

### 3. 理論（重要ポイント3〜6個）【目安: 8分】

（3.2 の落とし穴を強化）

### 3.2 イベントループ

- **ポイント**: 1 スレッド内で複数タスクを切り替えながら実行する仕組み。`asyncio.run()` がループを起動・終了する。
- **落とし穴**: `asyncio.run()` は 1 プロセス内で 1 回だけ起動する想定。ネストして呼ぶ（例: 同期的に呼ばれた関数内で `asyncio.run()` を再度呼ぶ）と `RuntimeError: asyncio.run() cannot be called from a running event loop` になる。

（3.6 の後に新規追加）

### 3.7 共有状態と競合

- **ポイント**: 複数タスクが同じ mutable オブジェクト（リスト、辞書など）を書き換えると競合する。asyncio は GIL 内だが、await の前後で切り替わるため、一見アトミックに見える操作も割り込まれる。
- **落とし穴**: グローバル変数や共有リストを「つい」使いたくなるが、実務では引数で渡し、戻り値で返す設計を心がける。

---

### 4. ハンズオン（手順）【目安: 42分】

環境: 上記「前提」を確認したうえで、`venv` を有効化し、**教材フォルダ（23日）をカレントディレクトリにして**実行する。外部ライブラリは使わない。

---

### ステップ 1: 最小コルーチンの実行（目安: 5分）

**手順**:
1. `hello_async.py` を作成する（既にあれば上書き）
2. 以下を書いて保存する

```python
import asyncio

async def main():
    print("Hello, asyncio!")
    await asyncio.sleep(1)
    print("Done.")

if __name__ == "__main__":
    asyncio.run(main())
```

3. 教材フォルダで `python hello_async.py` を実行する

**確認方法**: 1 秒間隔で `Hello, asyncio!` → `Done.` が表示される。

**❌ うまくいかない場合**: `ModuleNotFoundError` が出る場合は、カレントディレクトリが教材フォルダか確認する。

---

### ステップ 2〜4

（手順 3 を「教材フォルダで `python ○○.py` を実行する」に統一。確認方法は現状維持）

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
```

3. 教材フォルダで `python -m unittest test_async_utils -v` を実行する

**確認方法**: 2 テストともパスする。`test_concurrent_not_sequential` で、並行実行により 0.55 秒未満で終わることを確認する。

**❌ うまくいかない場合**: `test_concurrent_not_sequential` が落ちる場合、マシンが重いと 0.55 秒を超えることがある。そのときは閾値を `0.6` に変更して再実行し、直列（0.6 秒）より短いことを確認する。

---

### ステップ 4 の確認方法（補足追加）

**確認方法**: タスク 2 のみ例外、他は成功。3 件とも結果が表示される。`return_exceptions=True` のとき、結果リストには「成功時は戻り値（int）、失敗時は Exception オブジェクト」が混在する。実務では `isinstance(r, Exception)` で分岐して処理する。

---

### 6. 実務での使いどころ（具体例3つ）【目安: 3分】

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

*レビュー実施: 2026年2月23日*
