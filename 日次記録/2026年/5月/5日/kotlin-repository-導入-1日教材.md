# Kotlin: Repository 導入（1日教材）

参照公式（最新方針の確認用）:

- [Data layer | App architecture | Android Developers](https://developer.android.com/topic/architecture/data-layer)
- [UI layer | App architecture | Android Developers](https://developer.android.com/topic/architecture/ui-layer)
- [ViewModel の概要 | Android Developers](https://developer.android.com/topic/libraries/architecture/viewmodel)

---

## 1. 今日のゴール（1〜2行）

目安時間: 2分

画面（UI）は **Repository 経由だけ** で本文データを取得し、一覧表示できる状態にする。ViewModel は Repository（の型は interface）だけを知り、データ取得の詳細（Fake か本番か）は **Factory など構築側** に閉じる。

---

## 2. 事前知識チェック（3問）※回答も付ける

目安時間: 5分

次の3問に口頭または紙で答えてから、ハンズオンに進む。

**Q1. ViewModel の役割は何か。**  
**A1.** UI 向けの状態を保持し、ユーザー操作に応じた処理をまとめる。原則として **Activity / Fragment より生存期間が長い**ため、回転などで UI が再生成されても同じインスタンスを再利用できる（※公式の UI layer では、状態と UI ロジックの担い手として位置づけられる）。

**Q2. 「API クライアントを Activity から直接呼ぶ」と何がまずいか。**  
**A2.** UI とデータ取得が密結合し、差し替え・再利用・テストが難しくなる。データの入り口を **Repository に集約**すると、取得元がネットワークでもローカルでも UI 側のコードを揺らしにくい（※公式でも UI は data source に直接触れず Repository を経由する前提が示される）。

**Q3. `suspend` とは何のためのキーワードか。**  
**A3.** コルーチンから安全に呼べる「一時停止しうる関数」を表す。時間のかかる処理（取得など）を、簡単な書き方でメインスレッドをブロックしにくく扱える（※厳密な仕様は後日でよい。今日は「Repository から `suspend` で返す」イメージで十分）。

---

## 3. 理論（重要ポイント3〜6個）

目安時間: 8分

重要ポイントは次の5つに絞る。比較観点は **「Repository を導入するとテストで何が楽になるか」** だけ深掘りする。

### 3.1. Repository は「データ層の窓口」である

- **要点**: UI / ViewModel から見えるデータの入り口を **1か所以上に束ねる**なら、その束ね役が Repository に相当する。公式では **Repository がデータソースへの直接アクセスを隠し、衝突の解消やビジネスロジックを抱えうる** と整理される。
- **よくある誤解/落とし穴**: 「Repository = DB ラッパー」だけに窄めると、API・DataStore・キャッシュが増えたときに再委譲地獄になりやすい。**画面単位の適当な `***Repository`** と **データ種別ごとの窓口**を混同しない（今日は1種類のデータだけなのでシンプルでよい）。

### 3.2. ViewModel は「Repository の利用者」にとどめる

- **要点**: ViewModel は UI 向けの状態更新やユースケースの呼び出しに集中し、**HTTP/DAO の詳細は知らない**方がよい。
- **よくある誤解/落とし穴**: 「とりあえず ViewModel に全部書く」が一番速いが、のちのち **肥大化した ViewModel** になりやすい。今日の段階では **取得処理は Repository に1行でも逃がす**ことを優先する。

### 3.3. 抽象化（interface）の有無はトレードオフである

- **要点**: **interface + 実装クラス**に分けると Fake（仮データ）と本実装の差し替えがしやすく、ユニットテストも書きやすい。**具体クラス1個だけ**でも動くが、公式でも **依存性の注入（コンストラクタで差し込む）** が推奨される。
- **よくある誤解/落とし穴**: 「interface が増えると難しい」は半分正しい。今日の規模なら **1インターフェース + Fake 実装** で十分であり、過剰な設計は不要。
- **設計の選択肢と、今日の選択理由（1つ）**
  - 選択肢A: `GreetingRepository` を **class のまま** Fake ロジックを直書き  
  - 選択肢B: `GreetingRepository` を **interface** にし、`FakeGreetingRepository` を **別クラス** にする  
  - **今日は B を採用**する。理由は **「ViewModel のテストや将来の差し替えで、コンストラクタ引数を変えるだけにできる」** 練習になり、公式が述べる **Repository を依存として注入** にそのまま繋がるからである。

### 3.4. 非同期・状態・エラーまわりの最低限の落とし穴

- **要点**: `viewModelScope.launch { ... }` の中は **コルーチン**。`suspend` の Repository 呼び出しは **メインスレッドを長時間ブロックしない**書き方に寄せやすい（処理の中身が重い計算なら別途 `Dispatchers.Default` などが必要だが、今日は List を返すだけなので扱わない）。
- **よくある誤解/落とし穴**:
  - **`MutableStateFlow` を UI スレッド外から更新しても動くことがあるが、一貫したルールを決めないと不具合の原因になる**。今日は **`viewModelScope`（Main イミュータブル既定）内だけで `value` を変える** と決め打ちする。
  - **`try` / `finally` で `isLoading` は下げても、`catch` が無いと例外時に一覧が古いまま・ログも残らない**ことがある。本番相当では **`runCatching { }` や `catch` で `StateFlow` にエラーを流す**などが必要（今日のコードは最小のため例外は握りつぶさず **クラッシュやコンソールエラーになりうる**点を知っておく）。
  - **画面を閉じたあと**: `viewModelScope` は **ViewModel 破棄時にキャンセル**される。長い通信をする前提なら **協調的キャンセル**の話題に触れるが、今日は深入りしない。

### 3.5. テスタビリティ＝「Android なしで検証できる塊」を増やすこと

- **要点**: Repository の契約（入力→出力）が明確なほど、**純粋な Kotlin として**検証しやすい。今日は **JUnit の最小テスト 1本** を用意する（後述）。
- **よくある誤解/落とし穴**:
  - 「UI テストを書けば十分」は重い。まず **Repository 契約のユニットテスト**から入るのがコスト対効果が高い。
  - **Fake に `delay` があると、`runBlocking` のテストがその分遅くなる**。許容できる遅さ（数十 ms）にするか、後日 `TestDispatcher` で進める（追加課題）。

---

## 4. ハンズオン（手順）

目安時間: 37分（**初めての環境では Gradle 同期や SDK で +10〜20分**かかることがある。全体として **60分枠**を想定する）

### 全体の置き場所（重要）

1. 今日の作業フォルダ（例: この TIL の日付フォルダなど）に **`tutorial/`** を作成する。  
2. Android Studio → **New Project** → 保存先（**Save location**）を **`…/tutorial/RepoBasics`** のように **`tutorial` 配下の空フォルダ**に指定する（プロジェクト名例: `RepoBasics`。親フォルダが既存プロジェクトだと警告が出るので、**必ず新しい空ディレクトリ**を選ぶ）。
3. **Git を使う場合**、リポジトリのルート（または日付フォルダ）に **`.gitignore` を追加**し、次の1行を書く（練習用の試行錯誤をコミットしないため）。

```gitignore
tutorial/
```

**確認方法**: Finder 等で `tutorial/RepoBasics/settings.gradle.kts`（または `.gradle`）が見え、**Git 利用時は** `git status` で `tutorial/` 配下が無視されること。

---

### ステップ1: 新規プロジェクト作成と依存関係（目安: 8分）

1. **New Project** → **Empty Activity**、**UI**: Jetpack Compose を選ぶ。**Language: Kotlin**、**Minimum SDK**: API 24 以上を推奨（エミュレータが古いと動かないため）。
2. プロジェクト同期（**Sync Now**）が終わるまで待つ。失敗したら **JDK 17** を Android Studio に割り当てているか確認する（**File → Settings → Build → Build Tools** 周辺）。
3. **`:app` の `build.gradle.kts`（または `build.gradle`）** で、次の依存関係を **足りないものだけ**追加する。既にテンプレートに含まれる行は重複させない（**`libs.versions.toml` 方式のプロジェクトなら、同じライブラリを Version Catalog 経由で1回だけ**足す）。

`build.gradle.kts` の例（**バージョンはプロジェクトの他依存と揃える。BOM を使うなら BOM に寄せる**）:

```kotlin
dependencies {
    // 既存の compose BOM / compose ui / material3 等はそのまま

    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    testImplementation("junit:junit:4.13.2")
}
```

（Groovy の場合は `implementation "..."` 形式に読み替える。`2.8.7` / `1.9.0` は **プロジェクトで既に使われている番号に合わせてよい**。）

**確認方法**: **Sync Project** が成功し、**Build → Make Project** が通る。

**迷いどころメモ**:

- **`collectAsStateWithLifecycle` が解決できない** → ほぼ **`lifecycle-runtime-compose` 未追加**。ステップ1の依存を見直す。
- **`Theme` でコンパイルエラー** → `ui/theme` パッケージに **`XxxTheme`**（Xxx はプロジェクト名由来）がある。**import を自動補完**させるか、そのファイル名を開いて実名を確認する。

---

### ステップ2: パッケージ作成と `GreetingRepository`（目安: 8分）

1. `app/src/main/java/<あなたのパッケージ>/` で右クリック → **New → Package** → `data` と `ui` を作る（例: `com.example.repobasics.data`）。
2. 次の2ファイルを `data` に追加する。

`GreetingRepository.kt`:

```kotlin
package com.example.repobasics.data

interface GreetingRepository {
    suspend fun getGreetings(): List<String>
}
```

`FakeGreetingRepository.kt`:

```kotlin
package com.example.repobasics.data

import kotlinx.coroutines.delay

class FakeGreetingRepository : GreetingRepository {
    override suspend fun getGreetings(): List<String> {
        // 擬似遅延（テストが遅くなりすぎない程度に留める）
        delay(80)
        return listOf(
            "おはよう",
            "こんにちは",
            "おやすみ",
        )
    }
}
```

**確認方法**: **Make Project** が成功する。パッケージ名 `com.example.repobasics` は **自分の Application ID / ディレクトリ構造に合わせて全置換**する。

---

### ステップ3: ViewModel から Repository を呼ぶ（目安: 8分）

`ui` パッケージに追加する。

`GreetingViewModel.kt`:

```kotlin
package com.example.repobasics.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.repobasics.data.GreetingRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class GreetingViewModel(
    private val repository: GreetingRepository,
) : ViewModel() {

    private val _greetings = MutableStateFlow<List<String>>(emptyList())
    val greetings: StateFlow<List<String>> = _greetings.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _greetings.value = repository.getGreetings()
            } finally {
                _isLoading.value = false
            }
        }
    }
}
```

`GreetingViewModelFactory.kt`:

```kotlin
package com.example.repobasics.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.repobasics.data.FakeGreetingRepository

class GreetingViewModelFactory : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(GreetingViewModel::class.java)) {
            return GreetingViewModel(FakeGreetingRepository()) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
    }
}
```

**確認方法**: コンパイルが通る。**`GreetingViewModel` のコンストラクタの型が `GreetingRepository` だけ**になっていることを確認する（**ViewModel 本体は `FakeGreetingRepository` を import しない**のが正解）。

---

### ステップ4: 画面から ViewModel を取得して一覧表示（目安: 7分）

既存の `MainActivity.kt` を次の構成に置き換える（**パッケージ宣言と `Theme` の import だけ自分のプロジェクトに合わせる**）。

```kotlin
package com.example.repobasics

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.repobasics.ui.GreetingViewModel
import com.example.repobasics.ui.GreetingViewModelFactory
import com.example.repobasics.ui.theme.RepobasicsTheme

class MainActivity : ComponentActivity() {

    private val viewModel: GreetingViewModel by viewModels {
        GreetingViewModelFactory()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            RepobasicsTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    GreetingScreen(viewModel = viewModel)
                }
            }
        }
    }
}

@Composable
fun GreetingScreen(viewModel: GreetingViewModel) {
    val greetings by viewModel.greetings.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.load()
    }

    if (isLoading && greetings.isEmpty()) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        return
    }

    LazyColumn {
        items(greetings) { item ->
            Text(text = item)
        }
    }
}
```

**`RepobasicsTheme` について**: 実際のシンボル名は **`ui/theme/Theme.kt`**（または同等）を開き、**`fun XxxTheme(...)` の `Xxx` 部分**に合わせて import と呼び出し名を置き換える（プロジェクト名が `Repobasics` なら多くの場合 **`RepobasicsTheme`** だが、大文字小文字の揺れがあるので **IDE の自動補完**が確実）。

**確認方法**: エミュレータまたは実機で起動し、**短いロードのあと 3 件**が縦に並ぶ。**ローディングが画面中央**に出ること。

---

### ステップ5: ユニットテスト 1本（最小）（目安: 6分）

1. `app/src/test/java/<パッケージ>/data/` を作成する（`androidTest` ではなく **`test`**）。
2. `FakeGreetingRepositoryTest.kt` を追加する。

```kotlin
package com.example.repobasics.data

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FakeGreetingRepositoryTest {

    @Test
    fun getGreetings_returns_expected_order_and_count() = runBlocking {
        val repo: GreetingRepository = FakeGreetingRepository()
        val items = repo.getGreetings()

        assertEquals(3, items.size)
        assertEquals(listOf("おはよう", "こんにちは", "おやすみ"), items)
        assertTrue(items.all { it.isNotBlank() })
    }
}
```

**確認方法**: テストクラスを右クリック → **Run** で **すべて緑**。`runBlocking` は **`delay` を実時間で待つ**ため、数十 ms かかるのは正常。

**よくある失敗**:

- **`test` ソースセットのパッケージが main とずれている** → ディレクトリ階層と `package` 宣言を一致させる。
- **`import org.junit.Test` を誤って別名にする** → コンパイルエラーになるので **JUnit4 の `org.junit.Test`** を指すことを確認する。

---

### ゴール達成の宣言

**ここまでできれば今日のゴール達成**: UI は Repository を直接知らず、ViewModel 経由で **仮データ取得 → 一覧表示** でき、**JVM ユニットテスト 1本**が通り、`.gitignore` で **`tutorial/` を除外** する前提も整っている。

---

## 5. 追加課題（時間が余ったら）

目安時間: 0〜10分

### Easy（5〜10分）

**課題**: `FakeGreetingRepository` の文言を1件追加し、画面とテストの期待値を追従させる。

**回答例（抜粋）**: `return listOf(..., "ただいま")` とし、`assertEquals(4, items.size)` と **期待 list 全体**を更新する。

---

### Medium（発展）

**課題**: `Result` 型で成功/失敗を返すように `GreetingRepository` を拡張し、ViewModel で失敗時にメッセージを `StateFlow<String?>` に流す。

**回答例（抜粋）**:

```kotlin
interface GreetingRepository {
    suspend fun getGreetings(): Result<List<String>>
}

class FakeGreetingRepository : GreetingRepository {
    override suspend fun getGreetings(): Result<List<String>> {
        delay(200)
        return Result.success(listOf("A", "B"))
    }
}
```

```kotlin
// ViewModel 側（要点）
private val _error = MutableStateFlow<String?>(null)
val error: StateFlow<String?> = _error.asStateFlow()

fun load() {
    viewModelScope.launch {
        _isLoading.value = true
        _error.value = null
        repository.getGreetings()
            .onSuccess { _greetings.value = it }
            .onFailure { _error.value = it.message ?: "error" }
        _isLoading.value = false
    }
}
```

---

### Hard（発展）

**課題**: 同じ `GreetingRepository` に **`NetworkGreetingRepository`（未実装で常に失敗）** を追加し、Factory だけ差し替えて挙動を切り替えられるようにする。**DI フレームワークは使わない。** さらに **`kotlinx-coroutines-test` と `runTest`** で ViewModel のテストを1本書いてみる（今日の本線からは外れるが実務に近い）。

**回答例（抜粋）**:

```kotlin
class NetworkGreetingRepository : GreetingRepository {
    override suspend fun getGreetings(): List<String> {
        error("not implemented")
    }
}

class GreetingViewModelFactory(
    private val repository: GreetingRepository = FakeGreetingRepository(),
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(GreetingViewModel::class.java)) {
            return GreetingViewModel(repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
    }
}

// Activity
private val viewModel: GreetingViewModel by viewModels {
    GreetingViewModelFactory(NetworkGreetingRepository())
}
```

---

## 6. 実務での使いどころ（具体例3つ）

目安時間: 3分

1. **ECアプリのカート**: `CartRepository` が **ローカルDBのカート行**と **在庫・価格API** を隠す。カート画面・注文確認・ミニカートの各 ViewModel は **`getCart()` のような同じ窓口**だけを呼び、**どこからデータが来たか**を意識しない。
2. **勤怠・現場入力アプリの打刻一覧**: オフライン時は **Room**、オンライン復帰で **同期API** を叩く流れを Repository に閉じる。画面側は **「期間指定で一覧」** だけを要求し、**リトライ・スタレデータの扱い**は Repository の責務に寄せる。
3. **設定画面の「利用規約URL」**: **Remote Config**・**サーバ設定JSON**・**ビルド時のデフォルト**の優先順位を Repository で一本化する。設定 ViewModel は **URL 文字列1本**だけ受け取り、**取得元の切り替え**をUIから切り離す。

---

## 7. まとめ（今日の学び3行）

目安時間: 2分

- 今日の学び1行目: **データ取得は Repository に集約し、UI は ViewModel → Repository の一方通行にすると責務が晴れる。**
- 今日の学び2行目: **interface + Fake 実装と JVM テストは、差し替え可能なデータ層の最低コストの安全網になる。**
- 今日の学び3行目: **非同期・状態・エラーは「完璧に扱わずに始めてよいが、どこで破綻しうるかだけは理論で拾う。**

---

## 8. 明日の布石（次のテーマ候補を2つ）

目安時間: 2分

1. **UseCase（インタラクター）を挟むかどうか**: ViewModel が太り始めたサインと、公式の層の考え方への接続（※深入りは翌日）。
2. **実 API へ置き換え**: `HttpURLConnection` など **標準APIのみ** で1エンドポイント叩き、Repository 内に閉じる（ライブラリ無し方針のまま）。
