# Kotlin: API取得と state 反映（1日分教材）

**参照（公式）**

- [Guide to app architecture](https://developer.android.com/topic/architecture)（単方向データフロー・UI state）
- [UI State production](https://developer.android.com/topic/architecture/ui-layer/state-production)（非同期 → 観測可能な state）
- [StateFlow and SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)（`MutableStateFlow` / 収集）
- [Use Kotlin coroutines with lifecycle-aware components](https://developer.android.com/topic/libraries/architecture/coroutines)（`viewModelScope`）
- [Recommendations for Android architecture (Views)](https://developer.android.com/topic/architecture/views/recommendations-views)（ViewModel が `StateFlow` で UI state を公開）
- [Lifecycle-aware collection in Compose](https://developer.android.com/develop/ui/compose/lifecycle#collect-flows-lifecycle)（`collectAsStateWithLifecycle`）
- [Debug アプリ内で HTTPS をローカルで扱う](https://developer.android.com/privacy-and-security/security-ssl)（本教材は学習用に公開 HTTPS のみ。社内 HTTP は別途 `networkSecurityConfig` が必要なため本編では扱わない）

---

## 1. 今日のゴール（1〜2行）

**目安時間: 1分**

1日の終わりには、**HTTPS の API を非同期取得し、Loading / Success / Error を 1 つの UI state として `StateFlow` に載せ、画面に表示できる**ところまで到達する（画面回転後も `ViewModel` により**成功状態を維持**できる、まで確認すると実務感が出る）。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間: 4分**

1. **`suspend` 関数と、通常のコールバック非同期の違い**は何ですか？  
   **答え**: `suspend` はコルーチン内で**中断と再開**を表現し、スレッドを「占有し続けない」書き方に寄せやすい。コールバックは完了時に別の関数が呼ばれる形で、**処理の流れを追いにくい**ことが多い。

2. **「ViewModel に UI の Context を持たせない」理由**を一言で。  
   **答え**: 画面回転・プロセス再作成と**生存期間が違い**、メモリリークや不整合の元になるから（公式も非推奨）。

3. **`StateFlow` を UI から `collect` する際、`Lifecycle` を意識する理由**は？  
   **答え**: バックグラウンド中も**ずっと collect し続ける**と無駄な処理や不整合の原因になりうる。View 系では `repeatOnLifecycle`、**Jetpack Compose では `collectAsStateWithLifecycle`** 等で**表示中だけ**流すのが定石。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間: 9分**

**重要ポイント（今回 1 つに絞った比較観点: 「非同期の結果を、どこで“画面の状態”に閉じ込めるか」）**

1. **単一の「画面用 state」を暴露する**  
   今日は **sealed class** で `Loading` / `Success` / `Error` を**排他的**に表す。成功時だけデータがある、等が型で分かる。  
   - **誤解**: 「とりあえず `var loading` と `var error` を別々に持てば同じ」→ **同時に true になりうる**など整合が壊れやすい。

2. **非同期は `viewModelScope` + 適切な `Dispatcher`（ネットは IO）**  
   ネットワーク処理は UI をブロックしないよう **Repository 側の `Dispatchers.IO`** 等へ。`viewModelScope` の `launch` は**既定で Main**に戻るため、`MutableStateFlow` の**画面向け**更新は通常そのまま安全に届く。  
   - **落とし穴**: コルーチンが**キャンセル**されたときは `CancellationException` を**取り違えて `Error` 表示**しない（`runCatching` だけに頼ると**キャンセルが失敗扱い**になることがある。後述の実装はその前提で書く）。  
   - **落とし穴**: `viewModelScope` 外に**生のスレッド**を増やし続けない（キャンセル不能な長処理の温床）。

3. **UI 側は `StateFlow` を「ライフサイクル安全に」集める**  
   公式の注意どおり、**`collect` は勝手に止まらない**ので、View では `repeatOnLifecycle(Lifecycle.State.STARTED)` で**STARTED 以上のときだけ**集める。**Compose では `collectAsStateWithLifecycle`**（`lifecycle-runtime-compose`）が同種の役割。  
   - **誤解**: 「`StateFlow` なら常に最善の値が取れる」→ **裏方で無駄に動かし続けない**方が大切、という別問題。

4. **エラーハンドリング**  
   one-shot 取得は **`Result` + sealed `Error(message)`** が分かりやすい。UI には**短いメッセージ**、スタックは**ログ/クラッシュレポーター**向け。  
   - **落とし穴**: `JSONObject.getString` が**キー欠損**で投げる → **同じ `Error` に寄せる**と UI は単純だが、本番は**型（HTTP 4xx/5xx/パース失敗）**で分岐するほうが障害切り分けに効く。  
   - **落とし穴**（HTTP 実装）: エラー時に `getErrorStream()` が **null** の端末差がありうる。本教材の API（JSONPlaceholder）は **HTTPS 200** 前提。オフライン時は**接続系例外**で `Result.failure` になる想定。

5. **設計の選択肢（今回の理由）: sealed class で UI state**  
   - **他案**: 単一 `data class` に `isLoading: Boolean` と `error: String?` を両方持つ。  
   - **なぜ sealed にしたか**: 初中級向けの**状態の抜け漏れ**（Loading 中に前の成功データを表示する、等）に気づきやすい。  
   - **トレードオフ**: 部分更新（「ヘッダーだけ再読み込み」等）は sealed だと大きくなりがち → **発展**は追加課題へ。

6. **ネット層（今日は標準 `HttpURLConnection`）**  
   原則**追加ネット専用ライブラリを使わない**方針。実務の多くは **OkHttp / Retrofit** だが、**Dispatcher・例外・Result・UI state の分離**の練習には足りる。社内**平文 HTTP** だけ学ぶ場合は、**9 以降の `usesCleartextTraffic` や `networkSecurityConfig` が別途必須**（セキュリティ方針に従うこと）。

---

## 4. ハンズオン（手順）

**目安時間: 40分**（**初回**は Gradle 同期・エミュレータ起動で **+5〜10 分**かかることが多い。合計 60 分枠の「ゆとり」として扱う）

**作業場所の準備**  
Android Studio 起動前に、教材と同じ階層（この `26日` フォルダ）に、空の `tutorial` ディレクトリを作成する。  
**この日の学習用レポジトリでは、ルートの `.gitignore` に `tutorial/` を入れておき、ハンズオン成果物を誤コミットしない**（本教材と一緒に `26日/.gitignore` を置ける）。

以降、**プロジェクト名は `ApiStateMini`**、パッケージ例は `com.example.apistatemini` として手順を書く（**New Project 時の「Package name」**と **Kotlin ファイルの `package` 宣言**、**`namespace`（AGP 8+）**を**同じ**に揃える）。

### ステップ0: プロジェクト作成（4分）

1. **File → New → New Project** → **Empty Activity**（**Language: Kotlin**）。ウィザードで **Build configuration language** は **Kotlin DSL（`build.gradle.kts`）**推奨。  
2. **Use Jetpack Compose** を **ON**（画面は **XML レイアウトを使わず**、Kotlin の `@Composable` で組み立てる）。  
3. 名前: `ApiStateMini`、保存先: `…/日次記録/2026年/4月/26日/tutorial/ApiStateMini`。  
4. **Minimum SDK** は **API 24** 程度（この教材の想定。環境に合わせ可）。  
5. 同期完了まで待つ。

**補足**: `res/layout/` や `activity_main.xml` は**本ハンズオンでは不要**（テンプレートが残していても未使用でよい。削除してもよいが必須ではない）。

**確認方法**: ビルドが通り、エミュレータ／実機で **起動**できる。

---

### ステップ1: 必要な AndroidX 依存（6分）

**Gradle / AGP の整合**（最新 Android Studio 想定）: `gradle/wrapper/gradle-wrapper.properties` の **`distributionUrl` は Gradle 9.4.1**（**Android Gradle Plugin 9.2** の最低要件と一致）。テンプレートが古い Gradle のままなら、ここを **9.4.1** に揃えてから Sync する。

**依存の書き方**: 実務では **`gradle/libs.versions.toml`（Version Catalog）** にまとめるのが一般的だが、**本ハンズオンでは手順を短くするため**、下記どおり **`app/build.gradle.kts` の `dependencies { }` に `implementation(...)` を直接書く**（テンプレートが `libs.androidx...` 形式なら、そのブロックに**追加**すればよい）。

**Compose の有効化**（テンプレートで **Use Jetpack Compose** を選んでいれば**既に入っている**ことが多い。無い場合のみ追記）:

- **`android { }` 内**に `buildFeatures { compose = true }`
- **プラグイン**: Kotlin 2.0 以降は **`org.jetbrains.kotlin.plugin.compose`**（ルートまたは `:app` の `plugins { }`。Android Studio の Compose テンプレートが自動で付与）

`build.gradle.kts`（**モジュール `:app`**）の `dependencies` に例（**2026年4月時点の Jetpack 安定版**。Kotlin 2.2 系・AGP 9.2 / Gradle 9.4.1 で **Sync 成功**を確認。**「Failed to resolve」**なら [AndroidX release notes](https://developer.android.com/jetpack/androidx/releases) で近い版を探す）:

**Empty Compose Activity テンプレート**には **Compose BOM・`ui`・`material3`・`activity-compose`** などが既に入っている。**本教材で足りないことが多いのは ViewModel 連携用**（`lifecycle-viewmodel-ktx` と **`lifecycle-viewmodel-compose`**、**`lifecycle-runtime-compose`**）。下記は「テンプレートに無い行だけ足す」想定でもよい。

```kotlin
dependencies {
    val lifecycle = "2.10.0"
    val coroutines = "1.10.2"
    val activityCompose = "1.10.0"

    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:$lifecycle")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:$lifecycle")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:$lifecycle")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:$lifecycle")

    implementation("androidx.activity:activity-ktx:$activityCompose")
    implementation("androidx.activity:activity-compose:$activityCompose")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$coroutines")

    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
}
```

**BOM の日付**はテンプレートのものに**合わせてよい**（上記は例。テンプレートと二重に BOM を書かないよう、**既に `platform(...)` があるならそのブロックに `lifecycle-compose` 系だけ追加**）。

**アプリ**の `minSdk` が **24 未満**の場合、一部ライブラリが要求する **min より上**に上げる必要が出る → **minSdk 24 推奨**で揃える。

**確認方法**: **Sync** が成功し、**Build → Make Project** でエラーが出ない。

---

### ステップ2: パッケージと `sealed` / `Mapper`、Repository（10分）

Android Studio の **Project** ビューで `java/com/example/apistatemini` 上で右クリック → **New → Package** → `data`、同様に `ui` を作る（フォルダが無いと手順で迷いやすい）。

**新規** `com/example/apistatemini/ui/PostUiState.kt`（`data object` / `data class` は **Kotlin 1.9+**。古いと `object` にする）

```kotlin
package com.example.apistatemini.ui

sealed class PostUiState {
    data object Loading : PostUiState()
    data class Success(val title: String) : PostUiState()
    data class Error(val message: String) : PostUiState()
}
```

**新規** `com/example/apistatemini/ui/PostUiMappers.kt`（**ViewModel も同じマッパーを使い、成功/失敗の分岐を 1 か所**に集約する）

```kotlin
package com.example.apistatemini.ui

import kotlinx.coroutines.CancellationException

object PostUiMappers {
    fun fromFetchResult(result: Result<String>): PostUiState =
        result.fold(
            onSuccess = { PostUiState.Success(it) },
            onFailure = { e ->
                if (e is CancellationException) throw e
                PostUiState.Error(e.message ?: "unknown")
            }
        )
}
```

**新規** `com/example/apistatemini/data/JsonPlaceholderRepository.kt`  
（**`runCatching` だけ**だと `CancellationException` を **Failure に潰しやすい**ため、`try` / `catch` で **再 throw** する）

```kotlin
package com.example.apistatemini.data

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class JsonPlaceholderRepository {
    private val url = URL("https://jsonplaceholder.typicode.com/posts/1")

    suspend fun fetchPostTitle(): Result<String> = withContext(Dispatchers.IO) {
        try {
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 10_000
                readTimeout = 10_000
            }
            try {
                val code = conn.responseCode
                val stream = if (code in 200..299) conn.inputStream
                else conn.errorStream ?: conn.inputStream
                val body = stream.bufferedReader().use { it.readText() }
                if (code !in 200..299) error("HTTP $code: $body")
                val title = JSONObject(body).getString("title")
                Result.success(title)
            } finally {
                conn.disconnect()
            }
        } catch (c: CancellationException) {
            throw c
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
```

**確認方法**: まだ起動しなくてよい。**ビルド**が通ること。

---

### ステップ3: ViewModel — API → `StateFlow<PostUiState>`（5分）

**新規** `com/example/apistatemini/ui/PostViewModel.kt`

```kotlin
package com.example.apistatemini.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.apistatemini.data.JsonPlaceholderRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class PostViewModel(
    private val repository: JsonPlaceholderRepository = JsonPlaceholderRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow<PostUiState>(PostUiState.Loading)
    val uiState: StateFlow<PostUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = PostUiState.Loading
            val result = repository.fetchPostTitle()
            _uiState.value = PostUiMappers.fromFetchResult(result)
        }
    }
}
```

**設計メモ（一言）**: ブロッキング相当の処理（HTTP）は **Repository の IO** に寄せ、**UI state への写像**は `PostUiMappers` に寄せると、**同じ分岐**をテストで固定しやすい（実務では**マッパー／UseCase を JVM テスト**するのが現実的）。

**確認方法**: 次ステップで画面へ。

---

### ステップ4: MainActivity — Jetpack Compose で `StateFlow` を表示（8分）

**`res/layout/activity_main.xml` は使わない。** 画面は **`setContent { ... }` 内の `@Composable`** で組み立てる（テンプレートが生成した **Theme（例: `ApiStateMiniTheme`）** を外して **`MaterialTheme`** だけにしてもよい）。

#### 4-A. やることの整理

| 項目 | 内容 |
|------|------|
| **画面の宣言** | `@Composable fun PostScreen(viewModel: PostViewModel)` などにまとめると `MainActivity` が短くなる。 |
| **`StateFlow` の購読** | **`collectAsStateWithLifecycle()`**（`lifecycle-runtime-compose`）で、**ライフサイクルに合わせて**最新の `PostUiState` を State 化する。 |
| **1 行表示** | `Text` の **`maxLines = 1`** と **`overflow = TextOverflow.Ellipsis`**（長いタイトルは末尾 `…`）。 |
| **レイアウト** | `Box` + **`contentAlignment = Alignment.CenterStart`** などで、従来の `gravity="center_vertical"` に近い配置にできる。 |

#### 4-B. `MainActivity.kt` + `PostScreen` 例

テンプレートの `MainActivity` を**次の形に置き換える**（**パッケージ名は自分のプロジェクトに合わせる**。`enableEdgeToEdge()` はテンプレートにあればそのままでもよい）。

```kotlin
package com.example.apistatemini

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.apistatemini.ui.PostUiState
import com.example.apistatemini.ui.PostViewModel

class MainActivity : ComponentActivity() {

    private val viewModel: PostViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                PostScreen(viewModel = viewModel)
            }
        }
    }
}

@Composable
fun PostScreen(viewModel: PostViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val text = when (state) {
        is PostUiState.Loading -> "Loading..."
        is PostUiState.Success -> state.title
        is PostUiState.Error -> "Error: ${state.message}"
    }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyLarge,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
```

**確認**: 保存後 **Build → Make Project** でエラーが出ないこと。`collectAsStateWithLifecycle` が解決されない場合は **ステップ1** の **`lifecycle-runtime-compose`** を追加したうえで **Sync**。

`AndroidManifest.xml` の **`<manifest>` 直下**（多くのテンプレートは `<application>` の上）に **インターネット**権限（**`https://` には必須**）:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

**確認方法**（**エミュレータ or 実機**、**ネット接続あり**）:

- 起動直後: **"Loading..."**  
- 数秒以内: **JSON の `title` 文字列**  
- 飛行機モード等: **"Error: ..."**（文言は環境依存）  
- 任意: **画面回転**（設定で「**画面の自動回転**」ON）で、**同じ `title` が再表示**されれば `ViewModel` 保持の効果を確認できている。

**トラブル**: **常に Error** なら、**権限**・**オフライン**・**企業 VPN / プロキシ**を疑う。**自己署名 HTTPS** を叩く本番では別途**証明書**話題が入る（本 API は不要）。

**ここまでできれば今日のゴール達成。**

---

### ステップ5: ミニテスト 1 本（JVM、マッパー中心）（5分）

`app/src/test/java/com/example/apistatemini/ui/PostResultMappingTest.kt`（**パスは自分の `namespace` / package に揃える**）:

```kotlin
package com.example.apistatemini.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PostResultMappingTest {
    @Test
    fun success_maps_to_Success() {
        val s = PostUiMappers.fromFetchResult(Result.success("title"))
        assertTrue(s is PostUiState.Success)
        assertEquals("title", (s as PostUiState.Success).title)
    }

    @Test
    fun failure_maps_to_Error() {
        val s = PostUiMappers.fromFetchResult(Result.failure(RuntimeException("x")))
        assertTrue(s is PostUiState.Error)
        assertEquals("x", (s as PostUiState.Error).message)
    }
}
```

**上記の `PostUiMappers` は `fromFetchResult` 内で `CancellationException` を再 throw する**ため、**誤った `Error` 化**を防ぎやすい。JVM 上で**実際のキャンセル**までは再現しにくいが、**失敗系は `Result` で固定**しやすいのが実務的メリット。コルーチン層のテストを追加する場合は **`kotlinx-coroutines-test`**（本編外）で拡張。

**確認方法**: **Test** ディレクトリを右クリック → **Run 'Tests in …'** で**緑**（初回は **JDK / Gradle テスト実行**のダウンロードで時間がかかる場合あり）。

---

## 5. 追加課題（時間が余ったら）

**目安時間: 本編外（各難易度: Easy 5〜10分 / Medium・Hard は発展として別枠）**

**Easy（目安: 5〜10分）**  
「再読み込み」ボタンを置き、クリックで `viewModel.load()`。  

**回答例**（Compose の **`Button`** を `PostScreen` に追加。XML は不要）:

```kotlin
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

// PostScreen 内（例: Box の代わりに Column で縦並び）
Column(Modifier.fillMaxSize().padding(16.dp)) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyLarge,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
    Button(onClick = { viewModel.load() }) {
        Text("再読み込み")
    }
}
```

**Medium**  
本編ステップ2の **`HttpURLConnection` を使わない**形に差し替える。実務でもよく使う **OkHttp** を例にする（**依存を1つ追加**。**minSdk 24** のままでよい）。  

**`java.net.http.HttpClient` について**: Android では **API レベルやランタイム**の条件が絡むことがある。試す場合は [公式の扱い](https://developer.android.com/reference/java/net/http/HttpClient) やプロジェクトの **minSdk** を確認すること。本 Medium の**主例は OkHttp** に統一する。

**手順**

1. **`app/build.gradle.kts` の `dependencies { }` に追加**（版は [OkHttp releases](https://square.github.io/okhttp/changelog/) などで近い安定版を確認）:

```kotlin
implementation("com.squareup.okhttp3:okhttp:4.12.0")
```

2. **`JsonPlaceholderRepository.kt` を次の内容に置き換え**（**クラス名・`suspend fun fetchPostTitle(): Result<String>` は本編と同じ**なので、**`PostViewModel` は変更不要**）。

```kotlin
package com.example.apistatemini.data

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class JsonPlaceholderRepository {

    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    private val url = "https://jsonplaceholder.typicode.com/posts/1"

    suspend fun fetchPostTitle(): Result<String> = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder().url(url).get().build()
            client.newCall(request).execute().use { response ->
                val body = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    return@withContext Result.failure(
                        IllegalStateException("HTTP ${response.code}: $body")
                    )
                }
                val title = JSONObject(body).getString("title")
                Result.success(title)
            }
        } catch (c: CancellationException) {
            throw c
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
```

**補足**: `execute()` は**ブロッキング**呼び出しのため、**必ず `Dispatchers.IO` 上**で実行する（本編どおり `withContext(Dispatchers.IO)` でよい）。

**確認**: アプリの挙動は本編と同じ（Loading → タイトル表示）。**ビルド**で OkHttp が解決すること。

**（任意・発展）** `PostRepository` インターフェースを導入し、この OkHttp 実装を `: PostRepository` にすると、**`FakePostRepository`** で `ViewModel` を差し替えてテストしやすい。HTTP スタックの変更と契約の抽象化は**別の関心事**なので、Medium の達成目標はまず **「`HttpURLConnection` を捨てる」** と捉えてよい。

**Hard**  
`load()` の**同時多発**を抑える。`load()` に **`Job?` キャンセル** または **`Mutex` 直列化**。

**回答例**（`import kotlinx.coroutines.Job`）:

```kotlin
private var loadJob: Job? = null

fun load() {
    loadJob?.cancel()
    loadJob = viewModelScope.launch {
        _uiState.value = PostUiState.Loading
        val result = repository.fetchPostTitle()
        _uiState.value = PostUiMappers.fromFetchResult(result)
    }
}
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間: 3分**

1. **EC: 注文前の在庫・価格の再取得**（「確認画面を開いている数秒のあいだに価格が変わる」想定。`Loading` → `Success(確定価格)` / `Error` は **再試行 or 戻る**）  
2. **社内: 出退勤や申請の「サーバ確定ステータス」表示**（オフライン時は **Error または前回キャッシュ**のポリシーとセット。本教材は**キャッシュ無し**）  
3. **SaaS: 設定画面の「利用プラン名・機能フラグ」**（`load` / `refresh` を**同じ** `ViewModel` 経路に集約し、**二重 `Boolean` 分岐**を避ける）

---

## 7. まとめ（今日の学び3行）

**目安時間: 2分**

- API 取得の**非同期**は、**IO と UI state 更新**を層で分け、`viewModelScope` で**生命期間**に合わせる。  
- 画面向けは **Loading / Success / Error** を**型**で表し、Compose では **`collectAsStateWithLifecycle`** で**表示中だけ**状態を反映する（View 系では **`repeatOnLifecycle`**）。  
- **キャンセル**と**ビジネス失敗**を取り違えない（**`runCatching` 単体**に注意**）。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間: 1分**

1. **Repository + `Flow` + `stateIn(WhileSubscribed)`**（一覧の**継続更新**・購読の省電力）  
2. **Compose 発展**: エラー用 **Snackbar**、ローディング **CircularProgressIndicator / Placeholder**、`Navigation` との連携

---

*教材: Android / Kotlin 公式（App architecture, StateFlow, Coroutines with lifecycle, Compose での lifecycle-aware 収集）の推奨に沿っています。UI は **Jetpack Compose**（**画面用 XML レイアウトは使用しない**）。HTTP は学習用に `HttpURLConnection`（**追加のネット専用ライブラリなし**）としています。*
