# Kotlin Coroutine + Structured Concurrency 1日分学習教材

## 1. 今日のゴール（目安: 2分）

Structured Concurrency の考え方を理解し、`CoroutineScope` と `coroutineScope {}` を使って、親子関係のあるコルーチン階層を正しく設計できるようになる。最後に、複数タスクを並列実行しつつキャンセルも伝播する「動くサンプル」を完成させる。

---

## 2. 事前知識チェック（目安: 5分）

### Q1. `launch` と `async` の違いは何か？それぞれどんな戻り値を持つか？

**回答:**  
- `launch`: 結果を返さない（`Job` を返す）。「火付けっぱなし」の非同期処理向け。  
- `async`: `Deferred<T>` を返し、`await()` で結果を取得できる。並列計算や値を返したい場合に使う。

### Q2. `GlobalScope.launch` の何が問題か？

**回答:**  
ライフサイクルに紐づかないため、アプリ終了後も動き続ける可能性がある。また、親スコープがないため、キャンセルや例外の伝播が構造化されず、リソースリークや予期しない動作の原因になる。

### Q3. `runBlocking` は本番コードでいつ使うべきか？

**回答:**  
`main()` やテストの最上位など、プログラムのエントリポイントで「コルーチンが終わるまでブロックしたい」ときのみ。通常のビジネスロジックや Android の Activity 内では使わない（UI スレッドをブロックするため）。

---

## 3. 理論（目安: 12分）※15分で切り上げ

### 3.1 Structured Concurrency とは

**ポイント:** コルーチンは必ずスコープに属し、親がキャンセルされれば子もキャンセルされる。子が例外で失敗すれば、兄弟もキャンセルされ、親に伝播する。これにより、リソースリークや「孤児タスク」を防ぐ。

**よくある誤解:** 「並列 = バラバラに動く」と思いがちだが、Structured Concurrency では「階層」と「責任の伝播」が重要。親が子の完了を待つ責任を持つ。

---

### 3.2 `CoroutineScope` と `coroutineScope {}` の違い

**ポイント:**
- `CoroutineScope`: インターフェース。`launch` や `async` を呼ぶための「場」を提供する。
- `coroutineScope {}`: サスペンド関数。新しいスコープを作り、そのブロック内の全コルーチンが完了するまで待つ。`runBlocking` と違い、スレッドをブロックしない。

**よくある誤解:** `coroutineScope` は「新しいスコープを作るだけ」と思いがちだが、実際には**ブロック内の全子コルーチンが完了するまで待つ**。これが Structured Concurrency の要。

---

### 3.3 キャンセルの伝播

**ポイント:** 親がキャンセルされると、その子・孫・兄弟も全てキャンセルされる。逆に、子が失敗すると、親は例外を受け取り、兄弟もキャンセルされる。`SupervisorJob` を使うと、兄弟の失敗を親に伝播させずに済む（子の失敗だけを吸収）。

**落とし穴:** `try-catch` で `launch` の外側を囲んでも、子の例外はキャンセルとして扱われるため、`catch` に届かないことがある。`CoroutineExceptionHandler` や `supervisorScope` を使う必要がある。

---

### 3.4 `Job` と `Deferred` の関係

**ポイント:** `Deferred` は `Job` の子インターフェースで、`await()` で結果を取得できる。`async` の戻り値。`Job` は `launch` の戻り値で、完了・キャンセルの状態管理のみ。

**落とし穴:** `async` で例外が発生した場合、`await()` を呼ぶまで例外は伝播しない。`await()` を呼ばないと例外が握りつぶされる可能性がある。

---

### 3.5 設計の選択肢: `coroutineScope` vs `supervisorScope`

**選択肢:**
- `coroutineScope`: 子の1つでも失敗したら、全体が失敗し、例外が伝播する。
- `supervisorScope`: 子の失敗はその子に留め、兄弟は継続。親は失敗しない。

**なぜこの選択にしたか（今回のハンズオン）:**  
複数タスクを並列実行しつつキャンセルも伝播させたいため、`coroutineScope` を採用。1つでも失敗したら全体を止める方が、デバッグしやすく、Structured Concurrency の「責任の伝播」を学びやすい。

---

### 3.6 `await()` の順序と例外伝播

**ポイント:** `a.await() + b.await()` のように順に待つと、`a` が失敗した時点で `b` はキャンセルされる。`awaitAll()` は全 `Deferred` を並列に待つが、1つでも失敗すれば他はキャンセルされ、最初の例外がスローされる。

**落とし穴:** `CancellationException` を `catch` して握りつぶすと、親へのキャンセル伝播が止まる。`catch (e: CancellationException) { throw e }` で再スローするか、`CancellationException` は catch しない。

---

## 4. ハンズオン（目安: 30分）※35分で切り上げ

### 環境

- **IDE:** IntelliJ IDEA 推奨（Kotlin/JVM プロジェクトが作りやすい）。Android Studio でも可。
- **プロジェクト:** `File > New > Project` → `Kotlin` → `Application` を選択。プロジェクト名: `CoroutineStructuredDemo`
- **依存:** モジュールの `build.gradle.kts`（`CoroutineStructuredDemo/build.gradle.kts`）に以下を追加:

```kotlin
dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
}
```

※ Android Studio で Android プロジェクトを作った場合、`app/build.gradle.kts` の `dependencies` に追加。

---

### ステップ1: プロジェクトの作成（目安: 5分）

1. IntelliJ IDEA: `File > New > Project` → `Kotlin` → `Application` → Next → プロジェクト名 `CoroutineStructuredDemo`
2. 作成後、`build.gradle.kts` を開き、上記の `kotlinx-coroutines-core` を追加
3. `Gradle` タブで「Reload All Gradle Projects」を実行

**確認方法:** プロジェクトがビルドできること。`./gradlew build` が成功する。

---

### ステップ2: `main` のベース作成（目安: 2分）

`src/main/kotlin/Main.kt` を作成（パッケージは `demo` とする）:

```kotlin
package demo

import kotlinx.coroutines.*

fun main() = runBlocking {
    println("Start: ${Thread.currentThread().name}")
    // ★ ステップ3〜5のコードはここに追記
    println("End: ${Thread.currentThread().name}")
}
```

**確認方法:** 実行すると `Start: main` と `End: main` が出力される。

---

### ステップ3: `coroutineScope` で子コルーチンを起動（目安: 3分）

`// ★` の部分を以下に**置き換え**:

```kotlin
    coroutineScope {
        launch {
            delay(500)
            println("Child 1: ${Thread.currentThread().name}")
        }
        launch {
            delay(300)
            println("Child 2: ${Thread.currentThread().name}")
        }
    }
    println("All children done")
```

**確認方法:** `Start` → `Child 2` または `Child 1` → `All children done` → `End`。`coroutineScope` が全子の完了を待っている。

---

### ステップ4: `async` で並列計算（目安: 4分）

ステップ3の `coroutineScope { ... }` ブロックを以下に**置き換え**:

```kotlin
    val result = coroutineScope {
        val a = async { delay(200); 10 }
        val b = async { delay(100); 20 }
        a.await() + b.await()
    }
    println("Result: $result")
```

**確認方法:** `Result: 30` が出力される。並列のため約200msで完了（直列なら300ms）。

---

### ステップ5: キャンセルの伝播を確認（目安: 4分）

ステップ4の `coroutineScope { ... }` を以下に**置き換え**（`try-catch` で囲む）:

```kotlin
    try {
        coroutineScope {
            launch {
                delay(100)
                throw RuntimeException("Child failed!")
            }
            launch {
                delay(500)
                println("This won't print")
            }
        }
    } catch (e: Exception) {
        println("Caught: ${e.message}")
    }
```

**確認方法:** `Start` → `Caught: Child failed!` → `End`。2つ目の `launch` はキャンセルされ、`This won't print` は表示されない。

---

### ステップ6: 最小成果物の完成（目安: 7分）

`Main.kt` を以下に**全体置き換え**:

```kotlin
package demo

import kotlinx.coroutines.*

fun main() = runBlocking {
    val urls = listOf("A", "B", "C")
    val results = fetchAll(urls)
    println("Results: $results")

    // ★ テスト: 期待通りの結果か確認
    check(results == listOf("data-A", "data-B", "data-C")) {
        "Expected [data-A, data-B, data-C], got $results"
    }
    println("Check passed!")
}

suspend fun fetchAll(urls: List<String>): List<String> = coroutineScope {
    urls.map { url ->
        async {
            delay(100)
            "data-$url"
        }
    }.awaitAll()
}
```

**確認方法:** `Results: [data-A, data-B, data-C]` と `Check passed!` が出力される。

---

### ステップ7: JUnit テスト（オプション・時間が余ったら）

**前提:** `build.gradle.kts` に以下を追加:

```kotlin
dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
}
test {
    useJUnitPlatform()
}
```

`src/test/kotlin/demo/FetchAllTest.kt` を作成:

```kotlin
package demo

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class FetchAllTest {
    @Test
    fun `fetchAll returns data for each url`() = runBlocking {
        val results = fetchAll(listOf("X", "Y"))
        assertEquals(listOf("data-X", "data-Y"), results)
    }
}
```

※ JUnit 5 ではテストメソッドは**インスタンスメソッド**（non-static）である必要がある。Kotlin のトップレベル関数は JVM 上で static になるため、クラス内に書く。

**確認方法:** `./gradlew test` でテストがグリーンになる。

**落とし穴:** `runBlocking` は同期的に待つため、`delay` が長いとテストが遅くなる。本番のテストでは `delay` を短くするか、`TestCoroutineDispatcher` を検討する。

---

## 5. 追加課題（時間が余ったら）

### Easy: `supervisorScope` で兄弟の失敗を吸収する

```kotlin
runBlocking {
    supervisorScope {
        launch { delay(100); throw RuntimeException("Fail") }
        launch { delay(200); println("OK") }
    }
    println("Done")
}
```

**期待:** `OK` と `Done` が出力され、例外は `supervisorScope` 内で処理される。

**回答例（例外を明示的に扱う場合）:**

```kotlin
import kotlinx.coroutines.*

fun main() = runBlocking {
    val handler = CoroutineExceptionHandler { _, e ->
        println("Caught: ${e.message}")
    }
    supervisorScope {
        launch(handler) {
            delay(100)
            throw RuntimeException("Fail")
        }
        launch {
            delay(200)
            println("OK")
        }
    }
    println("Done")
}
// 出力例: Caught: Fail → OK → Done（順序は前後する場合あり）
```

**回答の考え方:** `supervisorScope` は子の失敗を親に伝播させない。兄弟は継続し、`Done` まで到達する。`CoroutineExceptionHandler` を渡すと、失敗した子の例外を明示的に扱える。

---

### Medium: タイムアウト付き `fetchAll`

`withTimeout(250) { fetchAll(listOf("A","B","C")) }` のように、250ms でタイムアウトさせる。各 `async` の `delay` を 150ms にすると成功、300ms にすると `TimeoutCancellationException` になることを確認する。

**回答例:**

```kotlin
suspend fun fetchAllWithTimeout(urls: List<String>, timeoutMs: Long) = withTimeout(timeoutMs) {
    fetchAll(urls)
}
```

---

### Hard: 失敗したタスクだけ再試行する

`fetchAll` の一部が失敗したとき、失敗した URL だけ再試行し、成功したものとマージして返す。

**回答例:**

```kotlin
import kotlinx.coroutines.*

// 失敗をシミュレートする fetch（実務では API 呼び出しなど）
suspend fun fetchUrl(url: String, attempt: Int = 0): String {
    delay(100)
    if (url == "B" && attempt == 0) throw RuntimeException("Network error")  // デモ: B は1回目だけ失敗
    return "data-$url"
}

suspend fun fetchAllWithRetry(urls: List<String>, maxRetries: Int = 2): List<String> = coroutineScope {
    val resultMap = mutableMapOf<Int, String>()  // index -> 成功した結果
    var retryList = urls.mapIndexed { index, url -> Triple(index, url, 0) }  // index, url, attempt

    for (round in 0..maxRetries) {
        if (retryList.isEmpty()) break
        val failed = supervisorScope {
            retryList.map { (index, url, attempt) ->
                async {
                    try {
                        resultMap[index] = fetchUrl(url, attempt)
                        null
                    } catch (e: Exception) {
                        Triple(index, url, attempt + 1)  // 次回は attempt+1 で再試行
                    }
                }
            }.awaitAll().filterNotNull()
        }
        retryList = failed
    }

    // 元の順序でマージ。再試行後も失敗したものは例外
    urls.indices.map { resultMap[it] ?: throw IllegalStateException("Failed: ${urls[it]}") }
}

// 使用例
fun main() = runBlocking {
    val results = fetchAllWithRetry(listOf("A", "B", "C"))
    println(results)  // [data-A, data-B, data-C]（B は2回目で成功）
}
```

**ポイント:**
- `supervisorScope` で兄弟の失敗を互いに伝播させない
- 各 `async` 内で `try-catch` し、失敗時は `(index, url)` を返して再試行リストに追加
- `resultMap` で index ごとの結果を保持し、最後に元の順序でマージ

---

**`fetchAllWithRetry` の詳しい解説**

| 要素 | 役割 |
|------|------|
| `resultMap` | 成功した結果を **index ごと** に保持。最後に元の順序で並べ替えるため |
| `retryList` | 次に試す対象。`Triple(index, url, attempt)` で「何番目か」「どの URL か」「何回目の試行か」を管理 |
| `supervisorScope` | 1つの `async` が失敗しても、他の `async` はキャンセルされずに完了する。兄弟の失敗を吸収 |
| `try-catch` の戻り値 | 成功時は `null`（再試行不要）、失敗時は `Triple(index, url, attempt+1)`（次ラウンドで再試行） |
| `filterNotNull()` | 成功したもの（`null`）を除外し、失敗したものだけを `retryList` に渡す |
| `for (round in 0..maxRetries)` | 初回 + 最大 `maxRetries` 回の再試行。全成功で `retryList` が空になり `break` |
| 最終行の `map` | `urls.indices` で元の順序を保ち、`resultMap` から結果を取得。なければ例外 |

**実行の流れ（例: urls = ["A", "B", "C"]、B が1回目だけ失敗）:**

1. **round 0:** retryList = [(0,A,0), (1,B,0), (2,C,0)]
   - A, C は成功 → resultMap に格納、戻り値 `null`
   - B は失敗 → 戻り値 `Triple(1, B, 1)`
   - failed = [(1,B,1)] → retryList を更新

2. **round 1:** retryList = [(1,B,1)]
   - B は attempt=1 で成功 → resultMap に格納
   - failed = [] → retryList が空、次回 `break`

3. **最終:** resultMap = {0→"data-A", 1→"data-B", 2→"data-C"} を元の順序で返す

---

## 6. 実務での使いどころ

### 1. API 複数呼び出しの並列化

```kotlin
// ViewModel や Repository 内
suspend fun loadUserDashboard(userId: String): Dashboard = coroutineScope {
    val user = async { api.getUser(userId) }
    val settings = async { api.getSettings(userId) }
    val history = async { api.getHistory(userId) }
    Dashboard(
        user = user.await(),
        settings = settings.await(),
        history = history.await()
    )
}
```

1つでも失敗すれば例外が伝播し、他はキャンセルされる。トランザクション的なロールバックは DB 層で別途設計する。

---

### 2. Android の ViewModel / 画面ライフサイクル

```kotlin
class UserViewModel(private val repo: UserRepository) : ViewModel() {
    fun loadUser() {
        viewModelScope.launch {
            val user = repo.fetchUser()  // suspend
            _userState.value = user
        }
    }
}
```

画面が破棄されると `viewModelScope` がキャンセルされ、`fetchUser` もキャンセルされる。`GlobalScope` だと破棄後も動き続ける。

---

### 3. バッチ処理の並列実行

```kotlin
suspend fun processRecords(records: List<Record>) = coroutineScope {
    records.chunked(100).map { chunk ->
        async(Dispatchers.IO) {
            chunk.forEach { saveToDb(it) }
        }
    }.awaitAll()
}
```

親がキャンセルされれば全 `async` がキャンセルされ、リソースリークを防ぐ。`Dispatchers.IO` で I/O 負荷を分散。

---

## 7. まとめ

- Structured Concurrency では、コルーチンは必ずスコープに属し、親子でキャンセル・例外が伝播する。
- `coroutineScope {}` はスレッドをブロックせず、ブロック内の全子の完了を待つ。
- `async` + `awaitAll` で並列処理しつつ、`coroutineScope` で構造化するのが基本パターン。
- 本番では `GlobalScope` や `runBlocking` を避け、`viewModelScope` や `lifecycleScope` などライフサイクルに紐づいたスコープを使う。

---

## 8. 明日の布石

1. **Flow と Cold Stream**  
   `flow {}` と `collect` の関係、`channelFlow` との違い。リアクティブなデータストリームの基礎。

2. **CoroutineContext と Dispatcher**  
   `Dispatchers.IO` / `Main` / `Default` の使い分け、`withContext` によるディスパッチャ切り替え。
