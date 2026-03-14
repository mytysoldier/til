# Python dataclass 1日分学習教材

---

## 1. 今日のゴール（目安: 2分）

`@dataclass` を使って型安全で簡潔なデータクラスを定義し、`typing` と組み合わせた validation の考え方まで押さえる。**最小成果物**: `Order` / `OrderItem` の注文モデルと、正常系・異常系を含むテスト2つを完成させる。

---

## 2. 事前知識チェック（目安: 5分）

### Q1. 通常のクラスで `__init__` を手書きする場合、属性が増えると何が面倒になるか？

**回答**: 引数の並び順を間違えやすい、`__repr__` や `__eq__` を自分で実装する必要がある、型ヒントを書いても実行時には効かない、といった点が面倒になる。

### Q2. `typing.Optional[X]` と `X | None` の違いは？

**回答**: Python 3.10+ では意味は同じ。`Optional[X]` は `Union[X, None]` の糖衣構文。`X | None` は新記法で、より簡潔。古い Python では `from __future__ import annotations` が必要な場合がある。

### Q3. dataclass の `frozen=True` を付けると何が変わるか？

**回答**: インスタンス生成後に属性の代入ができなくなる（イミュータブルになる）。ハッシュ可能になり `dict` のキーや `set` の要素に使える。

---

## 3. 理論（目安: 12分）

### 3.1 dataclass の基本

`@dataclass` を付けると、`__init__`、`__repr__`、`__eq__` が自動生成される。属性はクラス本体に型アノテーション付きで宣言する。

**よくある誤解**: 「dataclass はただの辞書の代わり」と思いがちだが、メソッドも持てるし、継承もできる。データ保持専用ではない。

### 3.2 `field()` とデフォルト値の罠

デフォルト値を持つ属性と持たない属性を混在させる場合、**デフォルト値なしの属性を先に書く**必要がある。ミュータブルなデフォルト（`list`、`dict` など）は `field(default_factory=list)` のようにする。

**落とし穴**: `field(default=[])` と書くと、全インスタンスで同じリストを共有してしまう。

### 3.3 typing との組み合わせ

`List[str]`、`Dict[str, int]`、`Optional[str]` などで型を明示できる。Python 3.9+ では `list[str]`、`dict[str, int]` と小文字で書ける。型ヒントは IDE や mypy の支援に役立つが、**実行時には強制されない**。

**落とし穴（型）**: `User(name: str, age: int)` でも `User(123, "Alice")` のように型を無視して渡すと、そのまま代入される。実行時 validation は自分で入れる必要がある。

### 3.4 validation の考え方

標準の dataclass には validation 機能はない。実装方法の例:
- `__post_init__` でチェックして `ValueError` を投げる
- 外部ライブラリ（pydantic など）を使う

**設計の選択肢**: `__post_init__` で自前 validation を入れるか、pydantic に任せるか。今回は外部ライブラリを使わない方針なので、`__post_init__` で最小限の validation を入れる。

**落とし穴（エラー）**: `__post_init__` 内で `raise` した場合、`ValueError` の Traceback が表示される。どの属性で失敗したかメッセージに含めるとデバッグしやすい。

### 3.5 `frozen` と `slots`

`frozen=True` でイミュータブルにできる。`slots=True`（Python 3.10+）でメモリ効率を上げられる。`frozen` と `slots` は併用可能。

**落とし穴**: `slots=True` にすると `__dict__` がなくなり、動的な属性追加ができなくなる。

### 3.6 継承時の注意

親クラスにデフォルト値ありの属性がある場合、子クラスでもデフォルト値ありの属性は後ろに書く必要がある。親子で `field()` の使い方を揃えると混乱しにくい。

**落とし穴（状態）**: dataclass の属性が `list` や `dict` の場合、`frozen=True` でも**中身の変更**は防げない。`c.items.append(x)` は可能。完全なイミュータブルにしたい場合は中身も不変にする設計が必要。

```python
from dataclasses import dataclass, field

# 悪い例: frozen でも list の中身は変更できる
@dataclass(frozen=True)
class Bad:
    items: list[str] = field(default_factory=list)

b = Bad()
# b.items = []      # FrozenInstanceError（代入は防げる）
# b.items.append("x")  # これは通る！中身の変更は防げない

# 良い例: tuple を使うと中身も不変
@dataclass(frozen=True)
class Good:
    items: tuple[str, ...] = ()

g = Good(("a", "b"))
# g.items.append("c")  # AttributeError: 'tuple' object has no attribute 'append'
# g.items += ("c",)    # これも FrozenInstanceError（代入になる）
```

---

## 4. ハンズオン（目安: 28分）

### 前提条件

- **Python 3.9 以上**（`list[str]` 記法を使うため。3.8 以下の場合は `List[str]` と `from typing import List` に置き換える）
- 本教材のルートディレクトリで作業する

### 環境準備（目安: 3分）

```bash
# 1. 教材ディレクトリに移動
cd 日次記録/2026年/3月/9日

# 2. venv 作成と有効化
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
# プロンプト先頭に (venv) が出ればOK

# 3. tutorial フォルダを作成（なければ）
mkdir -p tutorial
```

### ステップ1: 最小の dataclass を作る（目安: 3分）

`tutorial/step01_basic.py` を**新規作成**し、以下を書く。

```python
from dataclasses import dataclass


@dataclass
class User:
    name: str
    age: int


u = User("Alice", 30)
print(u)
```

**確認方法**: `python tutorial/step01_basic.py` を実行し、`User(name='Alice', age=30)` と表示されること。

---

### ステップ2: デフォルト値と `field()` を使う（目安: 5分）

`tutorial/step02_field.py` を**新規作成**し、以下を書く。

```python
from dataclasses import dataclass, field


@dataclass
class Task:
    title: str
    done: bool = False
    tags: list[str] = field(default_factory=list)


t = Task("買い物")
print(t)
t.tags.append("urgent")
print(t.tags)
```

**確認方法**: `python tutorial/step02_field.py` を実行し、`Task(title='買い物', done=False, tags=[])` の後に `['urgent']` が表示されること。`default_factory=list` により、各インスタンスで別のリストが使われている。

---

### ステップ3: `__post_init__` で validation を入れる（目安: 5分）

`tutorial/step03_validation.py` を**新規作成**し、以下を書く。

```python
from dataclasses import dataclass


@dataclass
class Product:
    name: str
    price: float

    def __post_init__(self):
        if self.price < 0:
            raise ValueError("price must be >= 0")
        if not self.name.strip():
            raise ValueError("name must not be empty")


# 正常
p = Product("本", 1000.0)
print(p)

# 異常（コメントを外して試す）
# Product("", 100)
# Product("本", -100)
```

**確認方法**: `python tutorial/step03_validation.py` を実行し、`Product(name='本', price=1000.0)` と表示されること。コメントを外すと `ValueError` が発生することを確認する。

---

### ステップ4: frozen と typing を組み合わせる（目安: 5分）

`tutorial/step04_frozen.py` を**新規作成**し、以下を書く。

```python
from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class Config:
    host: str
    port: int
    timeout: Optional[float] = None


c = Config("localhost", 8080)
print(c)
print(hash(c))
# c.port = 9090  # FrozenInstanceError
```

**確認方法**: `python tutorial/step04_frozen.py` を実行し、`Config(host='localhost', port=8080, timeout=None)` とハッシュ値が表示されること。`c.port = 9090` のコメントを外すと `FrozenInstanceError` になることを確認する。

---

### ステップ5: 統合サンプルとテストを書く（目安: 10分）

`tutorial/step05_integration.py` を**新規作成**し、以下を書く。**これが今日の最小成果物**。

```python
from dataclasses import dataclass, field


@dataclass
class OrderItem:
    name: str
    price: float
    quantity: int = 1

    def __post_init__(self):
        if self.price < 0 or self.quantity < 1:
            raise ValueError("Invalid price or quantity")
        if not self.name or not self.name.strip():
            raise ValueError("name must not be empty")

    @property
    def total(self) -> float:
        return self.price * self.quantity


@dataclass
class Order:
    items: list[OrderItem] = field(default_factory=list)

    def add(self, item: OrderItem) -> None:
        self.items.append(item)

    @property
    def total(self) -> float:
        return sum(i.total for i in self.items)


def test_order_total():
    """正常系: 合計金額が正しく計算される"""
    o = Order()
    o.add(OrderItem("りんご", 100.0, 2))
    o.add(OrderItem("みかん", 50.0, 3))
    assert o.total == 350.0
    print("test_order_total: OK")


def test_order_item_validation():
    """異常系: 不正な値で ValueError が発生する"""
    for bad_args in [("", 100.0, 1), ("りんご", -100.0, 1)]:
        try:
            OrderItem(*bad_args)
            print("test_order_item_validation: FAIL (ValueError が出るべき)")
            return
        except ValueError:
            pass
    print("test_order_item_validation: OK")


if __name__ == "__main__":
    test_order_total()
    test_order_item_validation()
```

**確認方法**: `python tutorial/step05_integration.py` を実行し、`test_order_total: OK` と `test_order_item_validation: OK` が表示されること。

---

## 5. 追加課題（時間が余ったら）

### Easy: デフォルト値の順序エラーを体験する

```python
from dataclasses import dataclass

@dataclass
class Bad:
    x: int = 0
    y: str  # エラー: デフォルトなしの属性がデフォルトありの後に来ている
```

**回答**: 上記は `TypeError` になる。`y: str` を `x: int` より前に書くか、`y` にもデフォルトを付ける必要がある。

---

### Medium: `__post_init__` で型チェックを追加する

`OrderItem` に `name` が空でないことのチェックを追加し、テストで確認する。

**回答例**: ステップ5の `OrderItem` に既に含まれている。`if not self.name or not self.name.strip(): raise ValueError(...)` を追加すればよい。

---

### Hard: 継承した dataclass で親のデフォルトを上書きする

親に `status: str = "pending"` を持つ `Task` を定義し、子クラス `UrgentTask` で `status` のデフォルトを `"urgent"` に変える。

**回答例**:

```python
from dataclasses import dataclass

@dataclass
class Task:
    title: str
    status: str = "pending"

@dataclass
class UrgentTask(Task):
    status: str = "urgent"  # 親のデフォルトを上書き

t = UrgentTask("重要タスク")
print(t)  # UrgentTask(title='重要タスク', status='urgent')
```

---

## 6. 実務での使いどころ

### 1. API のリクエスト/レスポンスの型

外部 API の JSON をパースした結果を dataclass に詰めると、IDE の補完が効き、型チェッカーで不整合を検出できる。

```python
@dataclass
class UserResponse:
    id: int
    name: str
    email: str | None

# 実際は json.loads() の結果を手動でマッピング
data = {"id": 1, "name": "Alice", "email": "a@example.com"}
u = UserResponse(**data)
```

### 2. 設定オブジェクト

環境変数や YAML から読み込んだ設定を dataclass に格納。`frozen=True` で起動後の変更を防ぐ。

```python
@dataclass(frozen=True)
class AppConfig:
    db_host: str
    db_port: int
    debug: bool = False

config = AppConfig(
    db_host=os.environ["DB_HOST"],
    db_port=int(os.environ.get("DB_PORT", "5432")),
)
```

### 3. ドメインモデル（注文・在庫など）

注文、在庫、ユーザーなどのエンティティを dataclass で表現。`__post_init__` でビジネスルールを強制する。本教材の `Order` / `OrderItem` がその例。

---

## 7. まとめ

- dataclass は `__init__` / `__repr__` / `__eq__` を自動生成し、型アノテーションと相性が良い。
- ミュータブルなデフォルトは `field(default_factory=...)` を使う。`__post_init__` で validation を入れる。
- 型ヒントは実行時には効かないので、必要なチェックは `__post_init__` で明示する。

---

## 8. 明日の布石

1. **pydantic**: dataclass の validation を本格的にやりたい場合の次のステップ。JSON スキーマ連携やエラーメッセージが充実している。
2. **Protocol / 抽象基底クラス**: dataclass で「形」を定義した後、インターフェース（Protocol や ABC）で振る舞いを抽象化する設計に進む。

---

## 9. 追加ハンズオン: pydantic（目安: 15分）

dataclass の `__post_init__` と比較して、pydantic の validation を体験する。

### インストール

```bash
pip install pydantic
```

### ステップ1: 基本的なモデル（目安: 3分）

`tutorial/step06_pydantic.py` を**新規作成**し、以下を書く。

```python
from pydantic import BaseModel


class User(BaseModel):
    name: str
    age: int


u = User(name="Alice", age=30)
print(u)
print(u.model_dump())  # dict に変換
```

**確認方法**: `python tutorial/step06_pydantic.py` を実行し、`User` の表示と `{'name': 'Alice', 'age': 30}` が出力されること。

### ステップ2: 型の自動変換と validation（目安: 5分）

同じファイルに追記する。

```python
# 型の自動変換（str の "30" が int に変換される）
u2 = User(name="Bob", age="30")
print(u2.age, type(u2.age))  # 30 <class 'int'>

# validation 失敗（実行時に ValidationError）
try:
    User(name="", age=-1)
except Exception as e:
    print(type(e).__name__, e)
```

**確認方法**: `"30"` が int に変換されること、空の name や負の age で `ValidationError` が発生することを確認する。

### ステップ3: JSON からのパース（目安: 5分）

API レスポンスを想定した JSON をパースする。

```python
import json

class OrderItem(BaseModel):
    name: str
    price: float
    quantity: int = 1


json_str = '{"name": "りんご", "price": 100.0, "quantity": 2}'
data = json.loads(json_str)
item = OrderItem(**data)
print(item)
print(item.model_dump_json())
```

**確認方法**: JSON 文字列から `OrderItem` が生成され、`model_dump_json()` で JSON に戻せること。

### dataclass との違い（まとめ）

| 項目 | dataclass + __post_init__ | pydantic |
|------|---------------------------|----------|
| 型変換 | 自分で実装 | 自動（str→int など） |
| エラーメッセージ | 自分で書く | 詳細な ValidationError |
| JSON 連携 | 手動でマッピング | `model_validate()` で一発 |
| 依存 | 標準ライブラリのみ | 外部ライブラリ |
