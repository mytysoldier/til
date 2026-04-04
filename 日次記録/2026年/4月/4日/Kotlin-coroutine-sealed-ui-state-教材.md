# Kotlin: coroutine / sealed class / UI state（1日教材）

## 1. 今日のゴール（目安時間: 2分）

**Android Studio で `tutorial/` 配下に最小プロジェクトを置き、ViewModel + Coroutine + 単一の `UiState`（sealed class）で Loading / Success / Error を null なしで表現し、Compose で「状態→UI」が一本線で動くこと。ビルド・実行・JVM テスト 1 本まで通す。**

---

## 2. 事前知識チェック（目安時間: 5分）

以下に **質問と回答** を付けます。

1. **Coroutine の `suspend` は何のためにあるか？**  
   **答え:** 非同期処理を「ブロッキングせず」に書けるようにするため。スレッドを占有し続けず、`suspend` ポイントで中断・再開できる。コールバック地獄を減らし、エラーも `try/catch` で扱いやすくする。

2. **`viewModelScope` はいつキャンセルされるか？**  
   **答え:** 対応する `ViewModel` が `onCleared()` されるとき（画面を離れて ViewModel が破棄されるタイミング）。長時間ジョブはここに紐づけるとメモリリークを防ぎやすい。

3. **`sealed class` が enum と違って UI state に向く理由は？**  
   **答え:** 各状態に **異なるデータ型** を安全に載せられる（例: Success にだけ `data` を持つ）。`when` で **網羅性チェック** が効き、将来状態が増えてもコンパイラが追従を促す。

---

## 3. 理論（目安時間: 16分）

### 重要ポイント 1: UI は「状態の関数」である

- **要点:** 画面は `UiState` を読み、表示だけする。ボタン押下は「イベント」として ViewModel に渡し、結果はまた `UiState` に反映する。
- **よくある誤解/落とし穴:** Fragment でフラグと変数を増やすと、再入・回転・バックスタック復帰で不整合が起きる。単一の sealed ツリーに寄せる。**設定変更（回転）では Activity は作り直されても ViewModel は保持される**ので、「毎回初期化すべきデータ」と「保持したいデータ」を混同しない。

### 重要ポイント 2: `null` で「未ロード」を表さない

- **要点:** 「まだ何もない」は **`Loading`**、失敗は **`Error(message)`** のように **状態として明示**する。データが無い理由が型で分かる。
- **よくある誤解/落とし穴:** `data: T?` だけだと、`null` がロード中なのかエラーなのか区別できない。必要なら `Loading` / `Error` に分ける。

### 重要ポイント 3: Coroutine は「どのスコープで」「どのディスパッチャで」

- **要点:** UI 向けの状態更新は **`viewModelScope.launch { ... }` 内**で `_state.value` を書く（`viewModelScope` は Main）。重い処理は **`withContext(Dispatchers.IO)`** などに閉じ込め、**終わったら Main に戻ってから** State を更新する。
- **よくある誤解/落とし穴:** `GlobalScope.launch` は View 寿命と無関係に動き続け、リークやクラッシュの元。**`suspend` 内で投げられた未捕捉の例外は、Coroutine が完了扱いになりつつエラーが飲まれる**ことがあるため、Repository 呼び出しは **`try/catch` で `Error` 状態に落とす**のが実務では安全。

### 重要ポイント 4: sealed class + `when` は設計の安全弁

- **要点:** `when (state) { is Loading -> ... is Success -> ... is Error -> ... }` で **全分岐を強制**。新状態を追加したらコンパイルエラーで UI 修正箇所が見える。
- **よくある誤解/落とし穴:** `else` で逃げると網羅性が死ぬ。Compose の `when` は **式として全網羅**が効くように書く（必要なら `when { ... }` に `else` を付けず sealed で完結）。

### 重要ポイント 5: 表示とロジックの分離

- **要点:** ViewModel は **状態遷移とユースケース呼び出し**。Composable は **状態の描画とイベント送信のみ**。
- **よくある誤解/落とし穴:** Composable 内の `LaunchedEffect(Unit)` で毎回 `load()` すると、**プレビューや再合成のたびに意図せず再フェッチ**しやすい。初回だけなら `Unit` でよいが、**引数が変わったときだけ再実行**したい場合はキーを設計する。

### 重要ポイント 6: 非同期・エラー・型（実務で詰まりやすい所）

- **要点:** **メインスレッドでディスク／ネットのブロッキング呼び出しをしない**（ANR の原因）。Coroutine 内の例外は **`try/catch` で `UiState.Error` に写像**するか、上位で捕捉する方針を決める。
- **よくある誤解/落とし穴:** `StateFlow` は **ホット**で、購読者がいなくても最後の値を保持する。画面復帰時は「古い Success が残っている」ことがあるので、**再入場時に再ロードするか**はプロダクト要件で決める（Pull-to-refresh や `onResume` での再取得など）。

### 設計の選択肢と「なぜこの選択か」（1つ）

| 選択肢 | 内容 |
|--------|------|
| A | `data class` + 複数の Boolean（`isLoading`, `hasError`） |
| B | **単一の `sealed class UiState`** |

**この教材では B を採用。** Boolean の組み合わせ爆発（ロード中かつエラー表示など）を防ぎ、**同時に成立してはいけない状態を型で表現できない**ようにするため。チームでも「状態の追加＝型の追加」でレビューしやすい。

---

## 4. ハンズオン（手順）（目安時間: 28分）

**前提:** Android Studio で **新規プロジェクト → Phone and Tablet → Empty Activity**。**「Build configuration language」は Kotlin DSL（`build.gradle.kts`）を推奨**（手順とファイル名が教材と一致しやすい）。**UI は Jetpack Compose を有効**（テンプレートで「Use Jetpack Compose」にチェック）。プロジェクトの保存先を **`…/til/…/4日/tutorial/BookSample/`** のように **本日の `tutorial/` 直下** にする。

**最短ルート:** 迷ったら **Compose テンプレート一本**で進め、XML は後日でよい。

### ステップ 1: プロジェクト作成と依存関係の確認

- **手順:**  
  1. 上記テンプレートでプロジェクト作成し、**Gradle Sync** を実行する。  
  2. **app モジュール**の `build.gradle.kts` を開き、`dependencies { }` を確認する。テンプレートは **Version Catalog**（`gradle/libs.versions.toml`）を使うことが多い。その場合は **`libs.androidx.activity.compose`** のようなエイリアスで **`androidx.activity:activity-compose`** が入っている。  
  3. **直書きの例**（Version Catalog を使わない／追記するとき用）。`dependencies { }` に **少なくとも次が含まれる**こと。バージョン番号は **プロジェクト作成時点の安定版**に合わせてよい（古い場合は Android Studio の「Suggest upgrade」や [Maven の androidx.activity](https://mvnrepository.com/artifact/androidx.activity/activity-compose) を参照）。  

```kotlin
// app/build.gradle.kts の dependencies { } への追記例（Compose 用の一例）
dependencies {
    // Jetpack Compose のバージョンをまとめる BOM（テンプレートに既にあることが多い）
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")

    // ComponentActivity#setContent { } 用（これが無いと setContent が解決しない）
    implementation("androidx.activity:activity-compose:1.9.3")

    // ViewModel + Compose
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
}
```

- **Version Catalog を使う場合の対応:** `gradle/libs.versions.toml` に `activity-compose` / `compose-bom` / `lifecycle` のバージョンがあり、`build.gradle.kts` では次のように参照されることが多い。**意味は上の `implementation(...)` と同じ**。

```toml
# libs.versions.toml の例（キー名はプロジェクトによって異なる）
[versions]
activityCompose = "1.9.3"
composeBom = "2024.12.01"
lifecycle = "2.8.7"

[libraries]
androidx-activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
androidx-compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
androidx-lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }
androidx-lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }
androidx-lifecycle-viewmodel-ktx = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-ktx", version.ref = "lifecycle" }
```

```kotlin
// app/build.gradle.kts（Catalog 利用時のイメージ）
dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
}
```

- **確認方法:** Gradle Sync が成功し、緑の三角で **Run 'app'** が実行でき、エミュレータまたは実機で **デフォルトの “Hello” 画面**が表示される。

#### ステップ 1 のつまずき: `KotlinBuildScript` / `Unresolved reference: alias`

次の **2 つは別の問題**だが、同時に出ることが多い（Gradle が正しく解決できず、スクリプト全体が赤くなる）。

| 症状 | 意味 | 対処の方向 |
|------|------|------------|
| **Cannot access script base class `KotlinBuildScript`** | IDE が **`build.gradle.kts` を Gradle の Kotlin DSL として認識できていない**／Sync が失敗している | 下記 A |
| **`Unresolved reference: alias`** | `plugins { alias(libs.plugins.xxx) }` の **`alias` が解決できない**（多くは **Gradle が古い**、または **`libs` が無い**） | 下記 B |

**A. `KotlinBuildScript` まわり**

1. **File → Sync Project with Gradle Files** を実行する。  
2. **File → Invalidate Caches → Invalidate and Restart**（キャッシュ破損のとき有効）。  
3. **Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK** を **`Embedded JDK 17` または `JDK 17` 以上**にする（AGP 8.x は JDK 17 が前提）。  
4. プロジェクトを **ルートフォルダ**（`settings.gradle.kts` がある階層）で開いているか確認する。`app` だけ開いていると Gradle として認識されない。  
5. `gradle/wrapper/gradle-wrapper.properties` の **Gradle 本体**が **8.x** になっているか確認する（Android Studio のウィザードで作ったプロジェクトなら通常問題なし）。

**B. `alias` まわり**

- `alias(libs.plugins.android.application)` のような書き方は **Version Catalog の `libs` と Gradle 7.2+ のプラグイン解決**に依存する。  
- **Gradle が古い**（例: 6.x）と **`alias` がプラグインブロックで使えず** `Unresolved reference: alias` になる。**`gradle-wrapper.properties` で Gradle を 8.x に上げる**（Android Studio の「Gradle を更新」に従うのが安全）。  
- **`libs` が赤い**ときは `gradle/libs.versions.toml` が無い／名前が違う。**新規プロジェクトをウィザードで作り直す**のが早い。  
- **回避策（Catalog を使わない）:** ルートの `build.gradle.kts` の `plugins { }` を、次のように **従来の `id` + `version` に書き換える**（バージョンはプロジェクトに合わせる）。

```kotlin
plugins {
    id("com.android.application") version "8.7.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}
```

`app/build.gradle.kts` 側は:

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
```

**注意:** `alias` は **Gradle の Kotlin DSL が正しく動いているときだけ**使える。先に **A で Sync を成功**させないと、`alias` だけ直してもまた別の赤線が出ることがある。

### ステップ 2: `UiState` を sealed class で定義する

- **手順:** `app/src/main/java/<パッケージ>/ui/BookUiState.kt` を新規作成（パッケージ名は Android Studio が付けた `com.example.booksample` 等でよい。**以降の import は自分のパッケージに合わせる**）。

```kotlin
// ui/BookUiState.kt
package com.example.booksample.ui  // 実際のパッケージに合わせて変更

sealed class BookUiState {
    data object Loading : BookUiState()
    data class Success(val title: String) : BookUiState()
    data class Error(val message: String) : BookUiState()
}
```

- **確認方法:** **Build → Make Project** が通る。

### ステップ 3: ViewModel で `StateFlow` と coroutine を使う

- **手順:** 同じパッケージ階層に `BookViewModel.kt` を作成。`load()` 内で **擬似遅延のあと Success／Error** に遷移。**実務に近い形**として、擬似 API で例外が出た場合は `catch` で `Error` に落とす。

```kotlin
// BookViewModel.kt
package com.example.booksample  // 実際のパッケージに合わせる

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.booksample.ui.BookUiState
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class BookViewModel : ViewModel() {

    private val _state = MutableStateFlow<BookUiState>(BookUiState.Loading)
    val state: StateFlow<BookUiState> = _state.asStateFlow()

    fun load(shouldFail: Boolean = false) {
        viewModelScope.launch {
            _state.value = BookUiState.Loading
            try {
                delay(800)
                if (shouldFail) error("ネットワークエラー（デモ）")
                _state.value = BookUiState.Success("Kotlin in Action")
            } catch (e: Exception) {
                _state.value = BookUiState.Error(e.message ?: "不明なエラー")
            }
        }
    }
}
```

- **確認方法:** Make Project が通る。まだ UI を繋いでいなくてよい。

### ステップ 4: UI から ViewModel を取得し、状態で分岐表示する

- **手順:**  
  1. `MainActivity` を **`ComponentActivity` + `setContent { … }`** にし、テーマで `BookScreen` を表示する（テンプレートが既にそうなら、その中身だけ差し替える）。  
  2. `BookScreen.kt` を新規作成し、下記の **import をパッケージに合わせて** 修正する。  
  3. `load(shouldFail = false)` を **`LaunchedEffect(Unit)` で 1 回だけ**呼ぶ。

```kotlin
// MainActivity.kt（抜粋・パッケージとテーマ名はプロジェクトに合わせる）
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            BookSampleTheme {  // テンプレートが生成した Theme 名
                BookScreen()
            }
        }
    }
}
```

```kotlin
// BookScreen.kt
package com.example.booksample  // 実際のパッケージに合わせる

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.booksample.ui.BookUiState

@Composable
fun BookScreen(viewModel: BookViewModel = viewModel()) {
    val uiState by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) {
        viewModel.load(shouldFail = false)
    }

    when (val s = uiState) {
        BookUiState.Loading -> Text("読み込み中…")
        is BookUiState.Success -> Text("タイトル: ${s.title}")
        is BookUiState.Error -> Text("エラー: ${s.message}")
    }
}
```

- **確認方法:** Run で **先に「読み込み中」→ 約 0.8 秒後にタイトル**が出る。`load(shouldFail = true)` に変えて再 Run すると **エラー文**になる。  
- **つまずき:** `Unresolved reference: collectAsStateWithLifecycle` → ステップ 1 の **lifecycle-runtime-compose** を追加。`viewModel` が無い → **lifecycle-viewmodel-compose** を追加。

### ステップ 5: テスト 1 本（JVM）

- **手順:** `app/src/test/java/<パッケージ>/BookUiStateLogicTest.kt` を追加。**`when` が全分岐を網羅していること**と、Success のデータを **1 本のテスト**で検証する（実務では「状態の型ごとの表示文言マッピング」を関数に切り出してテストしやすくする）。

```kotlin
// src/test/.../BookUiStateLogicTest.kt
package com.example.booksample  // 実際のパッケージに合わせる

import com.example.booksample.ui.BookUiState
import org.junit.Assert.assertEquals
import org.junit.Test

class BookUiStateLogicTest {

    /** UI 用の表示文言を一箇所に集約する例（そのまま Composable から呼んでもよい） */
    fun messageFor(state: BookUiState): String = when (state) {
        BookUiState.Loading -> "読み込み中…"
        is BookUiState.Success -> "タイトル: ${state.title}"
        is BookUiState.Error -> "エラー: ${state.message}"
    }

    @Test
    fun mapsSuccessToTitleMessage() {
        val state = BookUiState.Success("Kotlin in Action")
        assertEquals("タイトル: Kotlin in Action", messageFor(state))
    }
}
```

- **確認方法:** `BookUiStateLogicTest` を右クリック → **Run**。緑なら OK。**ステップ 4 の文言と一致させる**と、仕様とテストがズレにくい。

---

## 5. 追加課題（時間が余ったら）（目安時間: 4分）

### Easy

- **内容:** 画面上に「再読み込み」ボタンを置き、タップで `Loading` に戻ることを目視確認する。
- **回答例:** `Button(onClick = { viewModel.load(shouldFail = false) }) { Text("再読み込み") }` を `BookScreen` に追加。

### Medium

- **内容:** `Success` に `lastUpdated: Long` を追加し、画面と `messageFor` のテストを更新する。
- **回答例:**

```kotlin
data class Success(val title: String, val lastUpdated: Long) : BookUiState()
// ViewModel: BookUiState.Success("Kotlin in Action", System.currentTimeMillis())
```

### Hard

- **内容:** `Error` に `cause: Throwable?` を足し、ユーザー向け文言とログを分ける（`Log.e` は `android.util.Log` を UI 層に書かず ViewModel で呼ぶのが無難）。
- **回答例:**

```kotlin
data class Error(val message: String, val cause: Throwable? = null) : BookUiState()
// ViewModel の catch で: BookUiState.Error("表示できませんでした", e)
```

---

## 6. 実務での使いどころ（具体例3つ）（目安時間: 2分）

1. **決済・注文確定画面:** `Submitting` のあいだはボタンを無効化し、成功で `Success(orderId)`、カードエラーは `Error(code)` で **再試行可能か** を分岐。KPI は **二重送信率** と **エラー後の完了率**。  
2. **ホームのおすすめ一覧:** 初回は `Loading`、取得後は `Success(items, fetchedAt)`。オフライン時はキャッシュを `Success` に載せ **`stale` フラグ**で上部に「接続を確認」バナー。レビュー指標は **空表示時間** と **リトライ後の成功率**。  
3. **設定画面の「アカウント削除」:** 確認ダイアログ後に `Deleting` → 成功でログアウト遷移。失敗は `Error` で **サポート問い合わせ導線**を出す。インシデント時は **Sentry 等の `cause` とユーザー向け message の分離**が効く。

---

## 7. まとめ（今日の学び3行）（目安時間: 2分）

- **単一の sealed `UiState` に寄せると、表示の分岐と「ありえない組み合わせ」を同時に減らせる。**  
- **`viewModelScope` と `StateFlow` で、ライフサイクルに紐づいた非同期と単方向の状態更新が書ける。例外は `Error` に写像する習慣を付ける。**  
- **表示文言を関数に切り出して JVM テストすると、Compose を動かさずに仕様を固定しやすい。**

---

## 8. 明日の布石（次のテーマ候補を2つ）（目安時間: 1分）

1. **Repository の `Result` / 例外を `UiState` にマッピングする規約**（どの層で `try/catch` するか、ログの責務）。  
2. **`MutableSharedFlow` の one-shot イベント（Snackbar / 画面遷移）と `UiState` の役割分担**（状態に載せないものの扱い）。

---

## 成果物チェックリスト

| 項目 | 確認 |
|------|------|
| `tutorial/` 配下に動くプロジェクト | □ |
| `BookUiState` が sealed で Loading/Success/Error | □ |
| ViewModel が coroutine で状態更新（try/catch で Error） | □ |
| Compose で `when` 分岐が動く | □ |
| JVM テスト 1 本（`messageFor` 等）が緑 | □ |

**合計目安時間: 2 + 5 + 16 + 28 + 4 + 2 + 2 + 1 = 60 分**（セクション5をスキップする場合は約 56 分。初回 Android Studio だけで詰まる場合は **ハンズオンに 5〜10 分のバッファ**を見て、理論の「重要ポイント 6」は翌日に回してもよい）
