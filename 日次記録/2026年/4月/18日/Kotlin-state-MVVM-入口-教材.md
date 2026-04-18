# Kotlin: state管理と MVVM の入口（1日教材）

公式ドキュメントの参照先（最新の考え方の土台）:

- [ViewModel の概要](https://developer.android.com/topic/libraries/architecture/viewmodel)
- [UI 層: 状態とイベント](https://developer.android.com/topic/architecture/ui-layer)
- [Kotlin の StateFlow / MutableStateFlow](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.flow/-state-flow/)

---

## 1. 今日のゴール（1〜2行）（目安時間: 2分）

**Android Studio で `tutorial/` に Compose プロジェクトを置き、`UiState`（data class）と `ViewModel`（`StateFlow`）で「表示用の状態は1か所」「更新は ViewModel 経由」という MVVM の最小ループを動かし、ViewModel の単体テストを1本通す。**

---

## 2. 事前知識チェック（3問）※回答も付ける（目安時間: 5分）

以下に **質問と回答** を付けます。

1. **MVVM で「View」は具体的に何を指すことが多いか？（Android の例）**  
   **答え:** Activity / Fragment / Jetpack Compose の `@Composable` など、**ユーザーに見える画面を描画し、入力イベントを ViewModel に渡す層**。ビジネスルールの本体は持たないのが基本。

2. **`StateFlow` と `MutableStateFlow` の関係は？**  
   **答え:** `MutableStateFlow` は **書き換え可能な保持先**で、外部には **`StateFlow` として読み取り専用で公開**する（カプセル化）。UI は `StateFlow` を購読して再描画する。

3. **「単一責務」で ViewModel に頼みすぎると起きやすいことは？**  
   **答え:** ViewModel が **API・DB・画面遷移・Analytics まで抱える**と肥大化し、テストも再利用も難しくなる。入口段階では「画面の状態とユーザー操作の受け口」に寄せ、データ取得は Repository などに分けるのが無難。

---

## 3. 理論（重要ポイント3〜6個）（目安時間: 11分）

### 重要ポイント 1: UI state は「読み取り用のスナップショット」として定義する

- **要点:** 画面に必要な値を **`data class UiState(...)` に集約**し、Compose は `uiState` を読むだけにする。公式の UI 層の説明でも、**状態（state）とイベント（event）** に分ける考え方が中心。
- **よくある誤解/落とし穴:** Composable 内の `var count by remember { mutableIntStateOf(0) }` だけで完結させると速いが、**画面回転やプロセス再生成で設計の一貫性が崩れやすい**（学習用ミニアプリでは許容、実務では ViewModel 側に寄せることが多い）。**同じ値を `remember` と ViewModel の両方に持つ**と、どちらが正か分からなくなる。

### 重要ポイント 2: 更新の流れは「イベント → ViewModel → 新しい UiState」

- **要点:** ボタン押下などは **イベント**として `ViewModel` のメソッドへ。内部で `_uiState.update { it.copy(...) }` のように **不変データのコピーで次状態を作る**。これが state 更新の一本線。
- **よくある誤解/落とし穴:** UI から `MutableStateFlow` を直接触れる設計にすると、**どこで状態が変わるか追えなくなる**。`_uiState` は `private` にし、公開は `StateFlow` のみにする。

### 重要ポイント 3: ViewModel の責務は「画面の状態とユーザー意図の境界」

- **要点:** ViewModel は **UI のための状態ホルダ**と **ユーザー操作の受け口**（UseCase / Repository 呼び出しのオーケストレーション）に寄せる。**View は描画とイベント送信**に専念する。
- **よくある誤解/落とし穴:** 「ViewModel = 全部のロジック」ではない。**ドメインのルールは下位層**（Repository / UseCase）へ。ViewModel は **UI に載せる形への変換**が主戦場。

### 重要ポイント 4: MVVM は「ファイル名」ではなく依存の向き

- **要点:** **View → ViewModel →（Repository 等）Model** の依存で、**逆方向に View を参照しない**。これが MVVM の入口での押さえどころ。
- **よくある誤解/落とし穴:** `Activity` を ViewModel に渡して操作すると **メモリリークやテスト不能**になりやすい。Context が必要なら `AndroidViewModel` や Application 注入など別論（本日は深入りしない）。

### 重要ポイント 5: 比較観点（本日は1つだけ）— View に state を置かない理由

- **要点:** View に散らすと、**同じ値が複数箇所に重複**し、表示と実際のデータがズレやすい。**単一の `UiState`（単一情報源）**に寄せると、デバッグとレビューがしやすい。
- **よくある誤解/落とし穴:** 「小さい画面なら View で十分」は事実だが、**実務では要件が増えた瞬間に負債化**しやすい。今日は **最初から ViewModel + UiState** の形を体に染み込ませるのが目的。

### 重要ポイント 6: 非同期・エラー・型（実務で最初に詰まる所）

- **要点:** ネットワークや DB は **`viewModelScope.launch` など Coroutine 内**で実行し、**終わった結果だけ**を `UiState` に反映する。失敗時は **`UiState` にユーザー向けメッセージや `Result` 相当の情報**を載せる方針を決めておくと、表示がブレない。
- **よくある誤解/落とし穴:** Coroutine 内の例外を握りつぶすと **Loading のまま固まる**ことがある。`try/catch` で **エラー状態に写像**するか、Repository で `Result` に寄せる。**「数値が負になってはいけない」などの制約は ViewModel かドメインで保証**し、UI は表示だけにする（本ハンズオンでは `count` の下限をコードで保証する）。

### 設計の選択肢と「なぜこの選択にしたか」（1つ）

| 選択肢 | 内容 |
|--------|------|
| A | 画面ごとに `count` などを複数の `MutableState` / `LiveData` に分割 |
| B | **1つの `data class UiState` に集約し、`StateFlow` で公開** |

**この教材では B を採用。** [UI 層の状態](https://developer.android.com/topic/architecture/ui-layer) の考え方に沿い、**「今の画面の完全なスナップショット」**が一箇所で分かる。分割が必要になったら **画面を分ける / 状態をサブモジュール化**する方が追いやすい（入口ではシンプル優先）。

---

## 4. ハンズオン（手順）（目安時間: 30分）

**前提:** Android Studio で **新規プロジェクト → Phone and Tablet → Empty Activity**。**Jetpack Compose を有効**にする。プロジェクトの保存先は **`…/日次記録/2026年/4月/18日/tutorial/MvvmMini/`** のように、**本日のフォルダ直下の `tutorial/` 以下**とする（`tutorial` フォルダは手元で新規作成してよい）。

**この教材ではファイルの事前作成は不要**（ここに手順だけ書く）。**リポジトリには `tutorial/` を載せない**よう、同じ `18日` ディレクトリに置いた `.gitignore` で `tutorial/` を除外済み。

**名前のルール:** 以下の `com.example.mvvmmini` は **New Project の「Package name」に合わせて置き換える**（`MainActivity` の `package` と一致させる）。不一致だと import エラーになる。

### ステップ 1: `tutorial` フォルダを作り、プロジェクトを作成し、依存関係を確認する

- **手順:**  
  1. エクスプローラ / Finder で `18日` 直下に **`tutorial` フォルダを作成**する。  
  2. Android Studio で **New Project** し、保存場所を `…/18日/tutorial/MvvmMini` とする。  
  3. **Gradle Sync** が成功するまで待つ。  
  4. **app の `build.gradle.kts`** を開き、`dependencies { }` に **少なくとも次の意図**が含まれることを確認する（キーは Version Catalog のエイリアスでもよい）。  
     - **Compose BOM**（`platform("androidx.compose:compose-bom:…")`）  
     - **`androidx.lifecycle:lifecycle-viewmodel-ktx`**（ViewModel）  
     - **`androidx.lifecycle:lifecycle-viewmodel-compose`**（`viewModel()`）  
     - **`androidx.lifecycle:lifecycle-runtime-compose`**（`collectAsStateWithLifecycle`）  
     - **`androidx.activity:activity-compose`**（`setContent`）  
  5. 無い行だけ **Sync 後に追記**する（バージョンは [AndroidX のリリースノート](https://developer.android.com/jetpack/androidx/releases/lifecycle) または Studio の提案に合わせる）。

```kotlin
// app/build.gradle.kts の dependencies { } に「無いものだけ」足す例（バージョンは環境に合わせる）
dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
}
```

- **確認方法（期待される出力/挙動）:**  
  - **Gradle Sync** が成功する。  
  - エミュレータまたは実機で **デフォルトの「Hello」画面**が表示される。

### ステップ 2: `UiState` と `CounterViewModel` を追加する

- **手順:**  
  1. `app/src/main/java/<あなたのパッケージ>/` 配下に `ui` パッケージを作り、`CounterUiState.kt` を追加する。

```kotlin
// CounterUiState.kt
package com.example.mvvmmini.ui

data class CounterUiState(
    val count: Int = 0,
    val lastActionLabel: String = "まだ操作していません",
)
```

  2. 同じ `ui` パッケージに `CounterViewModel.kt` を作成する（**パッケージ宣言はプロジェクトに合わせる**）。

```kotlin
// CounterViewModel.kt
package com.example.mvvmmini.ui

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class CounterViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(CounterUiState())
    val uiState: StateFlow<CounterUiState> = _uiState.asStateFlow()

    fun onIncrement() {
        _uiState.update { current ->
            current.copy(
                count = current.count + 1,
                lastActionLabel = "＋1",
            )
        }
    }

    fun onDecrement() {
        _uiState.update { current ->
            current.copy(
                count = (current.count - 1).coerceAtLeast(0),
                lastActionLabel = "−1",
            )
        }
    }
}
```

- **確認方法（期待される出力/挙動）:**  
  - **Build → Make Project** が成功する。  
  - `uiState` が **`StateFlow`** として公開され、`_uiState` が **`private`** になっている。  
  - `count` が **0 未満にならない**（実務では「無効化」やバリデーションとセットにすることが多い）。

### ステップ 3: `MainActivity` と Compose をつなぎ、画面を表示する

- **手順:**  
  1. **テンプレートが生成した `Theme` の Composable**（例: `MvvmMiniTheme`）で `setContent` をラップする構成のまま、中身だけ差し替える。  
  2. `MainActivity.kt` を次の **形**に近づける（**パッケージ名・Theme 名は自分のプロジェクトに合わせる**）。`CounterScreen` は **`MainActivity.kt` にそのまま書いても、別ファイルに切り出してもよい**（切り出す場合は `package` と `import` を揃える）。

```kotlin
package com.example.mvvmmini

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.mvvmmini.ui.CounterViewModel
import com.example.mvvmmini.ui.theme.MvvmMiniTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MvvmMiniTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    CounterScreen()
                }
            }
        }
    }
}

@Composable
fun CounterScreen(viewModel: CounterViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Column(modifier = Modifier.padding(16.dp)) {
        Text(text = "count = ${uiState.count}")
        Text(text = uiState.lastActionLabel)
        Button(onClick = { viewModel.onIncrement() }) { Text("+1") }
        Button(onClick = { viewModel.onDecrement() }) { Text("-1") }
    }
}
```

  3. **`collectAsStateWithLifecycle` が未解決**なら、`lifecycle-runtime-compose` をステップ 1 の依存に追加して **再 Sync** する。  
  4. どうしても依存追加で詰まる場合の **学習用フォールバック:** `collectAsStateWithLifecycle()` の代わりに **`collectAsState()`**（`import androidx.compose.runtime.collectAsState`）でも動く。本番ではライフサイクルに合わせた購読を優先。

- **確認方法（期待される出力/挙動）:**  
  - アプリ起動で **count = 0** とラベルが表示される。  
  - **+1 / −1** で数字とラベルが更新される。  
  - **−1 を繰り返しても count は 0 未満にならない。**

### ステップ 4: 「state 更新の流れ」を口頭またはメモで言語化する

- **手順:**  
  1. ボタン押下 → `onIncrement` / `onDecrement` → `_uiState.update` → **新 `CounterUiState`** → `StateFlow` が通知 → Compose が再描画、の順を紙やコメントに書く。  
  2. **Composable 内で `count` を直接増やさない**ことを確認する。

- **確認方法（期待される出力/挙動）:**  
  - 自分の言葉で **1分以内**に説明できる（教材の理解度チェック用）。

### ステップ 5: ViewModel の単体テストを1本追加する

- **手順:**  
  1. `app/build.gradle.kts` の `dependencies` に **JUnit** があることを確認する（無ければ追記）。

```kotlin
testImplementation("junit:junit:4.13.2")
```

  2. `src/test/java/<パッケージと同じ階層>/CounterViewModelTest.kt` を作成する。`CounterViewModel` と **同じパッケージにしなくてよい**が、`import com.example.mvvmmini.ui.CounterViewModel` は必要。

```kotlin
import com.example.mvvmmini.ui.CounterViewModel
import org.junit.Assert.assertEquals
import org.junit.Test

class CounterViewModelTest {

    @Test
    fun `onIncrement は count と lastActionLabel を更新する`() {
        val vm = CounterViewModel()
        assertEquals(0, vm.uiState.value.count)
        vm.onIncrement()
        assertEquals(1, vm.uiState.value.count)
        assertEquals("＋1", vm.uiState.value.lastActionLabel)
    }
}
```

  3. テスト実行で **`Default AndroidJUnitRunner` を選ばず**、**JUnit（ローカル JVM）** として実行する（テストファイル左の緑矢印）。  
  4. **`ViewModel` が解決しない**場合は、`implementation` の `lifecycle-viewmodel-ktx` が **app モジュールに入っているか**、**Gradle Sync** 済みかを確認する。

- **確認方法（期待される出力/挙動）:**  
  - Android Studio で **該当テストを Run** し **緑（成功）** になる。

**ここまでできれば今日のゴール達成。**

---

## 5. 追加課題（時間が余ったら）（目安時間: 5分）

### Easy（5〜10分）

**課題:** `UiState` に `val canDecrement: Boolean` を追加し、`count <= 0` のとき **−1 ボタンを無効化**する（状態は ViewModel 側で決める）。

**回答コード例:**

```kotlin
data class CounterUiState(
    val count: Int = 0,
    val lastActionLabel: String = "まだ操作していません",
) {
    val canDecrement: Boolean get() = count > 0
}

fun onDecrement() {
    _uiState.update { current ->
        if (!current.canDecrement) return@update current
        current.copy(count = current.count - 1, lastActionLabel = "−1")
    }
}
```

```kotlin
Button(
    onClick = { viewModel.onDecrement() },
    enabled = uiState.canDecrement,
) { Text("-1") }
```

### Medium

**課題:** `CounterViewModel` で **Repository インターフェース**を1つ定義し、`onIncrement` が **Repository 経由で「上限10」** を超えないようにする（Repository は `FakeCounterRepository` でメモリ実装）。

**回答コード例:**

```kotlin
interface CounterRepository {
    fun clamp(value: Int): Int
}

class FakeCounterRepository : CounterRepository {
    override fun clamp(value: Int): Int = value.coerceAtMost(10)
}

class CounterViewModel(
    private val repository: CounterRepository = FakeCounterRepository(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(CounterUiState())
    val uiState: StateFlow<CounterUiState> = _uiState.asStateFlow()

    fun onIncrement() {
        _uiState.update { current ->
            val next = repository.clamp(current.count + 1)
            current.copy(count = next, lastActionLabel = "＋1（上限10）")
        }
    }
}
```

### Hard

**課題:** `UiState` を **`sealed interface`** に分割し、`Loading` / `Ready(...)` の2状態にし、**初期表示を Loading→Ready に遷移**させる（`viewModelScope.launch` + `delay` で疑似ロード）。入口の次段のため、エラー状態は省略可。**`Loading` のときはボタンを出さない／押せない**ようにし、`onIncrement` / `onDecrement` は **`Ready` のときだけ**状態を更新する。

**回答コード例（`CounterUiState.kt`）:**

```kotlin
package com.example.mvvmmini.ui

sealed interface CounterUiState {
    data object Loading : CounterUiState

    data class Ready(
        val count: Int,
        val lastActionLabel: String = "まだ操作していません",
    ) : CounterUiState {
        val canDecrement: Boolean get() = count > 0
    }
}
```

**回答コード例（`CounterViewModel.kt` — `init`・`onIncrement`・`onDecrement` すべて）:**

```kotlin
package com.example.mvvmmini.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class CounterViewModel : ViewModel() {

    private val _uiState = MutableStateFlow<CounterUiState>(CounterUiState.Loading)
    val uiState: StateFlow<CounterUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            delay(300)
            _uiState.value = CounterUiState.Ready(
                count = 0,
                lastActionLabel = "準備完了",
            )
        }
    }

    fun onIncrement() {
        _uiState.update { state ->
            when (state) {
                CounterUiState.Loading -> state
                is CounterUiState.Ready -> state.copy(
                    count = state.count + 1,
                    lastActionLabel = "＋1",
                )
            }
        }
    }

    fun onDecrement() {
        _uiState.update { state ->
            when (state) {
                CounterUiState.Loading -> state
                is CounterUiState.Ready -> {
                    if (!state.canDecrement) return@update state
                    state.copy(
                        count = (state.count - 1).coerceAtLeast(0),
                        lastActionLabel = "−1",
                    )
                }
            }
        }
    }
}
```

**回答コード例（`CounterScreen` — 状態で分岐。**教材の `when` は式として網羅的に）:** 

```kotlin
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun CounterScreen(viewModel: CounterViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    // `by` 委譲プロパティは smart cast しにくいので、`when (val s = …)` で束ねると安全
    when (val s = uiState) {
        CounterUiState.Loading -> {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                CircularProgressIndicator()
                Text("読み込み中…")
            }
        }

        is CounterUiState.Ready -> {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(text = "count = ${s.count}")
                Text(text = s.lastActionLabel)
                Button(onClick = { viewModel.onIncrement() }) { Text("+1") }
                Button(
                    onClick = { viewModel.onDecrement() },
                    enabled = s.canDecrement,
                ) { Text("-1") }
            }
        }
    }
}
```

---

## 6. 実務での使いどころ（具体例3つ）（目安時間: 3分）

1. **ログイン・会員登録フォーム:** メール・パスワード・「送信中」・**フィールドごとのエラー文言**を `UiState` に載せ、ボタンは `enabled = !uiState.isSubmitting && uiState.isFormValid` のように **状態からだけ決める**（二重送信や表示ズレを防ぐ）。  
2. **検索・一覧画面:** `Loading` / `Empty` / `Error(message)` / `Content(items)` のように **同時に成立してはいけない表示**を型または状態で分け、Pull-to-refresh や再入場時の再取得方針とセットで設計する（ViewModel は Repository の結果を **画面向けに整形**する）。  
3. **オフライン・権限エラー:** 「ユーザーに見せる一文」と「再試行可能か」を `UiState` に持たせ、Composable は **メッセージ表示と再試行ボタン**に専念する（例外の握りつぶしを防ぐ）。

---

## 7. まとめ（今日の学び3行）（目安時間: 2分）

- **画面に散らさず、`data class` で UiState を1か所にまとめ、`MutableStateFlow` は ViewModel 内に閉じた。**  
- **イベントは ViewModel のメソッドへ、更新は `update { copy(...) }` で次のスナップショットを作った。**  
- **MVVM の入口は「依存の向き」と「ViewModel の責務の線引き」、比較は「単一情報源に寄せるか」で十分押さえられた。**

---

## 8. 明日の布石（次のテーマ候補を2つ）（目安時間: 2分）

1. **Navigation Compose と ViewModel のスコープ**（画面単位の `ViewModelStoreOwner`、引数の受け渡し）。  
2. **UseCase / Repository に切り出した非同期処理**（`CoroutineScope` の境界、`Result` 型やエラー状態の載せ方）。
