# Python: FastAPI の入口（1日分）

## 1. 今日のゴール

**目安時間（分）**: 1

FastAPI で **POST 1本** の API を動かし、**リクエスト／レスポンスの形（DTO）** をコードで固定できる。自動ドキュメント（`/docs`）で入出力を確認し、**単体テストで成功とバリデーション失敗の両方** を自動検証できる。

---

## 2. 事前知識チェック（3問）

**目安時間（分）**: 5

### Q1. HTTP の GET と POST の使い分けを一言で言うと？

**回答例**: GET は **取得（副作用なしが原則）**、POST は **作成や送信など、サーバー側の状態を変えうる操作** に使うことが多い（厳密な規約ではないが実務の約束事として有効）。

### Q2. JSON の「オブジェクト」と「配列」を Python で表すとだいたい何に相当？

**回答例**: オブジェクトは **`dict`**、配列は **`list`**。

### Q3. 「API の契約」とは何を指すことが多い？

**回答例**: **パス・HTTP メソッド・入力形式・出力形式・エラー時の意味** など、クライアントとサーバーが共有する **インターフェースの約束**。

---

## 3. 理論（重要ポイント）

**目安時間（分）**: 11

### 3.1 FastAPI は「型」と Pydantic で入出力を宣言する

FastAPI はパス操作関数の引数や戻り値の型から、**バリデーション** と **OpenAPI（`/docs`）** を組み立てる。リクエストボディは公式にも **Pydantic の `BaseModel`** で宣言するのが基本。

- **よくある誤解/落とし穴**: 「とりあえず `dict` で受ければ速い」→ 検証や補完が効かず、**契約がコードに残らない**。最初からモデル化した方が後戻りが少ない。

### 3.2 DTO は「層の境界」のための箱（今日は API 境界だけ意識すればよい）

DTO（Data Transfer Object）は、**外部とのやり取り用のデータ形** を表すクラス/型の総称として使う。今日は **HTTP の入出力＝API 境界** に **`XxxCreate` / `XxxResponse` のように分ける** だけで十分。

- **よくある誤解/落とし穴**: 「DB のモデル＝API のモデルで一本化」→ 最初は楽だが、**公開フィールドと内部表現が固結び** し、後から分離が辛くなることが多い。

### 3.3 入力モデルと出力モデルを分けると、設計の比較がしやすい

**比較観点（今日はこれだけ）**: **「1 つの `Book` クラスで全部やる」vs「`BookCreate` と `BookResponse` に分ける」**  
本教材では後者を選ぶ。**理由**: 作成時だけ必須のフィールド（例: `title`）と、応答だけ出したいフィールド（例: `id`）がすぐ分岐するため、**境界がコード上で見える**。

- **よくある誤解/落とし穴**: 「小さい API なら分けるまでもない」→ 小さくても **分離の型癖** を付けると、チーム開発で事故が減る（過剰になったら後で寄せられる）。

### 3.4 `async def` は必須ではない（迷ったら同期でもよい）

公式にもある通り、パス操作関数は **`def` でも `async def` でもよい**。I/O 主体で非同期スタックに乗るなら `async`、今日の規模ではどちらでも可。

- **よくある誤解/落とし穴**: 「FastAPI だから全部 `async`」→ **`async def` の中で時間のかかる同期処理（重い計算・同期 I/O）をそのまま実行すると、イベントループを塞ぎやすい**。迷ったら今日は **`def` のまま** でよい。

### 3.5 `response_model` は「返してよい形」の宣言になる

`response_model=BookResponse` は、**レスポンス JSON の形をスキーマとして固定**する。戻り値に余分なキーが混ざっていても、**レスポンスモデルに無いフィールドは切り捨てられる**（設定により異なるが、今日は「公開しない内部値を誤って返さない」ための安全弁と捉える）。

- **よくある誤解/落とし穴**: 「関数が返す `dict` がそのまま全部出る」→ **モデルとズレると意図せずマスクされる**ので、**契約はモデル側を正**とする。

### 3.6 自動ドキュメントは「契約の共有物」として扱う

`/docs`（Swagger UI）は開発体験用だが、裏は **OpenAPI**。フロントや他チームとの **見える化された契約** になる。

- **よくある誤解/落とし穴**: 「ドキュメントは後回し」→ FastAPI は **コード＝ドキュメントの素** なので、**型を捨てるとドキュメントも壊れる**。

### 3.7 グローバルなインメモリ状態・HTTP ステータス・422（実務で踏みがち）

- **インメモリ（モジュールの `dict`）** は、**プロセス内だけ**有効。サーバー再起動や別ワーカー間では共有されない。本番では DB 等に置き換える。
- **作成系の POST** は慣習として **`201 Created`** を返すことが多い（常に `200` でも動くが、クライアントやゲートウェイの期待とズレやすい）。
- **リクエストボディのバリデーション失敗** は FastAPI/Pydantic ではだいたい **`422 Unprocessable Entity`**（「型や制約に合わない」）。**ビジネスルール上の「見つからない」** は **`404`** など別ステータスで表現する、と切り分ける。
- **テスト**でモジュールグローバルな `_BOOKS` を触る場合、**テスト間で状態が残ると順序依存の失敗**になる。`setUp` で **毎回クリア**する。

### 3.8 実行は `fastapi dev`（公式推奨）か `uvicorn` でよい

公式の First Steps では **`fastapi dev`** が紹介されている（開発時のリロード等）。環境によっては `uvicorn main:app --reload` でも同様。

- **よくある誤解/落とし穴**: カレントディレクトリが `tutorial/` 以外だと **`ModuleNotFoundError: No module named 'main'`**。**`main.py` があるディレクトリに `cd` してから** 起動する。CLI が見つからないときは **`python -m fastapi dev main.py`** を試す。

---

## 4. ハンズオン（手順）

**目安時間（分）**: 34

**前提**: Python **3.10 以上**（型表記 `str | None` を使うため）。`python3 --version` で確認する。

作業場所はすべて **`tutorial/` 配下** とする（リポジトリ直下に `tutorial` を作る想定）。  
（※手順は [FastAPI First Steps](https://fastapi.tiangolo.com/tutorial/first-steps/) および [Request Body](https://fastapi.tiangolo.com/tutorial/body/) に準拠。Pydantic v2 では `model_dump()` を使う。）

### ステップ 0: `tutorial` と venv の準備

1. リポジトリ直下（または学習用プロジェクトのルート）に `tutorial` フォルダを作成し、その中に移動する。
2. `python3 -m venv .venv` で仮想環境を作る。
3. 仮想環境を有効化する（macOS / zsh の例）。

```bash
mkdir -p tutorial
cd tutorial
python3 -m venv .venv
source .venv/bin/activate
```

**確認方法（期待される出力/挙動）**: プロンプトに `(.venv)` が付く、または `which python` が `.../tutorial/.venv/...` を指す。

---

### ステップ 1: 依存関係のインストール

```bash
pip install "fastapi[standard]"
```

**設計の選択肢と理由（最小）**: 標準ライブラリだけでは HTTP API フレームワークは作れないため、**本テーマの最小セットは `fastapi`（実行用 CLI 含む standard 推奨）のみ** とする。DB ドライバ等は今日は入れない。

**確認方法**: `python -c "import fastapi; print(fastapi.__version__)"` でバージョンが表示される。

---

### ステップ 2: `.gitignore` を作成（`tutorial/` を除外）

**※リポジトリのルート（`tutorial` の親）で行う。** 練習用ディレクトリを誤コミットしないため。

リポジトリルートの `.gitignore` に次の1行を追加する（既存ファイルがあれば追記）。

```
tutorial/
```

**補足（迷いどころ）**: `tutorial` を別の階層に置いた場合は、`日次記録/.../tutorial/` のように **実パスを書く**か、チームルールに合わせる。

**確認方法**: `git check-ignore -v tutorial/` がパターンを表示する（Git 管理下のリポジトリで実行）。すでに `tutorial/` をコミット済みなら、一度 `git rm -r --cached tutorial` が必要になることがある。

---

### ステップ 3: `main.py` に GET（ヘルス）を置く

`tutorial/main.py` を新規作成する。

```python
from fastapi import FastAPI

app = FastAPI(title="Book API (tutorial)")


@app.get("/health")
def health():
    return {"status": "ok"}
```

**確認方法**: この時点ではサーバ未起動なので **ファイルが保存されたこと** だけ確認すればよい。動作確認は **ステップ 5** でまとめて行う。

---

### ステップ 4: POST と DTO（`BookCreate` / `BookResponse`）を追加

`tutorial/main.py` を **次の全文に置き換える**（コピペでよい）。

```python
from uuid import uuid4

from fastapi import FastAPI, status
from pydantic import BaseModel, Field

app = FastAPI(title="Book API (tutorial)")


class BookCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    author: str | None = None


class BookResponse(BaseModel):
    id: str
    title: str
    author: str | None = None


# 教材用のインメモリ保存（本番では使わない・プロセス内のみ有効）
_BOOKS: dict[str, BookResponse] = {}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/books", response_model=BookResponse, status_code=status.HTTP_201_CREATED)
def create_book(payload: BookCreate) -> BookResponse:
    book_id = str(uuid4())
    book = BookResponse(id=book_id, title=payload.title, author=payload.author)
    _BOOKS[book_id] = book
    return book
```

**確認方法（静的）**: ファイル保存後、`python -c "import main; print(main.app.title)"` で `Book API (tutorial)` が出ればインポートは成功。

**起動方法**（API を試す前に、**`main.py` と同じディレクトリ `tutorial/`** で実行する。仮想環境が無効なら先に `source .venv/bin/activate`）:

```bash
fastapi dev main.py
```

**うまくいかないとき**: `python -m fastapi dev main.py`  
さらにダメなら: `uvicorn main:app --reload`

起動に成功すると、ターミナルに `http://127.0.0.1:8000` 前後の URL が表示される。**このターミナルは開いたまま**にし、次の `curl` は **別ターミナル**を開いて同じく `tutorial/` に移動してから実行する。

公式: [First Steps - FastAPI](https://fastapi.tiangolo.com/tutorial/first-steps/)

**確認方法（起動後に実施）**:

- 正しい JSON なら **`201`** と `id` 付き JSON。
- `title` が空文字なら **`422`**。

```bash
curl -s -i -X POST http://127.0.0.1:8000/books \
  -H 'content-type: application/json' \
  -d '{"title":"FastAPI入門","author":"you"}'
```

（`-i` でステータス行も見える。）

---

### ステップ 5: 開発サーバの起動と `/docs` 確認

**サーバが止まっていれば**、ステップ 4 と同じく `tutorial/` で次を実行する（起動済みならそのまま進んでよい）。

```bash
fastapi dev main.py
```

**うまくいかないとき**: `python -m fastapi dev main.py`  
さらにダメなら: `uvicorn main:app --reload`

公式: [First Steps - FastAPI](https://fastapi.tiangolo.com/tutorial/first-steps/)

**確認方法（すべて満たせば OK）**:

1. ターミナルに `http://127.0.0.1:8000` 前後の URL が表示される。
2. **別ターミナル**で `curl -s http://127.0.0.1:8000/health` → `{"status":"ok"}`。
3. `curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:8000/books -H 'content-type: application/json' -d '{"title":"x"}'` → `201`。
4. ブラウザで `http://127.0.0.1:8000/docs` を開き、`POST /books` が **201** になっていることを確認し **Try it out** できる。
5. `http://127.0.0.1:8000/openapi.json` が JSON で開ける。

---

### ステップ 6: テスト（`TestClient` + 標準 `unittest`）

**`unittest discover` は `tutorial/` をカレントにして実行する**（`from main import app` が通るため）。

`tutorial/test_main.py` を新規作成する。

```python
import unittest

import main
from fastapi.testclient import TestClient


class TestBooks(unittest.TestCase):
    def setUp(self) -> None:
        main._BOOKS.clear()
        self.client = TestClient(main.app)

    def test_create_book_returns_201_and_body_contract(self) -> None:
        res = self.client.post(
            "/books", json={"title": "テスト本", "author": "tester"}
        )
        self.assertEqual(res.status_code, 201)
        body = res.json()
        self.assertEqual(body["title"], "テスト本")
        self.assertIn("id", body)
        self.assertIsInstance(body["id"], str)

    def test_create_book_validation_error_is_422(self) -> None:
        res = self.client.post("/books", json={"title": ""})
        self.assertEqual(res.status_code, 422)


if __name__ == "__main__":
    unittest.main()
```

```bash
cd tutorial
source .venv/bin/activate
python -m unittest discover -q
```

**確認方法**: `Ran 2 tests` と **OK**（失敗 0）。

**補足（落とし穴）**: `TestClient` は **同期的にリクエストをシミュレート**する（裏で非同期を扱う仕組みだが、テストコード側は普通の `def` でよい）。**`setUp` で `_BOOKS` を空にしないと**、テストの実行順で結果が変わりうる。

---

### ゴール達成の合図

**ここまでできれば今日のゴール達成**: `POST /books` が **`201`** で動き、**入力は `BookCreate`、出力は `BookResponse`** で固定でき、`/docs` と **ユニットテスト 2 ケース**（成功・422）で確認できる。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）**: （本編外）Easy 5〜10 分 / Medium・Hard は任意

### Easy（5〜10 分）

**課題**: `GET /books/{book_id}` を追加し、存在しなければ **404** を返す。

**回答例**:

```python
from fastapi import HTTPException

# ... 既存の imports / _BOOKS はそのまま ...


@app.get("/books/{book_id}", response_model=BookResponse)
def get_book(book_id: str) -> BookResponse:
    book = _BOOKS.get(book_id)
    if book is None:
        raise HTTPException(status_code=404, detail="not found")
    return book
```

---

### Medium（発展）

**課題**: `BookListResponse`（`items: list[BookResponse]` と `total: int`）を返す `GET /books` を作り、**レスポンスモデルだけ** で配列形を固定する。

**回答例**:

```python
class BookListResponse(BaseModel):
    items: list[BookResponse]
    total: int


@app.get("/books", response_model=BookListResponse)
def list_books() -> BookListResponse:
    items = list(_BOOKS.values())
    return BookListResponse(items=items, total=len(items))
```

---

### Hard（発展）

**課題**: 「作成ロジック」を関数に切り出し、ルートは薄く保つ（**依存性注入は使わず**、純関数でよい。注入は別日のテーマに回す）。

**回答例**:

```python
def create_book_in_memory(payload: BookCreate) -> BookResponse:
    book_id = str(uuid4())
    return BookResponse(id=book_id, title=payload.title, author=payload.author)


@app.post("/books", response_model=BookResponse, status_code=status.HTTP_201_CREATED)
def create_book(payload: BookCreate) -> BookResponse:
    book = create_book_in_memory(payload)
    _BOOKS[book.id] = book
    return book
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）**: 6

1. **BFF / 画面向け API**: 例）ユーザーDTOから **`password_hash` や内部用の `legacy_id` を落とし**、`display_name` と `avatar_url` だけを `UserResponse` に載せる。フロントは OpenAPI 生成クライアントで **取りうるキーが型で固定**される。
2. **外部パートナー向け API**: 例）契約上必須の `invoice_tax_id` を `Field(min_length=10)` のように **入力スキーマで固定**し、変更は **OpenAPI の差分レビュー**に載せる（「口頭の仕様」と実装のズレを減らす）。
3. **マルチプロセス運用（Kubernetes 等）**: インメモリ `dict` は **Pod ごとに別物**になる。**セッションや在庫の「単一の真実」**は Redis/DB に寄せ、FastAPI は **DTO で I/O を検証して層に渡す**役に留める、という分担が典型。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）**: 2

- FastAPI は **型と Pydantic** で API 契約をコードに落とせる。  
- **入力DTOと出力DTOを分ける**と、公開境界が明確になり、**`response_model` で返却形も縛れる**。  
- **作成は 201・バリデーションは 422** のように HTTP を整理し、**テストではモジュール状態を毎回リセット**すると安全。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）**: 1

1. **FastAPI の依存性注入（`Depends`）**: DB セッションや認証をルートから切り離す。  
2. **ルータ分割と設定管理（`APIRouter` / 設定クラス）**: 成長したアプリの構造を整える。

---

## 参考リンク

- [First Steps - FastAPI](https://fastapi.tiangolo.com/tutorial/first-steps/)
- [Request Body - FastAPI](https://fastapi.tiangolo.com/tutorial/body/)
- [Pydantic BaseModel](https://docs.pydantic.dev/latest/concepts/models/)
