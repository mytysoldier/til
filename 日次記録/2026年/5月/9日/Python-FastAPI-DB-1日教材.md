# Python: FastAPI + DB（1日分・60分想定）

参照: [FastAPI — SQL (Relational) Databases](https://fastapi.tiangolo.com/tutorial/sql-databases/)（セッションと依存注入の考え方）、[FastAPI — Testing](https://fastapi.tiangolo.com/tutorial/testing/)（`TestClient`）、[SQLAlchemy 2.0 — ORM Quick Start](https://docs.sqlalchemy.org/en/20/orm/quickstart.html)（`Mapped` / `mapped_column`）

---

## 1. 今日のゴール（1〜2行）

**目安時間（分）: 1**

SQLite と SQLAlchemy で「Item」の CRUD を行う最小の FastAPI を、`tutorial/` 以下に組み立て、`/docs` から一通り操作できること。あわせて **pytest 1 本** で POST→GET を検証し、開発用 DB とテスト DB を切り分ける入口を押さえること。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間（分）: 5**

**Q1. REST でリソース「items」を表すコレクション URL はどちらが一般的か。**  
**A1.** `/items` のような複数形コレクション配下にするのが一般的である（単一リソースは `/items/{id}`）。

**Q2. HTTP メソッドで「新規作成」「取得」「（広義の）更新」「削除」に当てはまりやすいものは。**  
**A2.** 作成は `POST`、取得は `GET`、更新は `PUT` または `PATCH`（この教材では `PATCH`）、削除は `DELETE` が代表的である。

**Q3. ORM のモデルクラスをそのまま API の入出力に使うと何が起きやすいか。**  
**A3.** DB カラムの変更や内部フィールドがそのまま外部仕様に漏れ、クライアントとの結合が強くなる。また入力検証の境界が曖昧になりやすい。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間（分）: 12**

- **責務分離（ルート／CRUD／DB）**  
  ルートは HTTP とステータスコード、`crud` はクエリとトランザクション単位の操作、`database`/`models` は接続とテーブル定義に寄せる。**よくある誤解:** 「とりあえずルートに SQL を書く」ことで最初は早いが、テストと変更が苦しくなる。

- **DTO（Pydantic）で入口・出口を固定する／比較は今日はこれだけ**  
  入力は `ItemCreate`、更新は `ItemUpdate`、返却は `ItemRead`。**「DTO で境界を切る」vs「ORM をそのまま返す」では DTO を選ぶ** — HTTP の契約をモデルから独立させられるからである。`ItemRead` には `model_config = ConfigDict(from_attributes=True)` が必要。**よくある誤解:** ORM をそのまま返せば楽だが公開仕様が緩く伸びやすい。`from_attributes` を忘れるとレスポンス組み立てで落ちる。

- **`Depends(get_db)` とセッション寿命**  
  `yield` でリクエスト単位に開閉する。**よくある誤解:** グローバルに 1 セッションを共有するとスレッド／並行性で破綻しやすい。

- **同期ルート・SQLite・非同期への入口**  
  教材は **`def` + 同期 `Session`**。SQLite は `check_same_thread=False` が必要なことがあり、同時書き込みに弱い。**よくある誤解:** 「FastAPI だから `async def`」だけを増やし同期 DB を直叩きするとイベントループを塞ぎやすい。負荷が載ったら非同期スタックや PostgreSQL など別選択となる。

- **コミット・例外・状態**  
  例外発生時は **`rollback()`** を検討し、トランザクション境界をどこで切るかを決める（サービス層など）。今日の `crud` は最小のため省略している。**よくある誤解:** `commit()` だけ書けばよい。

- **テスト・HTTP の落とし穴**  
  開発用 `items.db` でそのまま pytest すると手動検証データと混ざり **フレーク** の元になる。**実務では** `dependency_overrides` で `get_db` を差し替え、インメモリ SQLite（`StaticPool`）等へ。**DELETE が `204`** のときボディは返さない設計が筋がよい。**よくある誤解:** TestClient が通れば同一ファイルでよい。別要件で「標準ライブラリのみ」とぶつかるときは、HTTP/ORM のために `fastapi`、`uvicorn`、`sqlalchemy`、`pytest`、`httpx` を最小限認める、という整理になる。

---

## 4. ハンズオン（手順）

**目安時間（分）: 34**

**このセクションを通じて守ること**

- コマンド例では **`tutorial/` をカレントディレクトリにしたまま** 実行する（`mkdir tutorial && cd tutorial` のあとに一度移動し、そのターミナルでは出ない）。
- Python のモジュール解決は **`tutorial/` がカレント** のとき `app` パッケージとして読める。親フォルダから `uvicorn` を叩くと `ModuleNotFoundError: app` になりやすい。
- `.venv` を有効化したシェルで `pip` と `pytest`、`uvicorn` を実行する。

作業ルートは `tutorial/` とする（日付フォルダ直下）。**このディレクトリ用の `.gitignore` に `tutorial/` を書いておく** と学習用生成物をコミットしやすい。

### ステップ 1: `tutorial/` と venv、依存関係

1. 日付フォルダで `mkdir tutorial && cd tutorial`
2. `python3 -m venv .venv && source .venv/bin/activate`（Windows は `.venv\Scripts\activate`）
3. `requirements.txt` を作成して保存する。

```txt
fastapi>=0.115.0
uvicorn[standard]>=0.30.0
sqlalchemy>=2.0.0
pytest>=8.0.0
httpx>=0.27.0
```

4. `python -m pip install -r requirements.txt`

**確認方法（期待される出力／挙動）:** `python -m pip show fastapi sqlalchemy` でパッケージ情報が表示され、`python -c "import fastapi, sqlalchemy"` がエラーなく終わること。

---

### ステップ 2: `app/database.py` と `app/models.py`

`mkdir app` のうえで `app/__init__.py` は空ファイルでよい（`touch app/__init__.py` など）。

**`app/database.py`**

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

SQLALCHEMY_DATABASE_URL = "sqlite:///./items.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

**`app/models.py`**

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Item(Base):
    __tablename__ = "items"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(index=True)
    description: Mapped[str | None] = mapped_column(default=None)
```

**確認方法:** `tutorial/` で venv を有効化したうえで  
`python -c "from app.database import engine; from app.models import Base; Base.metadata.create_all(bind=engine)"`  
を実行し、`tutorial/items.db` が作成されること。

---

### ステップ 3: `app/schemas.py`（DTO）

```python
from pydantic import BaseModel, ConfigDict


class ItemCreate(BaseModel):
    title: str
    description: str | None = None


class ItemUpdate(BaseModel):
    title: str | None = None
    description: str | None = None


class ItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
```

**確認方法:** `python -c "from app.schemas import ItemCreate; print(ItemCreate(title='a'))"` がエラーなく動くこと。

---

### ステップ 4: `app/crud.py`（DB 操作の集約）

```python
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import models, schemas


def create_item(db: Session, data: schemas.ItemCreate) -> models.Item:
    obj = models.Item(title=data.title, description=data.description)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


def list_items(db: Session, skip: int = 0, limit: int = 50):
    stmt = select(models.Item).offset(skip).limit(limit)
    return list(db.scalars(stmt))


def get_item(db: Session, item_id: int) -> models.Item | None:
    return db.get(models.Item, item_id)


def update_item(
    db: Session, item: models.Item, data: schemas.ItemUpdate
) -> models.Item:
    payload = data.model_dump(exclude_unset=True)
    for key, value in payload.items():
        setattr(item, key, value)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def delete_item(db: Session, item: models.Item) -> None:
    db.delete(item)
    db.commit()
```

**確認方法:** `python -m compileall app` がエラーなく終わること。

---

### ステップ 5: `app/main.py` と起動

```python
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from sqlalchemy.orm import Session

from app import crud, schemas
from app.database import engine, get_db
from app.models import Base


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Items CRUD", lifespan=lifespan)


@app.post("/items", response_model=schemas.ItemRead, status_code=status.HTTP_201_CREATED)
def create_item(payload: schemas.ItemCreate, db: Session = Depends(get_db)):
    return crud.create_item(db, payload)


@app.get("/items", response_model=list[schemas.ItemRead])
def read_items(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    return crud.list_items(db, skip=skip, limit=limit)


@app.get("/items/{item_id}", response_model=schemas.ItemRead)
def read_item(item_id: int, db: Session = Depends(get_db)):
    obj = crud.get_item(db, item_id)
    if obj is None:
        raise HTTPException(status_code=404, detail="not found")
    return obj


@app.patch("/items/{item_id}", response_model=schemas.ItemRead)
def patch_item(
    item_id: int, payload: schemas.ItemUpdate, db: Session = Depends(get_db)
):
    obj = crud.get_item(db, item_id)
    if obj is None:
        raise HTTPException(status_code=404, detail="not found")
    return crud.update_item(db, obj, payload)


@app.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int, db: Session = Depends(get_db)):
    obj = crud.get_item(db, item_id)
    if obj is None:
        raise HTTPException(status_code=404, detail="not found")
    crud.delete_item(db, obj)
```

**確認方法:**  
`uvicorn app.main:app --reload`  
ブラウザで `http://127.0.0.1:8000/docs` を開き、`POST /items` → `GET /items` が期待どおり動くこと。

---

### ステップ 6: テスト 1 本（pytest）

`mkdir tests` とし、`tests/__init__.py` は空でよい。

**`tests/test_items.py`** — `get_db` を **`dependency_overrides`** で差し替え、**インメモリ SQLite + `StaticPool`** で開発用 `items.db` とデータを分離する。

```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import get_db
from app.main import app
from app.models import Base


@pytest.fixture
def client():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as ac:
        yield ac
    app.dependency_overrides.clear()


def test_create_and_list(client):
    r = client.post("/items", json={"title": "hello", "description": "world"})
    assert r.status_code == 201
    body = r.json()
    assert body["title"] == "hello"
    rid = body["id"]

    r2 = client.get("/items")
    assert r2.status_code == 200
    rows = r2.json()
    assert any(row["id"] == rid for row in rows)
```

**確認方法:** `pytest -q` が `1 passed` になること。

---

### つまずきメモ（必要なときだけ読む）

| 症状 | 確認すること |
|------|----------------|
| `ModuleNotFoundError: No module named 'app'` | カレントが `tutorial/` か。親ディレクトリから実行していないか。 |
| Swagger は動くが pytest だけ失敗する | `dependency_overrides` がテスト終了後に `clear` されているか（上記コードどおりか）。 |
| SQLite がロックされる／変な状態 | 開発中はサーバを止めてから `items.db` を削除し、`create_all` で作り直す（データは消える）。 |
| `PATCH` でフィールドが更新されない | `ItemUpdate` は省略フィールドを送っていないか。未送信キーは `exclude_unset=True` で無視される。 |

---

**ここまでできれば今日のゴール達成**

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）: （余裕時）**

### Easy（5〜10分）

**課題:** `GET /items` にクエリ `q` を追加し、`title` に部分一致（大文字小文字無視）でフィルタする。

**回答コード例（抜粋・イメージ）:**

```python
# crud.py（ファイル先頭に次がある前提: from sqlalchemy.orm import Session）
from sqlalchemy import select

def list_items(db: Session, skip: int = 0, limit: int = 50, q: str | None = None):
    stmt = select(models.Item)
    if q:
        stmt = stmt.where(models.Item.title.ilike(f"%{q}%"))
    stmt = stmt.offset(skip).limit(limit)
    return list(db.scalars(stmt))

# main.py の read_items に q: str | None = None を追加し crud.list_items に渡す
```

---

### Medium

**課題:** `limit` の上限を `Query(le=100)` で強制し、レスポンスに総件数を載せない設計のまま「ページ番号 `page`」で取得できるようにする。

**回答コード例（イメージ）:**

```python
from fastapi import Depends, Query
from sqlalchemy.orm import Session

@app.get("/items", response_model=list[schemas.ItemRead])
def read_items(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
):
    skip = (page - 1) * limit
    return crud.list_items(db, skip=skip, limit=limit)
```

---

### Hard

**課題:** Alembic を導入し、`description` に `NOT NULL` 制約を付けるマイグレーションを書く（既存データがある場合の埋め方まで考える）。

**回答コード例（方針のみ・コマンドとスケルトン）:**

```bash
pip install alembic
cd tutorial && alembic init alembic
# alembic.ini の sqlalchemy.url と env.py で Base.metadata を読み込む
alembic revision --autogenerate -m "description not null"
# revision 内で既存 NULL を '' に UPDATE してから alter_column(not_null=True)
alembic upgrade head
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）: 4**

1. **社内 CMS の「記事下書き」API** — 編集者が管理画面からタイトル・本文を保存する。公開フィールドは `ItemRead` のように DTO で固定し、下書き用の内部カラム（レビュー状態など）は ORM にだけ持たせてクライアントに出さない構成にしやすい。
2. **EC の商品マスタ同期用の「カタログ投入」エンドポイント** — バッチや基幹から SKU・説明を POST する。入力検証を `ItemCreate` に閉じ、`crud` に更新ロジックを集約すると、あとから「同一 SKU は UPSERT」へ拡張するときの変更点が見える。
3. **機能フラグ／設定ストアの最小 CRUD** — 運用が SQLite で足りる規模ならファイル一つで検証環境を配れる。トラフィックが増えたら PostgreSQL とプーリングへ載せ替える、そのときもルートと `schemas` の契約はそのままにしやすい。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）: 2**

- FastAPI の `Depends` と `yield` で、リクエスト単位の DB セッション寿命をきれいに扱える。  
- ORM と HTTP の間に Pydantic の DTO を置くと、変更に強い API 境界になる。  
- テストでは `dependency_overrides` で DB を差し替え、開発用ファイルと検証データを分離するのが実務的である。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）: 2**

1. **Alembic とマイグレーション運用** — スキーマ変更をコードレビュー可能な形で残す。  
2. **認可・認証（API Key / OAuth2 の入口）** — `Depends` に認可を足して境界を硬くする。
