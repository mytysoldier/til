# Kotlin：データ保持と state 接続（1日分教材）

公式ドキュメントの整理の目安：[Android アーキテクチャ](https://developer.android.com/topic/architecture)、[ViewModel の概要](https://developer.android.com/topic/libraries/architecture/viewmodel)、[Kotlin コルーチンと Flow](https://kotlinlang.org/docs/flow.html)（状態は `StateFlow` で単方向データフローに寄せる前提）。

---

## 1. 今日のゴール

**（目安時間：2分）**

今日の終わりに、「Repository がデータを供給する → ViewModel が `UiState` を **`StateFlow` で単一ソース化**する → Compose が **ライフサイクルに沿って購読**して一覧を描く」という**データフローを一本**で説明できる。

**完了の定義（チェックリスト）**

- [ ] アプリ起動後、短いローディングのあと **3 件の一覧**が出る（エミュレータまたは実機）。
- [ ] **Run Tests** で `ItemRepositoryTest` が緑（オフラインでも可）。
- [ ] 口頭またはメモで、「一覧は **どのレイヤがいつ更新**したか」を説明できる。

---

## 2. 事前知識チェック（3問）

**（目安時間：4分）**

### 問1：`suspend` と通常の関数の違いは何ですか？

**回答：** いったん処理を中断し、スレッドを占有し続けない「非ブロッキングな中断可能な処理」を表現するために使われることが多いです。Coroutine のスコープ内でしか直接呼べません。

---

### 問2：UI が「状態」を持つとき、Activity に直接大量の変数を置くと何が起きやすいですか？

**回答：** 画面回転やプロセス再生成で値が失われたり、テストや再利用が難しくなり、責務が混ざります。画面の「表示用の状態」は ViewModel などへ寄せるのが実務では一般的です。

---

### 問3：`Flow` は「イベント」にも「状態」にも使えますか？

**回答：** はい（用途で設計が変わります）。**イベント単発通知**にも**最新値を保持したい状態ストリーム**にも使えますが、Compose と組み合わせるとき「最新の状態」は `StateFlow` が扱いやすいです。

---

## 3. 理論（重要ポイント）

**（目安時間：10分）**

### ポイント1：データの「置き場」を分ける——Repository は「データ取得の入口」

**内容：** Repository は、`ViewModel` が「データの由来（メモリ・ローカルDB・将来的にネットワーク）」を知らなくて済むようにするレイヤーの入口です。**今日はフェイク実装のみ**とし、クラスの形だけ掴みます（`interface` 分割は追加課題でも可）。

**よくある誤解/落とし穴：** 「Repository があれば状態管理まで面倒を見てくれる」——**しません**。Repository は取得・キャッシュなど**データ側**。画面上の「単一の真実」は ViewModel がまとめます。

---

### ポイント2：単方向データフロー（状態は一方向）

**内容：** 「データソース → Repository → ViewModel が state を更新 → UI が読む → ユーザー操作は関数呼び出しで上げる」の一方通行にすると追いやすいです。**state は immutable に寄せ、更新は `_uiState.update { it.copy(...) }`**が基本です。

**よくある誤解/落とし穴：** UI が `remember { mutableStateOf(...) }` で独自のソースを増やすと、`ViewModel` の `UiState` と食い違うバグになります。**表示の単一ソース**は ViewModel の `UiState` に寄せます。

---

### ポイント3：`StateFlow` は「購読しやすい最新の値」

**内容：** `StateFlow<UiState>` にすると、Compose では **`collectAsStateWithLifecycle()`** が推奨です（開始・停止や画面のライフサイクルに連動）[該当 API](https://developer.android.com/jetpack/compose/libraries#lifecycle)。**常に最新の UiState が一つ**という前提が立てやすくなります（[StateFlow と SharedFlow](https://kotlinlang.org/docs/stateflow-and-sharedflow.html)）。

**よくある誤解/落とし穴：** `StateFlow` は**ホット**。初期値がそのまま「最初に描画される内容」にも効くので、**初フレームだけ空表示がフラッシュする**などは設計で潰します（ローディングをいつ出すかを決める）。

---

### ポイント4：設計の比較観点（今日はこれひとつ）—— Repository を ViewModel からどう見せるか

**内容：** 実務では **Use Case（Interactor） を挟む**選択もありますが、今日の規模では **ViewModel → Repository を直接依存**させます。

**選択肢：**  
A) ViewModel → Repository  
B) ViewModel → UseCase → Repository  

**なぜ A にしたか（一言）：** 60 分前後で「データの流れの一本線」を確認する優先。**ドメインロジックや再利用が増えたフェーズで B を検討**するほうが、入口では迷いが少ないです。

---

### ポイント5：`UiState` は `data class` で表現すると追跡がしやすい

**内容：** 「画面に最低限必要な情報」を一つの型に閉じます。**余計なフラグだけ増える**ときは、`sealed class` で状態を区切る検討（追加課題の Hard）。

**よくある誤解/落とし穴：** 「とりあえず全部 `nullable`」と「`isLoading` の二重」の混在。**ローディング中に前回リストを見せる**場合など、フラグだけでは伝わらなくなるので、いつでも **「ユーザーに見せている意味」で読める**名前にすることが多いです。

---

### ポイント6：今日の実務でも効く「落とし穴」短リスト（ここだけは頭に残す）

1. **非同期：** **`StateFlow.update` はスレッドセーフ**ですが、**`UiState` の中身がスレッドセーフでないと意味がない**（例：`MutableList` を渡して別スレッドから触る）。**IO 境界では `withContext(Dispatchers.IO)`、反映は `update` に一本化**するのが実務の基本形——今日は Repository が同期的なので省略。

2. **状態：** 「ローディング + リスト同時」を許すか許さないかを曖昧にしない（**空リストのときのローディング**とエラーの見せ分け）。**`isLoading` と `errorMessage` が同時に立つ**設計は避ける（どちらを表示するかがブレる）。

3. **エラー：** `catch` の範囲が広すぎると **原因の切り分けができない**。本番は **ユーザー向け文言・ログ・リトライ可否**を分ける。`e.message` は **null や英語のまま**になりがちなので、少なくとも「読み込めませんでした」＋ログ送信までをセットで考える。

4. **型：** `List<Item>` をそのまま `UiState` に持つとき、**ミュータブルリストを代入しない**（`toList()` で防御）。**`copy` したつもりが中身は共有**、はランタイムでしか気づけないバグになりやすい。

5. **テスト：** **Repository は「Android 非依存の契約テスト」**、画面状態の振る舞いは **`FakeRepository` + `ViewModel` テスト**が定石（今日は前者 1 本でレイヤー分けの感覚を取る）。

---

## 4. ハンズオン（手順）

**（目安時間：35分）**

**最小成果物：** `tutorial/` フォルダ配下に Android Studio プロジェクトを作成し、**Repository → ViewModel（StateFlow）→ Compose で一覧表示**までが **ビルドと実行・テスト1本**が通る状態にする。

**フォルダ方針：** 手順どおり **`tutorial`** をワークスペースまたは任意の親ディレクトリに作り、その中でプロジェクトを進めます。教材開始時は **ソースファイルは作らなくて構いません**。

**Git について：** 作業親などに置く `.gitignore` の例です。

```
# .gitignore 例（学習用をコミットに混ぜたくないとき）
/tutorial/
```

---

### ステップ1：プロジェクト作成

**やること**

1. Android Studio で **New Project** → **Empty Activity**（**Jetpack Compose** オン）を選択する。  
2. **Save location** を `.../tutorial/StateRelay` のように **`tutorial/` 配下**とする。**Language は Kotlin**。  
3. **Min SDK はテンプレのままで可（API 26 程度以上が無難）**。

**初心者が詰まりやすい点：** ウィザード完了後、Android Studio が **Gradle Sync** を走らせるまで **数分かかることがある**。Sync 失敗時は **JDK 17** と **SDK の Android API** が入っているか、エラーペインのリンクから Studio が案内する **「Install missing …」** を先に片付ける。

**確認方法（期待される出力/挙動）**

- Gradle Sync が終わり、エミュレータまたは実機で **デモ画面が動く**。

---

### ステップ2：パッケージだけ用意する（空）

**やること**

プロジェクト既定のパッケージの下に、例として次を作る（名前はこれでなくてよい）。

- `data` … モデルと Repository  
- `ui` … Composable と ViewModel  

`UiState` は **ViewModel と同ファイル**でも **`ui` または `model` に切り分けてもよい**。今日は **ViewModel ファイル直下**で問題ありません。

**確認方法**

- Project ツリーでフォルダが見えること。

---

### ステップ3：データモデルと Repository（フェイク）

**ファイル名：** `data/Item.kt`、`data/ItemRepository.kt`（実パスは自分のモジュールに合わせる）

**やること**

- `Item` と、固定リストを返す `suspend` の Repository を定義する。

**最小コード例**

```kotlin
// Item.kt
package com.example.staterelay.data

data class Item(
    val id: String,
    val title: String,
)

// ItemRepository.kt
package com.example.staterelay.data

class ItemRepository {

    suspend fun loadItems(): List<Item> {
        // 呼び出し側がミュータブル List を渡さない前提でも、実務では toList() で防御することが多い
        return listOf(
            Item(id = "1", title = " Kotlin / Repository "),
            Item(id = "2", title = " StateFlow と UiState "),
            Item(id = "3", title = " 単方向データフロー "),
        ).toList()
    }
}
```

**確認方法**

- **Rebuild Project** が通る。

---

### ステップ4：Gradle を一度だけ確認してから ViewModel を書く

**やること（先に Gradle）**

- **依存関係（ビルド用）：** `:app` の `build.gradle.kts` に **ViewModel** と **`lifecycle-runtime-compose`**（Compose から `ViewModel` を取得し、`collectAsStateWithLifecycle` などライフサイクル連携のために必要）が **揃っていることを確認**する。**Compose テンプレートなら既定で入っていることが多い**。外部ライブラリの追加は、**テンプレートに無い行だけ最小限**。要件・バージョンは [ViewModel の概要](https://developer.android.com/topic/libraries/architecture/viewmodel) と [Compose における Lifecycle](https://developer.android.com/jetpack/compose/libraries#lifecycle) を参照。

- **追記例（`app/build.gradle.kts` の `dependencies { }` 内・直接記述パターン）：** バージョンは **他の androidx と揃える**か、公式ドキュメントに合わせて更新する。

```kotlin
// app/build.gradle.kts の dependencies { } 内への追記例（既にあれば重複させない）
dependencies {
    // … 既存の implementation …

    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.7") // viewModelScope
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7") // viewModel()
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7") // collectAsStateWithLifecycle()
}
```

- **Gradle Sync**。エラーになったら **Lifecycle 系のバージョンをひとつに揃える**。**`viewModelScope` が Unresolved** のときは **`lifecycle-viewmodel-ktx`** の記述有無を確認する。

**やること（ViewModel）**

- `UiState`（`isLoading` / `items` / `errorMessage` の **data class**）  
- `MutableStateFlow` + `_uiState` / 公開の `uiState`  
- `viewModelScope.launch` で Repository を読み、`update { it.copy(...) }` で状態を変える  

**ファイル名：** `ui/ItemViewModel.kt`（パッケージはプロジェクトに合わせる）

**最小コード例**

```kotlin
package com.example.staterelay.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.staterelay.data.Item
import com.example.staterelay.data.ItemRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class UiState(
    val isLoading: Boolean = false,
    val items: List<Item> = emptyList(),
    val errorMessage: String? = null,
)

class ItemViewModel(
    private val repository: ItemRepository = ItemRepository(),
) : ViewModel() {

    private val _uiState = MutableStateFlow(UiState(isLoading = true))
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val list = repository.loadItems().toList()
                _uiState.update {
                    it.copy(isLoading = false, items = list, errorMessage = null)
                }
            } catch (e: Exception) {
                // 本番ではログ（Firebase / Sentry 等）に e を送り、画面は固定文言寄りにすることが多い
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = e.message?.takeIf { it.isNotBlank() }
                            ?: "読み込みに失敗しました",
                    )
                }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }
}
```

**設計メモ：** 初期状態を **`UiState(isLoading = true)`** にすると、Compose 側では **初フレームからローディング**に寄せられます（フラッシュ対策）。

**確認方法**

- **ビルド成功**。`MainActivity` からまだ参照しなくてもよいが、未定義クラスがなくコンパイルが通ること。

---

### ステップ5：`MainActivity.kt` と `ItemListScreen` をつなぐ（コピペで動く形）

**やること**

- `MainActivity` の `setContent` で `viewModel()` を取得し、`collectAsStateWithLifecycle()` で購読。  
- **`ItemListScreen`** は下記をそのまま使ってよい（**不足 import は IDE の Optimize Imports で追加**）。
- **ウィザードが生成した `...Theme { }` と `enableEdgeToEdge()` は削らず残す**のが無難（この教材の抜粋は `MaterialTheme` 固定だが、実プロジェクトでは **テーマラッパー＋`Surface`** のみ差し替える）。

**ファイル名：** `MainActivity.kt`、`ui/ItemListScreen.kt`（同じファイルでも可）

**パッケージのルール：** `ItemViewModel.kt`（と `UiState`）と `ItemListScreen.kt` を **同じ `ui` パッケージ**に置けば `UiState` の **import は不要**。別パッケージに分けた場合は `import ……UiState` を追加する。

**最小コード例（MainActivity は必要部分のみ）**

```kotlin
package com.example.staterelay // 自分のパッケージに合わせる

import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.staterelay.ui.ItemListScreen
import com.example.staterelay.ui.ItemViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // テンプレに enableEdgeToEdge() がある場合はここに残す
        setContent {
            // 実務テンプレなら MaterialTheme ではなく MyApplicationTheme { … } に置き換え
            MaterialTheme {
                Surface(Modifier.fillMaxSize()) {
                    val vm: ItemViewModel = viewModel()
                    val uiState by vm.uiState.collectAsStateWithLifecycle()
                    ItemListScreen(
                        uiState = uiState,
                        onRetry = { vm.load() },
                    )
                }
            }
        }
    }
}
```

**最小コード例（`ItemListScreen.kt` 本文）**

```kotlin
package com.example.staterelay.ui // 自分のプロジェクトに合わせて変更

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun ItemListScreen(
    uiState: UiState,
    onRetry: () -> Unit,
) {
    when {
        uiState.errorMessage != null -> {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = uiState.errorMessage,
                    style = MaterialTheme.typography.bodyLarge,
                )
                Button(
                    onClick = onRetry,
                    modifier = Modifier.padding(top = 16.dp),
                ) {
                    Text("再試行")
                }
            }
        }
        uiState.isLoading && uiState.items.isEmpty() -> {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
        }
        else -> {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(uiState.items, key = { it.id }) { item ->
                    Text(
                        text = item.title.trim(),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            }
        }
    }
}
```

**落とし穴（Compose）：** **`@Preview` で `viewModel()` を書かない**——プレビューは `ItemListScreen(UiState(items = dummy), ...)` のような **固定状態**だけにする。

**確認方法（期待される出力/挙動）**

- アプリを起動すると **スピンのあとに 3 行の一覧が出る**。  
- 開発者メニューで **Dont keep activities をオフにした状態**でも、一覧が再構成されることを軽く目視確認できればベター。

---

### ステップ6：`src/test/` に Repository のテスト 1 本

**やること**

- **`src/test/java/.../data/ItemRepositoryTest.kt`** を追加（パッケージは **`ItemRepository` と同じ `…data`** が扱いやすい）。**件数・ID 順・タイトル非空・再呼び出しで壊れないこと**を検証する（契約テストの最小セット）。  
- `runBlocking` が **未解決**なら、`implementation` 側の **`kotlinx-coroutines`** と揃えた `testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:…")` を足すか、Studio の **Add dependency on the classpath** 提案に従う。


**やらないこと（今日のスコープ外だが実務ではこうする）：** `AndroidJUnit4` や `compose` の UI テストは重いので、**まず JVM の `src/test` で Repository／ViewModel の振る舞い**から切る。

**Gradle 追加の例（足りないときだけ）**

```kotlin
dependencies {
    testImplementation("junit:junit:4.13.2")
    // 必要なときだけ — BOM / Version Catalog と揃える
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}
```

※ バージョン番号は **プロジェクトが既に使っている kotlinx-coroutines** に寄せて書き換える。

**テストコード例**

```kotlin
package com.example.staterelay.data

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class ItemRepositoryTest {

    @Test
    fun loadItems_returnsStableContract() = runBlocking {
        val repo = ItemRepository()
        val items = repo.loadItems()
        assertEquals(3, items.size)
        assertEquals(listOf("1", "2", "3"), items.map { it.id })
        assert(items.all { it.title.isNotBlank() })
        // フェイクでも「毎回独立した一覧」を返す前提（ミュータブル共有の早期検知用）
        val again = repo.loadItems()
        assertEquals(items.map { it.id }, again.map { it.id })
    }
}
```

**このテストが意味を持つ理由（実務）：** API／DB の実装が変わっても **「この画面が期待するデータの形」**が壊れていないかを CI で先に止められる。次の段階では **`FakeRepository`（遅延・失敗・空リスト）を差し替えた `ItemViewModelTest`** に拡大する。

**確認方法**

- **Run Tests** が緑。失敗時は **テストソースセットの依存関係**と **テストクラスのパッケージ**を疑う。

### ハンズオン：詰まったときの優先チェック（3分以内）

| 症状 | まず見る場所 |
|------|----------------|
| `viewModel` / `collectAsStateWithLifecycle` が赤い | ステップ4 の **`lifecycle-runtime-compose` / `lifecycle-viewmodel-compose`** と **`lifecycle-viewmodel-ktx`** |
| `ItemViewModel` が見えない | `MainActivity` の **`import …ui.ItemViewModel`**（デフォルトは **ルートパッケージ／`ui` サブパッケージ**の組み合わせ） |
| `UiState` が見えない | `ItemListScreen` と `ItemViewModel` を **同じパッケージに置いたか**、または `import` |
| テストだけ赤い | **`src/test/java/.../data/ItemRepositoryTest.kt`** のように **ディレクトリ＝パッケージ**が一致しているか（例：`package com.example.staterelay.data`） |
| 画面は動くが真っ白 | `UiState` 初期が **`isLoading = true` か**、`ItemListScreen` の **`when` 分岐**が `items.isEmpty()` を想定と一致しているか |

---

**ここまでできれば今日のゴール達成**

- 「Repository がデータの入口」「ViewModel が `UiState` を **`StateFlow` で単一ソース化**」「Compose が **`collectAsStateWithLifecycle`** で読む」の一本が通っている状態。

---

## 5. 追加課題（時間が余ったら）

### Easy（5〜10分）

画面上部に **`Button("再読み込み")`** を追加し、`onRetry` と同じ `vm.load()` を呼ぶ。`LazyColumn` 上または `SmallTopBar` がなくてよい。**ローディング中の二重タップ連打対策は今日は無しで可**（発展）。

**回答例**

```kotlin
Button(onClick = onRetry, modifier = Modifier.padding(16.dp)) {
    Text("再読み込み")
}
```

---

### Medium

`Repository` に **`delay`** を入れ、`isLoading == true` の間が視覚的に確認できるようにする。そのうえで **`kotlinx-coroutines-test` の `runTest`** と仮時間の進み方を公式に沿って読む。**テスト**は **`runBlocking` でなく `runTest`** に差し替えて検討してよい。

**回答コード例のイメージ（Repository）**

```kotlin
suspend fun loadItems(): List<Item> {
    kotlinx.coroutines.delay(400)
    return listOf(/* ... */)
}
```

---

### Hard

`UiState` の代わりに **`sealed interface` で画面状態**（Loading / Content / Failed）へ置き換え、Compose は **`when` だけ**で分岐する（`if` 連鎖にしない）。**`isLoading` と `errorMessage` の同時成立**のような不正な組み合わせが、型として表現されなくなることを確認する。

**回答コード例（教材のパッケージ・`ItemRepository` を流用する想定）**

`UiState` data class をやめ、次を **ViewModel と同じファイルまたは `ItemScreenState.kt`** に置く。

```kotlin
package com.example.staterelay.ui

import com.example.staterelay.data.Item

sealed interface ItemScreenState {
    data object Loading : ItemScreenState
    data class Content(val items: List<Item>) : ItemScreenState
    data class Failed(val message: String) : ItemScreenState
}
```

**`ItemViewModel.kt`（`StateFlow` の型だけ差し替え）**

```kotlin
package com.example.staterelay.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.staterelay.data.ItemRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ItemViewModel(
    private val repository: ItemRepository = ItemRepository(),
) : ViewModel() {

    private val _screenState = MutableStateFlow<ItemScreenState>(ItemScreenState.Loading)
    val screenState: StateFlow<ItemScreenState> = _screenState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _screenState.value = ItemScreenState.Loading
            try {
                val list = repository.loadItems().toList()
                _screenState.value = ItemScreenState.Content(list)
            } catch (e: Exception) {
                _screenState.value = ItemScreenState.Failed(
                    e.message?.takeIf { it.isNotBlank() }
                        ?: "読み込みに失敗しました",
                )
            }
        }
    }
}
```

※ 全体を入れ替えるだけなので **`value` 代入**でもよい。`update { }` は「前の `data class` を微修正」するとき向けで、**判別共用体を丸ごと差し替える**なら `value =` で十分読みやすいことが多い。

**`ItemListScreen.kt`（`when` のみ・網羅チェックを効かせる）**

（**`import` は手順5の `ItemListScreen` と同じ。** `@Composable` 以外に追加不要。）

```kotlin
@Composable
fun ItemListScreen(
    screenState: ItemScreenState,
    onRetry: () -> Unit,
) {
    when (screenState) {
        ItemScreenState.Loading -> {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
        }

        is ItemScreenState.Content -> {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(screenState.items, key = { it.id }) { item ->
                    Text(
                        text = item.title.trim(),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            }
        }

        is ItemScreenState.Failed -> {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = screenState.message,
                    style = MaterialTheme.typography.bodyLarge,
                )
                Button(
                    onClick = onRetry,
                    modifier = Modifier.padding(top = 16.dp),
                ) {
                    Text("再試行")
                }
            }
        }
    }
}
```

**`MainActivity.kt`（購読する `StateFlow` の名前だけ変更）**

```kotlin
val vm: ItemViewModel = viewModel()
val screenState by vm.screenState.collectAsStateWithLifecycle()
ItemListScreen(
    screenState = screenState,
    onRetry = { vm.load() },
)
```

**確認のねらい：** 分岐に **`is ItemScreenState.Content` を足し忘れたらコンパイルが通らない**（モジュールの設定によっては警告）。**「ローディング中なのにエラー文言もある」**といった状態は、別途 `Content` にバナー用フィールドを足すなど**設計を明示しないと書けない**。

## 6. 実務での使いどころ（具体例3つ）

**（目安時間：4分）**

1. **通信失敗でもオフライン体験を維持する商品一覧／記事一覧：** `Repository` が 「ネット失敗時は Room のキャッシュ」「成功時は API」を **`suspend` または `Flow` で一本化**。`UiState` は **一覧＋帯域状況（例：バナー文言）**のみ。実務での判断軸は **「空画面より、古くても読めるコンテンツ＋問題表示」**（ただし決済まわりなど鮮度必須領域は別設計）。

2. **インフィード広告・おすすめ行の差し込み：** 同じ `LazyColumn` でも **データ取得は Repository**、**何行目に何を出すかは `UiState` のスナップショット**に閉じると、AB テストや Config 切替で **Compose を触り過ぎず**済む。

3. **機能トグル・メンテナンス表示：** Remote Config やバックエンドの **「一覧 API を返すか／メンテ文言」**だけを `Repository` で吸収し、**画面は `UiState` のフラグで分岐**——ストア審査中の段階的リリースや **緊急時の表示切替**でチームが揉めない。

---

## 7. まとめ（今日の学び3行）

**（目安時間：2分）**

**データの入口（Repository）**と**画面上の単一の真実（`UiState` + `StateFlow`）**を分離すると、非同期結果を「いつユーザーに見せるか」が読みやすくなる。**Compose は購読と描画**。**Gradle と初期ローディングの設計だけ**でも「動いたのにフラッシュだけおかしい」が減る。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**（目安時間：2分）**

1. **`ViewModel` のコンストラクタ注入**と **`ViewModelProvider.Factory`** でのテストダブルの差し替え（手動 DI だけでも構造がはっきりする）。  

2. **Room + Flow** で「ソースが変わるたび `Repository` が最新を流す」パターン。今日のフェイクからデータ層のみ差し替えてみる。

---

**合計目安：** **55〜65 分**（理論を軽く読み飛ばすなら **50 分前後**）。**Android Studio／Gradle が初めて**なら **+15〜25 分**見てよい（同期・SDK・JDK で止まりがち）。**60 分枠の現実的割合**の一例：**ハンズオン 35〜40 分・理論＋振り返り 15〜20 分・実務例 5 分**。余裕がなければ **セクション3のポイント6だけ読んでからステップ1へ**でもよい。
