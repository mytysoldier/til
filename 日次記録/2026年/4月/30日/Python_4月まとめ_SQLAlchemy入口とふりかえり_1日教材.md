# 1日教材: 4月まとめ — Python 全体ふりかえりと SQLAlchemy 入口

**参照**: [SQLAlchemy 2.0 ORM Quick Start](https://docs.sqlalchemy.org/en/20/orm/quickstart.html)（記法は 2.0 系の Declarative / `mapped_column` 前提）

**本編の目安合計: 60分**（崩れたときはハンズオン末尾の「予備」を削る）

### 4月の学び（リポジトリにプッシュ済み・ラフな地図）

**出典（ディレクトリ一覧）**: [mytysoldier/til — `日次記録/2026年/4月`](https://github.com/mytysoldier/til/tree/master/%E6%97%A5%E6%AC%A1%E8%A8%98%E9%8C%B2/2026%E5%B9%B4/4%E6%9C%88)

この月は **「画面の state とデータの流れ」** が横断テーマになりやすく、言語が Kotlin / Swift / Flutter / React Native / Go / Python / TypeScript（React）と分散している。**ふりかえりでは言語名より「状態・API・永続化」のどこで詰まったか**を1行ずつ拾うとよい。

| 束ね方 | 4月に置いた記録の例（フォルダ名レベル） |
|--------|------------------------------------------|
| モバイル UI と state | Kotlin（coroutine・sealed / MVVM・API と state）、Swift（Codable・enum / MVVM・async-await）、Flutter UI state、React Native UI 比較 |
| API・サーバ | Go（handler とデータフロー / API 入口）、FastAPI の入口 |
| フロント（横断） | React の State 設計（横断で揃える） |
| Python | asyncio とデータ処理の入口 |
| 比較・基盤 | Java と Kotlin の OOP 入門比較、Go の DB・repository、AI エージェント実装レビュー（依頼・改善の型） |

**今日の使い方（30秒でも可）**: 上の表を眺めて「自分が触った列」を思い出し、ステップ6のメモに **その列のどこがまだ薄いか**だけ書く。

---

## 1. 今日のゴール（1〜2行）

**目安時間: 1分**

SQLAlchemy 2.0 の最小ループ（モデル定義 → テーブル生成 → Session で INSERT/SELECT）を手元で一度通し、**上の4月の地図**と突き合わせて学びを短く整理し、5月に残す論点を1つに決める。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間: 5分**

以下は「今日のハンズオンに入る前の自己チェック」です。**括弧内が目安回答**です。

1. **トランザクションで commit と rollback が必要になる典型的な理由は？**  
   （複数 SQL を「全部成功 or 全部失敗」でまとめたいから。ORM でも `Session` はトランザクション単位で振る舞う。）

2. **リレーショナル DB で PRIMARY KEY を1つ置く主目的は？**  
   （行を一意に特定し、他テーブルから FOREIGN KEY で参照できるようにするため。）

3. **venv を使う主目的は？**  
   （プロジェクトごとにパッケージ版本を隔離し、グローバル環境と衝突させないため。）

---

## 3. 理論（重要ポイント3〜6個）

**目安時間: 11分**

今日は **「比較観点を1つに絞る」** ルールに従い、**ORM と素の SQL（DBAPI）** の違いだけを軸に置きます。

1. **ORM は「行を Python オブジェクトとして扱う」層**  
   テーブル行の寿命・関連・変更追跡を Session が抱えます。**よくある誤解**: 「ORM を使うと SQL を知らなくていい」→ **落とし穴**: パフォーマンスやロック、N+1 などは SQL 理解がないと事故る。

2. **SQLAlchemy 2.0 の推奨入口: Annotated Declarative（`DeclarativeBase` + `Mapped` + `mapped_column`）**  
   型注釈と列定義が揃い、チーム開発で読みやすい。**よくある誤解**: 「古い `declarative_base()` が必須」→ **落とし穴**: 新規コードは 2.0 ドキュメントの Quick Start に寄せた方が移行コストが下がる。

3. **今回扱う Session は「同期」API（`async` ではない）**  
   FastAPI などで `async def` ルートと組み合わせる場合は **`AsyncSession` と非同期ドライバ** が別テーマになる。**落とし穴**: 同期 Session を async ルートでそのままブロッキング I/O させると、イベントループを止めてレイテンシが悪化することがある。

4. **変更の永続化は `flush` / `commit` のタイミングに依存（状態の落とし穴）**  
   `add` しただけでは他の接続からは原則見えず、`commit` で確定する。**落とし穴**: `commit` を忘れると「動いていたのに別プロセスから見えない」。例外で `with Session` を抜けると、未コミットは **ロールバック** されやすい（コンテキスト終了時の挙動を信頼する前提を持つ）。

5. **メタデータ `Base.metadata.create_all()` は学習・小規模向け**  
   本番のスキーマ変更は **Alembic 等のマイグレーション** が基本。**よくある誤解**: 「create_all があればマイグレーション不要」→ **落とし穴**: 既存 DB に列を足しただけでは反映されないことが多く、**SQLite 学習なら `app.db` を消して作り直す**のが手早い（本番では非推奨）。

6. **Engine → Session の流れが「アプリの DB 入口」**  
   Engine は接続プールの工場、Session は「この単位でクエリと変更をまとめる」作業場。**よくある誤解**: 「Session を1個だけ長生き」→ **落とし穴**: Web ではリクエストスコープで Session を切るのが一般的（共有すると不整合・スレッド／並行の問題）。

**設計の選択肢と、今日の最小ハンズオンでの選択理由（1つ）**

- **選択**: Session 内で `add` → `commit`、`select` で読み取り。  
- **理由**: 公式 Quick Start と同じ流れで迷子になりにくい。**あえて採用しないもの**: 複雑な `relationship` や Repository 完全版（**追加課題** へ）。

> **本教材と「外部ライブラリ原則禁止」について**: 4月テーマで SQLAlchemy 入口が明示されているため、**例外的に SQLAlchemy のみ**追加します（DB は標準ライブラリ同梱の SQLite を利用）。

---

## 4. ハンズオン（手順）

**目安時間: 33分**（内訳の目安: 環境6 / コード20 / メモ5 / **予備2**）

**前提（迷子防止）**

- プロジェクトのルートは **`30日` フォルダ**（本 MD と同じ階層）。仮想環境は **必ずここで**作る。  
- Python を動かすときは **`tutorial` に `cd` してから** `python main.py` や `python -m unittest`。理由: `main.py` が `from models import ...` と書いており、**カレントディレクトリが `tutorial` のときだけ**そのまま解決する（パッケージ化は今日は扱わない）。

作業完了後のイメージ:

```text
30日/
├── .venv/
├── .gitignore          # tutorial/ を無視
├── requirements.txt
└── tutorial/           # 学習用（git では無視）
    ├── app.db          # 実行後に生成（SQLite ファイル）
    ├── models.py
    ├── main.py
    ├── test_note_counts.py
    └── april_reflection.md
```

### ステップ1: venv の作成と有効化

1. ターミナルで **`30日` に移動**する（`pwd` で場所を確認してもよい）。  
2. `python3 -m venv .venv`  
3. 有効化  
   - macOS / Linux（bash / zsh）: `source .venv/bin/activate`  
   - Windows（cmd）: `.venv\Scripts\activate.bat`  
   - Windows（PowerShell）: `.venv\Scripts\Activate.ps1`  
4. プロンプト先頭に `(.venv)` が付いていることを確認。

**確認方法**: `which python`（または Windows で `where python`）が `.venv` 配下を指す。

---

### ステップ2: `tutorial/` と `.gitignore`

1. まだ `30日` にいることを確認。`mkdir tutorial`  
2. `30日/.gitignore` に次の1行:

```gitignore
tutorial/
```

**確認方法**: Git 利用時は `git check-ignore -v tutorial` で無視ルールが当たる。未利用ならファイルがあればよい。

---

### ステップ3: `requirements.txt` の作成とインストール

`30日/requirements.txt`:

```text
sqlalchemy>=2.0,<3
```

1. `pip install -r requirements.txt`  
2. **ここで初めて** SQLAlchemy が入る。次で確認。

**確認方法**

- `python -c "import sqlalchemy; print(sqlalchemy.__version__)"` で **2.x** が表示される。  
- `pip show sqlalchemy` で Location が `.venv` 配下であること。

---

### ステップ4: `tutorial/models.py`（モデル = テーブル定義）

`tutorial/models.py` を新規作成:

```python
"""最小ノートモデル（SQLAlchemy 2.0）"""

from sqlalchemy import String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Note(Base):
    __tablename__ = "notes"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(120))
```

**確認方法**: `30日` に戻らず **`tutorial` にいる状態でも**、`python -m py_compile models.py`（`cd tutorial` 済みならこのコマンドでよい）。

---

### ステップ5: `tutorial/main.py`（DDL → INSERT → SELECT）

```python
"""エントリポイント: テーブル作成・投入・取得"""

from pathlib import Path

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from models import Base, Note

# tutorial/ 配下に SQLite ファイル（他プロセスと共有するとロックに注意）
DB_PATH = Path(__file__).resolve().parent / "app.db"
ENGINE = create_engine(f"sqlite:///{DB_PATH}", echo=False)


def init_db() -> None:
    Base.metadata.create_all(ENGINE)


def seed_if_empty() -> None:
    with Session(ENGINE) as session:
        exists = session.scalars(select(Note).limit(1)).first()
        if exists is not None:
            return
        session.add_all(
            [
                Note(title="4月: Python asyncio とデータ処理"),
                Note(title="4月: FastAPI 入口 × 状態・APIのつなぎ"),
            ]
        )
        session.commit()


def list_titles() -> list[str]:
    with Session(ENGINE) as session:
        rows = session.scalars(select(Note).order_by(Note.id)).all()
        return [r.title for r in rows]


if __name__ == "__main__":
    init_db()
    seed_if_empty()
    for title in list_titles():
        print(title)
```

**実行**（必ず `tutorial` で）:

```bash
cd tutorial
python main.py
```

**確認方法（期待される出力/挙動）**: 初回は2行のタイトルが出る。**もう一度** `python main.py` しても **行数が増えない**（重複 INSERT されない）。  
**練習用に作り直すとき**は `tutorial/app.db` を削除してから再実行（スキーマを変えたときも同様）。

---

### ステップ6: ふりかえりメモとテスト

`tutorial/april_reflection.md` に次を書く（各ブロック **3行以内** でよい）。**トピック一覧は教材冒頭の「4月の地図」の表をヒントに**、実際に手を動かした日付・テーマを思い出して列挙する。

- 4月に触れたトピック一覧（言語名だけでなく **state / API / 永続化** のどれだったかを添えるとなおよい）  
- 理解が曖昧なまま **1位**の論点  
- **5月に持ち越す論点（1つだけ）**

**テスト** `tutorial/test_note_counts.py`（標準 `unittest` のみ。**`cd tutorial` してから**実行）:

```python
import unittest

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from models import Base, Note


class TestNotePersistence(unittest.TestCase):
    def setUp(self) -> None:
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)

    def tearDown(self) -> None:
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def test_insert_and_count(self) -> None:
        with Session(self.engine) as session:
            session.add_all([Note(title="a"), Note(title="b")])
            session.commit()

        with Session(self.engine) as session:
            n = len(session.scalars(select(Note)).all())
        self.assertEqual(n, 2)

    def test_session_exit_without_commit_discards_changes(self) -> None:
        """commit せず with を抜けると、flush 済みでも通常は確定しない（Session 終了時にロールバックされやすい）。"""
        with Session(self.engine) as session:
            session.add(Note(title="orphan"))
            session.flush()

        with Session(self.engine) as session:
            n = len(session.scalars(select(Note)).all())
        self.assertEqual(n, 0)

    def test_exception_rollbacks_pending_writes(self) -> None:
        """例外でブロックを抜けたとき、未コミットの変更は残らない想定。"""
        try:
            with Session(self.engine) as session:
                session.add(Note(title="will-fail"))
                session.flush()
                raise RuntimeError("simulate failure")
        except RuntimeError:
            pass

        with Session(self.engine) as session:
            n = len(session.scalars(select(Note)).all())
        self.assertEqual(n, 0)


if __name__ == "__main__":
    unittest.main()
```

**確認方法**:

```bash
cd tutorial
python -m unittest test_note_counts.py
```

`Ran 3 tests ... OK` が出れば合格（テスト名は環境で多少変わってよい）。

---

### 詰まったとき（実務でよくある）

| 症状 | よくある原因 | 対処の例 |
|------|----------------|----------|
| `ModuleNotFoundError: models` | `30日` や他ディレクトリで `python tutorial/main.py` した | **`cd tutorial` してから** `python main.py` |
| `No module named 'sqlalchemy'` | venv 未効化／別の Python を叩いている | `source .venv/bin/activate` 後にもう一度 `pip install` |
| 列を足したのに反映されない | 既存 `app.db` が古いスキーマ | 学習用なら **`app.db` 削除** → 再実行 |
| `database is locked` | 同じ SQLite を複数プロセスが書いている | エディタの DB ビューアを閉じる／排他を避ける |

---

**予備（目安2分）**: `echo=True` に変えて `create_engine(..., echo=True)` とし、ログに SQL が出ることを一度見る。

---

**ここまでできれば今日のゴール達成**

---

## 5. 追加課題（時間が余ったら）

**目安時間: （本編の後・余裕があれば）**

### Easy（目安: 5〜10分）

`Note` に `body: Mapped[str] = mapped_column(String(500), default="")` を追加し、`create_all` が新規 DB で通ることを確認。既存 `app.db` があると列追加は自動では追いつかないので、**ファイル削除 or 別名 DB** で試す。

**回答の方向性**: `models.py` の列追加 → 新しい SQLite ファイルに `create_all` → `seed_if_empty` で `body` を渡す。

### Medium

`main.py` の「DB 触る部分」を **Session を引数で受け取る関数** に分割し、`main` は Session 生成だけにする（将来の Repository 化の入口）。

**回答例**:

```python
from collections.abc import Callable

from sqlalchemy.orm import Session


def with_session(engine, fn: Callable[[Session], None]) -> None:
    with Session(engine) as session:
        fn(session)
        session.commit()
```

※ 読み取り専用のみの関数に無条件 `commit` は避け、用途で分ける。

### Hard

公式 Unified Tutorial の「関連テーブル」章を読み、`User` / `Note` の **一対多** を `relationship` で繋いだ最小例を作る（[Working with ORM Related Objects](https://docs.sqlalchemy.org/en/20/tutorial/orm_related_objects.html)）。

**方向性**: `ForeignKey` + 双方向 `relationship(..., back_populates=...)`。

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間: 6分**

1. **社内サポート／障害チケットの永続化** — チケットID、ステータス（open/in_progress/closed）、対応者の社員ID、最終更新時刻を RDB に置き、社内ポータルから CRUD する API の裏（SQLite でも単一サーバ運用ならあり）。  
2. **夜間バッチの「取り込み記録」テーブル** — 例: S3 に届いたファイル名・ハッシュ・処理結果を `ingest_jobs` に INSERT し、失敗時だけ再キューする。ORM で検証可能な行オブジェクトにしておくと、運用ツールから同じモデルを再利用しやすい。  
3. **B2B の請求・課金ドラフト** — 締め前の明細行を RDB に保持し、確定トランザクションで状態を `draft` → `posted` に更新（本番では Postgres 等＋マイグレーション／監査ログが前提。**非機能**は別途）。

---

## 7. まとめ（今日の学び3行）

**目安時間: 2分**

- SQLAlchemy 2.0 は `DeclarativeBase` と `Mapped` / `mapped_column` でテーブルを Python に落とし、Session が変更とトランザクションの単位になる。  
- `commit`・例外時のロールバック・SQLite のファイルロックは、実務で詰まりやすいので早めに体感しておく。  
- 4月の振り返りを1枚に圧縮し、5月に持ち越す論点を1つに絞ると学習が加速する。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間: 2分**

1. **Alembic 最小導入**（`alembic init` → 初回 migration → 列追加の一連）  
2. **FastAPI + `AsyncSession`（または Depends 同期 Session）** で HTTP と DB をつなぐ — **非同期ルートではブロッキングをどう避けるか**まで一文で調べる  

---

## 参考リンク

- [SQLAlchemy 2.0 ORM Quick Start](https://docs.sqlalchemy.org/en/20/orm/quickstart.html)  
- [Unified Tutorial（深掘り用）](https://docs.sqlalchemy.org/en/20/tutorial/index.html)
