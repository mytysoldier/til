# Kotlin data class / sealed class 1日分学習教材

**テーマ**: data class / sealed class  
**想定時間**: 60分（±10分）  
**対象レベル**: 中級  
**開発環境**: Android Studio

| セクション | 目安時間 |
|------------|----------|
| 1. 今日のゴール | 1分 |
| 2. 事前知識チェック | 5分 |
| 3. 理論 | 10分 |
| 4. ハンズオン | 38分 |
| 5. 追加課題（余裕があれば） | 3分 |
| 6. 実務での使いどころ | 3分 |
| 7. まとめ・8. 明日の布石 | 4分 |

---

## 1. 今日のゴール（1〜2行）

Kotlinの`data class`でequals/hashCode/copyを自動生成し、`sealed class`で網羅的な分岐を型安全に扱えるようになる。両者の使い分けと落とし穴を理解する。

---

## 2. 事前知識チェック（3問）

### Q1. 次のコードの出力は？

```kotlin
data class User(val name: String, val age: Int)
val u1 = User("Alice", 30)
val u2 = User("Alice", 30)
println(u1 == u2)
```

**A1.** `true`  
data classは`equals`を自動生成するため、全プロパティが等しければ`true`になる。通常のclassでは`false`（参照比較）になる。

---

### Q2. data classの主コンストラクタに`var`を使うと何が起きる？

**A2.** `copy()`で生成されるオブジェクトは問題ないが、**元のオブジェクトがミュータブル**になる。`hashCode`は生成時にプロパティ値で決まるため、後からプロパティを変更すると、一度`Set`や`Map`のキーに入れたオブジェクトが「見つからない」などの不整合を起こす。data classは原則`val`で定義する。

---

### Q3. sealed classとenum classの違いは？

**A3.** enumは**1つのインスタンス**しか持たない（シングルトン）。sealed classのサブクラスは**複数のインスタンス**を持てる（例: `Success(data)`と`Success(otherData)`は別インスタンス）。状態を値として持つ「代数的データ型」的な表現にsealed classが向く。

---

## 3. 理論（重要ポイント3〜6個）

### 3.1 data classの自動生成メソッド

- `data`修飾子を付けると、`equals()`、`hashCode()`、`toString()`、`copy()`、`componentN()`が自動生成される。
- 比較対象は**主コンストラクタのプロパティのみ**。`body`内で定義したプロパティは含まれない。
- **よくある誤解**: 「全プロパティが自動で含まれる」と思いがちだが、主コンストラクタ外のプロパティは`equals`/`hashCode`に含まれない。意図しない比較結果になることがある。

---

### 3.2 data classの制約とvarの危険性

- 主コンストラクタに**1つ以上のプロパティ**が必要。
- data classは**継承できない**（openにできない）。ただし**interfaceの実装**は可能。
- **よくある落とし穴**: 継承して拡張したいモデルにはdata classは向かない。その場合は通常のclassか、sealed classのサブクラスとして設計する。
- **Set/Mapのキーに使う場合**: 主コンストラクタに`var`を使うと、後からプロパティを変更したときに`hashCode`が変わり、`Set`や`Map`のキーとして「見つからない」不整合が起きる。キーにするdata classは必ず`val`で定義する。

---

### 3.3 copy()の挙動

- `copy(name = "Bob")`のように、変更したいプロパティだけ指定し、他は元の値を引き継ぐ。
- イミュータブルな更新パターンで重宝する。
- **よくある落とし穴**: `copy()`は**シャローコピー**。ネストしたオブジェクトは参照がコピーされるだけなので、深い変更が必要なら自分で新しいオブジェクトを組み立てる必要がある。

---

### 3.4 sealed classの役割

- サブクラスが**コンパイル時に列挙可能**なクラス階層を表現する。
- `when`式で分岐するとき、全サブタイプを網羅していれば`else`が不要。漏れがあるとコンパイルエラーになる。
- **よくある誤解**: 「enumの上位互換」ではない。enumは定数集合、sealedは「型＋値」の表現。Result型（Success/Failure）やUI状態（Loading/Loaded/Error）のように、**値を持つ**分岐にsealed classが適する。

---

### 3.5 sealed classの継承ルール

- sealed classのサブクラスは、**同じファイル内**か、**ネストしたクラス**として定義する必要がある（Kotlin 1.5以降は同一モジュール内の別ファイルも可）。
- **よくある落とし穴**: 別パッケージの別ファイルにサブクラスを書くとコンパイルエラー。拡張性を制限することがsealed classの設計意図。

---

### 3.6 whenの網羅性とelseの罠

- `when`で全サブタイプを分岐すると、コンパイラが網羅性を保証する。**`else`を付けるとこのチェックが無効になる**。
- 実務では「将来のサブクラス追加時にコンパイルエラーで気づきたい」ため、`else`を安易に使わない。
- **よくある落とし穴**: 「とりあえずelseで潰す」と、新サブクラス追加時の漏れが実行時まで検出されない。sealed classの利点を捨てることになる。

---

### 3.7 設計の選択肢: data class vs sealed class

- **data class**: 1つの型で、プロパティの組み合わせが同じなら「同じ」とみなしたい値オブジェクト（User、Config、DTOなど）。
- **sealed class**: 有限個の「型の選択肢」があり、それぞれが固有のデータを持つ（Result、UIState、コマンドなど）。

**今回の選択**: ハンズオンでは、まずdata classで値オブジェクトを作り、次にsealed classでAPI結果（Success/Error）を表現する。実務では「APIレスポンスの型安全な分岐」でsealed classがよく使われる。

---

## 4. ハンズオン（手順）

**作業ディレクトリ**: 教材のルート（このREADMEがあるフォルダ）で、`tutorial` を作成し、`tutorial` 内で作業する。

**方針**: 単体のGradle（JVM）プロジェクトで進める。Android Studioで開いても、IntelliJ IDEAやVS Code + Kotlin拡張でも実行可能。

---

### ステップ1: プロジェクト準備（8分）

1. `tutorial` フォルダを作成し、その中に移動する。
2. 以下のファイルを**この順で**作成する。

**作成するファイル一覧**（ステップ5で `MainTest.kt` を追加）:
```
tutorial/
├── build.gradle.kts
├── settings.gradle.kts
└── src/
    └── main/kotlin/Main.kt
```

**build.gradle.kts**（`tutorial` 直下）:

```kotlin
plugins {
    kotlin("jvm") version "1.9.0"
    application
}

application {
    mainClass.set("MainKt")
}

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.9.0")
}

tasks.test {
    useJUnitPlatform()
}
```

**settings.gradle.kts**（`tutorial` 直下）:

```kotlin
rootProject.name = "tutorial"
```

**src/main/kotlin/Main.kt**（初期状態）:

```kotlin
fun main() {
}
```

3. 実行方法（いずれか）:
   - **Android Studio**: `tutorial` フォルダを「Open」で開く。Gradle 同期後、`Main.kt` の `main` を右クリック→「Run 'MainKt'」。
   - **コマンドライン**: `tutorial` 内で `gradle wrapper` を実行し、`./gradlew run` で起動。

**確認方法**: 何も出力されずに正常終了する（exit code 0）。

**得られる知見**: `application`プラグインで`mainClass`を指定すると`run`が動く。JUnit 5の依存と`useJUnitPlatform()`でテストが実行可能になる。

---

### ステップ2: 基本data classの定義（6分）

1. `Main.kt` を開き、`fun main()` の**上に** `User` data classを定義する。
2. `main` 内でインスタンスを作成し、`println` で表示する。

**Main.kt の内容**:

```kotlin
data class User(val name: String, val age: Int, val email: String)

fun main() {
    val u = User(name = "Alice", age = 30, email = "alice@example.com")
    println(u)
}
```

**確認方法**: `./gradlew run` で `User(name=Alice, age=30, email=alice@example.com)` が出力される。

**得られる知見**: data classは`toString()`を自動生成する。名前付き引数で可読性を保てる。

---

### ステップ3: equalsとcopyの確認（8分）

1. `Main.kt` の `main` 内を、以下の内容に差し替える。
2. 同じプロパティを持つ2つの`User`を比較し、`==`が`true`になることを確認する。
3. `copy(age = 31)`で新しいインスタンスを作り、元のオブジェクトが変わっていないことを確認する。

**Main.kt の main 部分**:

```kotlin
fun main() {
    val u1 = User("Alice", 30, "alice@example.com")
    val u2 = User("Alice", 30, "alice@example.com")
    println(u1 == u2)  // true

    val u3 = u1.copy(age = 31)
    println(u1.age)    // 30（変わっていない）
    println(u3.age)    // 31
}
```

**確認方法**: `./gradlew run` で `true`、`30`、`31`が順に出力される。

**得られる知見**: `equals`はプロパティベース。`copy`はイミュータブル更新の定石。

---

### ステップ4: sealed classの定義とwhen分岐（10分）

1. `Main.kt` に、`User` の下・`main` の上に `ApiResult` sealed class と `handleResult` 関数を追加する。
2. `main` 内に `handleResult` の呼び出しを追加する。
3. `when` に `else` を付けず、全サブタイプで分岐する。コンパイルが通ることを確認する。

**Main.kt の全体像**:

```kotlin
data class User(val name: String, val age: Int, val email: String)

sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val message: String) : ApiResult<Nothing>()
}

fun <T> handleResult(result: ApiResult<T>): String = when (result) {
    is ApiResult.Success -> "OK: ${result.data}"
    is ApiResult.Error -> "Error: ${result.message}"
}

fun main() {
    println(handleResult(ApiResult.Success("data")))
    println(handleResult(ApiResult.Error("network error")))
}
```

**確認方法**: `./gradlew run` で `OK: data` と `Error: network error` が出力される。`when` に `else` を付けずに全分岐を書けばコンパイルが通る。

**得られる知見**: sealed class + when で型安全な分岐。新サブクラスを追加すると、whenの漏れがコンパイルエラーで検出される。`<out T>` は共変（Success が T を持つ）、`Nothing` は Error がデータを持たない型として使う。

---

### ステップ5: テストの追加（6分）

1. `src/test/kotlin/MainTest.kt` を**新規作成**し、以下の内容を書く。
2. `Main.kt` と同じパッケージ（デフォルトパッケージ）に `User` と `handleResult` があるため、そのままインポートなしで参照できる。

**MainTest.kt の内容**:

```kotlin
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class MainTest {
    @Test
    fun `User equals returns true for same properties`() {
        val u1 = User("Alice", 30, "a@b.com")
        val u2 = User("Alice", 30, "a@b.com")
        assertEquals(u1, u2)
    }

    @Test
    fun `User copy creates new instance with updated property`() {
        val u1 = User("Alice", 30, "a@b.com")
        val u2 = u1.copy(age = 31)
        assertEquals(30, u1.age)
        assertEquals(31, u2.age)
    }

    @Test
    fun `handleResult returns OK for Success`() {
        val result = handleResult(ApiResult.Success("data"))
        assertTrue(result.startsWith("OK:"))
    }

    @Test
    fun `handleResult returns Error message for Error`() {
        val result = handleResult(ApiResult.Error("network error"))
        assertTrue(result.contains("network error"))
    }
}
```

**確認方法**: `tutorial` フォルダ内で `./gradlew test` を実行し、4件のテストが成功する。

**得られる知見**: data class の equals/copy と sealed class の when 分岐をテストで保証する。ステップ1で JUnit を入れてあるため、追加設定なしで動く。

---

## 5. 追加課題（時間が余ったら）

### Easy: data classにデフォルト値を追加

`User`の`email`にデフォルト値`""`を付け、`User("Bob", 25)`のように省略して生成できるようにする。

**回答例**:
```kotlin
data class User(val name: String, val age: Int, val email: String = "")
val u = User("Bob", 25)  // email は ""
```

---

### Medium: sealed classにLoadingを追加

`ApiResult`に`object Loading : ApiResult<Nothing>()`を追加し、`handleResult`のwhenに`Loading`分岐を足す。`object`は状態を持たないシングルトンとして使える。

**回答例**:
```kotlin
sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val message: String) : ApiResult<Nothing>()
    object Loading : ApiResult<Nothing>()
}

fun <T> handleResult(result: ApiResult<T>): String = when (result) {
    is ApiResult.Success -> "OK: ${result.data}"
    is ApiResult.Error -> "Error: ${result.message}"
    ApiResult.Loading -> "Loading..."
}
```

---

### Hard: data classのネストとcopyの限界

`data class Order(val id: Int, val user: User)`を定義し、`order.copy(user = order.user.copy(age = 31))`のようにネストした更新が必要なことを確認する。深い更新のパターンを理解する。

**回答例**:
```kotlin
data class User(val name: String, val age: Int)
data class Order(val id: Int, val user: User)

fun main() {
    val order = Order(1, User("Alice", 30))
    val updated = order.copy(user = order.user.copy(age = 31))
    println(updated.user.age)  // 31
}
```

---

## 6. 実務での使いどころ（具体例3つ）

1. **APIレスポンスの型安全な分岐**: Retrofitの`suspend`関数の戻り値を`sealed class ApiResponse<out T>`（Success/NetworkError/ParseError）にし、呼び出し側で`when`で網羅的にハンドリング。新エラー種別を追加したとき、whenの漏れがコンパイルエラーで即検出される。
2. **ViewModelのUI状態**: `sealed class UiState`（`Loading` / `Content(data)` / `Error(msg)`）をViewModelで保持し、Composeの`when (state)`で分岐。3状態を型で強制し、未ハンドリングを防ぐ。
3. **イベント/コマンドの表現**: ユーザー操作を`sealed class UserEvent`（`object Refresh`、`data class Search(val q: String)`）で表現し、各イベントに必要なパラメータを持たせる。whenで漏れなく処理でき、新イベント追加時にコンパイラが指摘する。

---

## 7. まとめ（今日の学び3行）

- data classはequals/hashCode/copyを自動生成し、値オブジェクトの実装を簡潔にする。主コンストラクタのプロパティのみが比較対象。
- sealed classは有限な型の選択肢を表現し、whenでの網羅的分岐をコンパイル時に保証する。
- 値の等価性が重要ならdata class、型の分岐が重要ならsealed class。組み合わせてResult型などを設計する。

---

## 8. 明日の布石（次のテーマ候補を2つ）

1. **objectとcompanion object**: シングルトン、ファクトリ、定数の整理。sealed classの`object`サブクラスとの関係。
2. **inline class / value class**: 型安全なラッパーと実行時オーバーヘッドの削減。Kotlin 1.5以降のvalue classの使いどころ。
