# Java（Kotlin 比較）— class / interface / enum / 例外 1 日分

> 参考: [The Java Tutorials: Interfaces and Inheritance](https://docs.oracle.com/javase/tutorial/java/IandI/index.html)、[Kotlin 言語仕様: Classes and Inheritance](https://kotlinlang.org/docs/classes.html)、[Exceptions](https://kotlinlang.org/docs/exceptions.html)。新しい学習トレイルは [dev.java](https://dev.java/learn/) も参照。

---

## 1. 今日のゴール（目安時間: 1 分）

**小さなドメイン（支払いの成否）を、Java の class / interface / enum / 例外で動かし、Kotlin との 1 つの比較軸（チェック例外）で違いを言語化する。最後に「自己検証用の main 1 本」で緑（成功メッセージ）になることを確認する。**

---

## 2. 事前知識チェック（目安時間: 4 分）

**Q1. Java で「型の契約だけを定義し、実装を差し替えたい」とき、まず使う第一候補は `class` と `interface` のどちら？**

- **A.** 状態を持たない「振る舞いの約束」なら `interface` が第一候補。状態を一か所にまとめたいなら `class` や `abstract class` を検討（オラクル系チュートリアルも「型として使う」話から入る流れ）。[[Interfaces and Inheritance](https://docs.oracle.com/javase/tutorial/java/IandI/index.html)]

**Q2. `enum` は「定数の列挙」以外に、よく使う目的は？**

- **A.** 有限パターンの分岐を型で表し、`switch` や `==` を安全に書く（今日は「支払いの結果」など）。`enum` は単一の列挙型で継承できない点に注意（Java では `enum` は暗黙に `java.lang.Enum` 継承）。

**Q3. Kotlin 経験者が Java に来たとき、「例外」で最初につまずきやすい点は？**

- **A.** **Java は `Exception` 型の扱いで「チェック例外」が型システムに乗る**（メソッドに `throws` や `try` が必要）。Kotlin では**同階層の例外を設計上は unchecked 寄り**に扱いやすい、という**設計上の圧**の違いを感じやすい。[[Kotlin Exceptions](https://kotlinlang.org/docs/exceptions.html)]

---

## 3. 理論（目安時間: 12 分）

### 重要ポイント 1: `class` の役割 —「状態＋ふるまいの単位」

- **内容:** フィールド（状態）とメソッド（振る舞い）を束ね、インスタンスを作る。継承は**単一**（1 スーパークラス）。OOP の「部品の箱」。

- **よくある誤解/落とし穴:** 「全部 `public class` に便利メソッドを足していけばよい」となり、責務が膨らみやすい。今日は**意識的に小さなクラス**に分ける。

### 重要ポイント 2: `interface` —「呼び出し側が依存すべき形（契約）」

- **内容:** 実装の詳細ではなく、**メソッドのシグネチャ（必要なら `default` で共通処理）**を定義。クラスは `implements` で複数まとめられる。

- **よくある誤解/落とし穴:** データだけを運ぶ DTO まで `interface` にしようとする人がいるが、**値オブジェクトのプレーンな入れ物**は `record` や `class` の方が素直、という判断も多い（今日は `record` に深入りしない）。

### 重要ポイント 3: `enum` —「有限で閉じた型」

- **内容:** 取り得る値が決まっているとき、文字列定数より `enum` の方が**コンパイラの味方**を得やすい。

- **よくある誤解/落とし穴:** 大量の分岐の置き場所にして巨大化しやすい。分岐を増やすなら、**`interface` に寄せる**などの抜け道（追加課題の種）。

### 重要ポイント 4: 例外（今日の比較の軸はこれ 1 つ）— **チェック vs unchecked の「呼び出し元への要求」**

- **内容（比較の一軸）:** 同じ「失敗」でも、
  - **Java:** チェック例外（例: 継承 `Exception` で **checked**）は、**呼び出し元に `try` か `throws` を強いる**。API 設計が「回復可能な失敗」であることを**型に書く**スタイル。
  - **Kotlin:** 公式ドキュメント上も「checked exception は**ない**」と説明され、**呼び出し元に同じ圧力をかけない**設計が基本。[[Exceptions](https://kotlinlang.org/docs/exceptions.html)]

- **よくある誤解/落とし穴:** Java で「`RuntimeException` を濫用」して、結局**どれが回復可能か分からない**コードになる。逆に、**回復不能なバグ**までチェック例外にすると、`throws` が連鎖して疲弊する。ここは**チームの例外ポリシー**が要る、という水準に留まる（今日は 1 サンプルで体験まで）。

### 重要ポイント 5（実務で詰まりやすい）: **型・ラムダ・非同期の落とし穴（入口）**

- **型:** ジェネリクス（`List<PaymentProcessor>` など）と併用すると、**型境界と例外**の相性（サンプル化は追加課題）で議論が長くなりがち。今日のコードは**プリミティブ＋自前型**のままに留める意図がある。

- **ラムダとチェック例外:** `java.util.function` の標準型（`Supplier` / `BooleanSupplier` 等）は、**`get` がチェック例外を `throws` しない**ため、ラムダの本体で **checked 例外をそのまま投げられない**（コンパイルエラー）。**検証用の自前コード**では「メソッドを分けて `throws ProcessorException` を伝播させる」か「ラムダ内を `try-catch` で包む」かの二択になる。**ハンズオンは前者**（初心者にコンパイル可能な道を一つ示す）。

- **状態:** 現場では **`PaymentProcessor` を複数スレッドから共有**するとき、**可変なフィールド**があれば同期や不変性の設計が必要。今日の `DefaultPaymentProcessor` は**インスタンスフィールドを持たない**ので、その議論に入る前の最小例。

- **非同期（`CompletableFuture` 等）:** チェック例外を **コールバックの奥**に通そうとすると、**`throws` 宣言のない関数型**とのミスマッチで「ラップ用のラッパー地獄」になりやすい。Kotlin も「スレッド境界では例外の扱いに注意」が必要だが、**Java は checked がある分、そこに型の摩擦が乗る**、という**現場感**だけ覚えておけば十分（本日は同期呼び出しのみ）。

- **よくある誤解/落とし穴:** 単体テスト（JUnit 等）では `@Test void foo() throws Exception` のように**検査例外を上に逃がせる**が、`main` や**ライブラリのコールバック**では逃げ道が違う。今日は **`main` を `throws ProcessorException` にする**、という**実在する抜け道**を使う。

**設計の選択肢（今日の 1 つ）: `interface` + 実装クラスにした理由**

- **なぜ `abstract class` ではなく `interface` か:** 今回の「支払い処理」は**状態を積極的に持たない契約**を切り、テスト用の偽実装（スタブ）を差し替えやすくする。状態を 1 か所の基底で共有するなら `abstract class` も候補になる、という**比較表**の視点に留める。

### 補足: Kotlin との違い（同じ概念の一言対応）

| 概念 | Java | Kotlin（感覚） |
|------|------|------------------|
| 不変 | `final` フィールド + コンストラクタ | `val` + 主コンストラクタ等 |
| 契約 | `interface` / `default` | `interface` も可（実装方法は記法が異なる） |
| 列挙 | `enum` | `enum class`（記法違い） |
| 例外 | checked / unchecked がある | ドキュメント上 **checked なし**扱いが基本想定 [[Exceptions](https://kotlinlang.org/docs/exceptions.html)] |

---

## 4. ハンズオン（手順）（目安時間: 32 分）

**開発環境:** **Cursor**（エディタ）＋**統合ターミナル**で `javac` / `java` を使う。IntelliJ は不要。  
**最小成果物:** `tutorial` 配下にソースを置き、**`ComparisonDemo` の `main` を `java` コマンドで実行**し、コンソール最後行に `ALL CHECKS OK` が出る。  
**方針:** ファイルは**手順どおりに自分で**作成。パッケージ名は下記例どおり `com.example.javakotlin` に**統一**する（ディレクトリ階層＝パッケージ階層のルールを崩さない）。

> **倉庫向け:** ルートの `.gitignore` に `tutorial/` を入れ、演習用を Git 管理から外す（本フォルダでは例示済み）。

> **補足（任意）:** **Extension Pack for Java** など拡張を入れると補完・診断が付く。**なくても** `javac` / `java` だけで完走できる。

### ステップ 1: フォルダを作る（Cursor で開く作業用）

1. 作業用の場所に **`tutorial` フォルダ**を作成し、その中に **`src/com/example/javakotlin/`** を作る（ターミナルなら `mkdir -p src/com/example/javakotlin` を `tutorial` 内で実行）。  
2. **Cursor** で `tutorial` フォルダ（又はその親）を **Open Folder** して開く。  
3. ターミナルを開き、**JDK 17 以上**が入っているか確認する。

```bash
cd /path/to/tutorial
java -version
javac -version
```

**どちらかが見つからない**場合は、まず [Adoptium](https://adoptium.net/) 等で **JDK** を入れ、PATH を通す（例: macOS では `brew install temurin@17` 等。環境ごとに手順は異なる）。

**最終的な目安（ツリー）:**

```text
tutorial/
  src/
    com/
      example/
        javakotlin/             ← 以降の .java をここに置く
  out/                          ← 次ステップで `javac -d` が生成（無くてもよい。`javac` が作る）
```

**確認方法:** エクスプローラで階層が上記どおり。`.java` の先頭行 `package com.example.javakotlin;` と**フォルダの階層が一致**している。

**よく詰まる点:** パッケージとディレクトリがずれると **`ClassNotFoundException` / `NoClassDefFoundError`** や、「メインはあるのに起動できない」になる。後述の **コンパイル・実行**は、必ず **`tutorial` に `cd` してから**行う（カレントがズレると `class` パスが合わない）。

---

### ステップ 2: `enum` — 支払いの結果

Cursor のエクスプローラで `javakotlin` を右クリック → **New File** → `PaymentOutcome.java` を作成し、下記を貼り付ける（**Empty File** からでよい。「Class テンプレートがない」問題は出ない）。

`PaymentOutcome.java`:

```java
package com.example.javakotlin;

public enum PaymentOutcome {
    SUCCEEDED,
    DECLINED
}
```

**確認方法:** Cursor 上でファイルを保存し、文法に矛盾がなければよい。Java 拡張を入れていれば**赤い波線**でエラー表示される（未導入なら、次のステップまで待って `javac` のエラーを見るでも可）。

---

### ステップ 3: チェック例外（比較の焦点）

`ProcessorException.java`（`Exception` 継承 = **checked**）:

```java
package com.example.javakotlin;

public class ProcessorException extends Exception {
    public ProcessorException(String message) {
        super(message);
    }
}
```

**確認方法:** 仮の `void foo() { throw new ProcessorException("x"); }` を書き、`javac` すると**未処理の checked 例外**でコンパイルが止まる。`throws ProcessorException` か `try-catch` を付けて**エラーが消える**ことを確認（エディタ拡張を入れていれば、同じ旨がエディタ上でも出る）。これが Kotlin では**同じ圧**にならない、という**今日の一軸**。

---

### ステップ 4: `interface` + 実装 `class`

`PaymentProcessor.java`:

```java
package com.example.javakotlin;

public interface PaymentProcessor {
    PaymentOutcome process(int amount) throws ProcessorException;
}
```

`DefaultPaymentProcessor.java`:

```java
package com.example.javakotlin;

public class DefaultPaymentProcessor implements PaymentProcessor {
    @Override
    public PaymentOutcome process(int amount) throws ProcessorException {
        if (amount < 0) {
            throw new ProcessorException("amount must be non-negative: " + amount);
        }
        if (amount == 0) {
            return PaymentOutcome.DECLINED;
        }
        return PaymentOutcome.SUCCEEDED;
    }
}
```

**設計の一言:** **契約は `interface`、**振る舞いの差し替えは**別クラス**（テスト用に別実装を足しやすい）。

**確認方法（任意）:** 一時的に別ファイルかコメント内で、未キャッチの `new DefaultPaymentProcessor().process(-1);` があると**`javac` が未処理の `ProcessorException` を指摘**する。対処は次ステップ。

---

### ステップ 5: エントリポイント + **自己検証（疑似テスト）1 本**

**`runChecks` 内で `p.process(...)` を直接呼ぶ**（`throws ProcessorException` を上に付ける）。`BooleanSupplier` 等の**標準の関数型＋ラムダ**のまま `process` を呼ぶと、**checked 例外が扱えずコンパイルできない**（理論の「ラムダとチェック例外」）ので、**今日は採用しない。**

`ComparisonDemo.java`（**そのままコピーでコンパイル可能**）:

```java
package com.example.javakotlin;

public class ComparisonDemo {

    public static void main(String[] args) throws ProcessorException {
        runChecks();
    }

    /** 教材用の一括自己検証。本番の単体テスト（JUnit）の代替ではない。 */
    static void runChecks() throws ProcessorException {
        PaymentProcessor p = new DefaultPaymentProcessor();

        if (p.process(10) != PaymentOutcome.SUCCEEDED) {
            throw new IllegalStateException("FAIL: 10 -> SUCCEEDED");
        }
        if (p.process(0) != PaymentOutcome.DECLINED) {
            throw new IllegalStateException("FAIL: 0 -> DECLINED");
        }
        try {
            p.process(-1);
            throw new IllegalStateException("FAIL: expected ProcessorException for negative amount");
        } catch (ProcessorException e) {
            String m = e.getMessage();
            if (m == null || !m.contains("non-negative")) {
                throw new IllegalStateException("FAIL: exception message: " + m);
            }
        }
        System.out.println("ALL CHECKS OK — Java 比較サンプル");
    }
}
```

**コンパイルと実行（ターミナル）:** 5 つすべての `.java` を置いたら、`tutorial` をカレントにして**次をそのまま貼る**（パスは環境に合わせ替える。macOS / Linux 向け。Windows は PowerShell でパス区切り `\\` に読み替えてよい）。

```bash
cd /path/to/tutorial
mkdir -p out
javac -d out -sourcepath src \
  src/com/example/javakotlin/PaymentOutcome.java \
  src/com/example/javakotlin/ProcessorException.java \
  src/com/example/javakotlin/PaymentProcessor.java \
  src/com/example/javakotlin/DefaultPaymentProcessor.java \
  src/com/example/javakotlin/ComparisonDemo.java
java -cp out com.example.javakotlin.ComparisonDemo
```

`javac` でエラーが出たら、表示された**行番号**で該当ファイルを直す。成功時は**最後の行**に次が出る。

**確認方法（期待される挙動）:** 標準出力に **`ALL CHECKS OK — Java 比較サンプル`** が 1 行出る。意図的に `10` の期待を壊すと **`IllegalStateException: FAIL: 10...`** で落ちる（検証が効いている証拠）。

> **補足:** 再コンパイルは同じ `javac` 行を打ち直せばよい。Cursor から何度も実行するなら、**Run Task** や**シェルにエイリアス**を足す（任意）。

> **テストの位置づき:** 本務の単体テストは **JUnit + アサーション**、CI 実行が一般的。今回の `runChecks` は **ビルドツール未導入でも動く**教材用の**最小の「緑/赤」**。

---

### ステップ 6: Kotlin 側の**対応**をコメントに 1 行だけ足す（任意・5 分以内）

`ComparisonDemo` の `main` 直上などに、**自分の言葉で 1 行**でよい。例:

- `// Kotlin: 同様の自前 Exception は checked にしない前提が基本。呼び出し元への throws 連鎖は Java ほど厳格に書かれない。`

**確認方法:** 将来 `*.kt` で書くとき、**[Kotlin の例外](https://kotlinlang.org/docs/exceptions.html)** の説明と辻褄が合うか読み返す。

---

**ここまでできれば今日のゴール達成:** 動く比較サンプル、**interface / class / enum / checked 例外**の実感、**ラムダに隠れた checked 例外の罠**の入口、**Kotlin との違いを 1 軸**で言語化できる。

---

## 5. 追加課題（時間が余ったら）（目安時間: 0〜20 分・任意。本編外）

### Easy（目安: 5〜10 分）

- **`PaymentOutcome` に `isSuccess()`** を `enum` に追加し、`runChecks` の先頭 2 条件を `p.process(10).isSuccess()` のように読みやすくする。

**回答コード例（抜粋）:**

```java
// PaymentOutcome.java 内
public boolean isSuccess() {
    return this == SUCCEEDED;
}
```

```java
if (!p.process(10).isSuccess()) { throw new IllegalStateException("..."); }
```

---

### Medium

- **別 `implements` 例:** `FailingProcessor`（常に `ProcessorException`）を追加し、`interface` 型の変数に差し替えて `runChecks` から 1 回呼ぶ。呼び出し側の `try-catch` または `throws` の書き方の違いを確認。

**回答コード例（抜粋）:**

```java
public class FailingProcessor implements PaymentProcessor {
    @Override
    public PaymentOutcome process(int amount) throws ProcessorException {
        throw new ProcessorException("always fail");
    }
}
```

```java
try {
    new FailingProcessor().process(1);
} catch (ProcessorException e) {
    System.out.println("caught: " + e.getMessage());
}
```

---

### Hard

- **enum の分岐地獄回避の入口:** 支払い方法ごとに挙動が違う場合、**`enum` + 戦略（`IntFunction` や専用 `interface`）**で差し替え可能にする雛形を 1 つ。GoF の `Strategy` の**読み方の練習**（実務で全部揃えるのは中級以降）。

**回答コード例（Strategy の入口。コンパイル可能な最小形）:**

```java
import java.util.function.IntFunction;

public final class PaymentStrategies {
    private PaymentStrategies() {}

    /** 金額しきい値で SUCCEEDED/DECLINED を分ける例（ProcessorException は使わない単純版） */
    public static final IntFunction<PaymentOutcome> BY_POSITIVE = amount ->
        amount <= 0 ? PaymentOutcome.DECLINED : PaymentOutcome.SUCCEEDED;
}
```

`enum` に上記のようなハンドラを**フィールド**で持たせ、呼び出しで**差し替え**可能に拡張する、という**次の１歩**まで（本格的な Strategy + 例外は設計議論とセットで時間が伸びる）。

---

## 6. 実務での使いどころ（具体例 3 つ）（目安時間: 3 分）

1. **境界レイヤ（REST クライアント・JDBC ドライバ）で IOException / SQLException など**が `throws` され、**自前のサービス層のメソッド宣言か try-with-resources か**に落ち着かせる場面。Kotlin マイクロサービスと**同一 JVM 内**で部品を混ぜると、**「どこで握り潰し、どこでログに残すか」**の規約づくりが要る（checked の有無で**圧**が違う）。

2. **注文ステータス**を `enum` として**アプリと DB の制約**（CHECK 制約やマスタ表）の両方に持たせ、**許可されない遷移**（例: `CANCELLED` から `SHIPPED`）を**コンパイラ＋単体テスト**で弾く。新規の「保留中」などの追加時に **`switch` の網羅**（SE 12+ の `switch` 式や、エディタの網羅警告）を使うとレビューで拾いやすい。

3. **決済トークン化など、外部 I/O から隔離したい処理**に `interface PaymentProcessor` を据え、**本番は実装＋**テストは**偽実装**（`return SUCCEEDED` 固定や失敗直前まで）に差し替え。**例外経路**は**メソッドの `throws` とテスト内の `assertThrows`**（JUnit5）で揃える、が現場の定番。今日の `runChecks` は**その心臓部だけ**の抜粋。

---

## 7. まとめ（今日の学び 3 行）（目安時間: 2 分）

- `interface` / `class` / `enum` / 例外を**1 本の小さな流れ**にすると、OOP の「部品の切り方」が手に取りやすい。  
- **比較の一軸**として、**Java の checked 例外が呼び出し元に求める責任**を、**Kotlin の「checked がない」説明**と照らし合わせると腹落ちしやすい。**標準の関数型＋ラムダでは checked を素直に扱えない**、という**実装の罠**も合わせて覚えておく。  
- 完走最優先で深掘りは**追加課題**に逃すのが、**1 日 1 テーマ**の積み上げ方として健全。

---

## 8. 明日の布石（次のテーマ候補 2 つ）（目安時間: 2 分）

1. **Java `record` と不変 DTO、Kotlin `data class` との比較**（1 軸: 不変性と `equals`/`hashCode`）。  
2. **コレクションと `Optional`** — null 安全の文化差（`Optional` の誤用パターンの入口）と、Kotlin の nullable 型との対比。

---

**合計目安時間（本編）:** 1 + 4 + 12 + 32 + 3 + 2 + 2 = **56 分**（セクション 5 の追加課題は上記に含まない任意分。初回は **JDK 導入・PATH** や **Cursor でフォルダを開く**作業で +5 分余裕を見てもよい）。
