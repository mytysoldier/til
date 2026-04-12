# Flutter（UIと状態管理の入口）— 1日分学習教材

**想定レベル:** 中級  
**目安時間合計:** 60分（セクション内訳の合計と一致）

---

## 1. 今日のゴール（目安時間：1分）

Flutter で「1画面・明示的な状態」を持つミニアプリを動かし、`StatefulWidget` の責務と UI 状態の境界を言語化できる。Compose / SwiftUI と比較する用語の対応表を頭に置く。

---

## 2. 事前知識チェック（目安時間：5分）

**Q1. Flutter の「画面の1単位」は何と呼ばれ、再描画の単位は何に紐づくか。**  
**A.** 画面の構成単位は **Widget**（`StatelessWidget` / `StatefulWidget` など）。`StatefulWidget` の場合、**`State` オブジェクト**が `setState` などで更新され、その Widget サブツリーが再ビルドされる。

**Q2. 「ビジネスロジック」と「UI の見た目」を分ける、という話で Flutter がまず触れる典型は何か。**  
**A.** 小規模では **`State` クラスにロジックを置く**か、**`ChangeNotifier` + `ListenableBuilder`（標準ライブラリ）**で通知と描画を分ける。大規模では Provider / Riverpod など（本日は外部パッケージなしの前提）。

**Q3. Jetpack Compose の `remember { mutableStateOf }` に近い「ローカル UI 状態」は Flutter で何に相当しやすいか。**  
**A.** **`StatefulWidget` の `State` 内のフィールド + `setState`**。Compose の `remember` は「再コンポジション間で値を保持」であり、Flutter では **`State` が `Element` にぶら下がって生存期間が保証される**点が近い。

---

## 3. 理論（目安時間：16分）

### ポイント1：Widget は「設定（immutable）」、`State` は「可変の心臓部」

`StatefulWidget` は軽く、`State` が `setState(() { ... })` で UI を更新する。再ビルドは **`build` 以下**が対象。

- **よくある誤解 / 落とし穴:** 「`setState` を多用すればどこでもよい」→ 不要な広い範囲を `setState` で巻き込むと再ビルドが肥大化。まずは **状態を1か所に集約**する。

### ポイント2：View の責務は「宣言」と「ユーザー入力の橋渡し」に寄せる

ボタンはイベントを上げ、表示は `build` が現在の状態を読むだけ、にするとテストしやすい。

- **よくある誤解 / 落とし穴:** 「Widget に全部書くのが Flutter 流」→ ロジックが `build` 内に混ざると副作用・テスト不能に。計算や I/O は **`build` の外**（`State` のメソッドや別クラス）。

### ポイント3：Kotlin / Swift との対応（ざっくり）

| 観点 | Kotlin (Compose) | Swift (SwiftUI) | Flutter |
|------|------------------|-----------------|---------|
| UI 宣言 | Composable | View | `Widget.build` |
| ローカル状態 | `remember` + `mutableStateOf` | `@State` | `State` + フィールド + `setState` |
| 画面外へ状態 | ViewModel + StateFlow 等 | `@Observable` / ObservableObject | `ChangeNotifier`、将来は Provider 等 |
| 再描画トリガ | state 変更 | プロパティ変更通知 | `setState` / `notifyListeners` |

- **よくある誤解 / 落とし穴:** 「SwiftUI の `@StateObject` と完全に同じ」→ SwiftUI はプロパティラッパで所有権が型に現れる。Flutter は **`State` のライフサイクル**（`createState` → `dispose`）で把握する。

### ポイント4：設計の選択肢（今日の選択）

**今日の選択：`StatefulWidget` + 単一 `State` クラスにカウンター状態を集約。** 理由は、依存ゼロで **ライフサイクル・再ビルド境界**を体験でき、後から `ChangeNotifier` や Provider に **状態クラスだけ移し替えやすい**から。

- **よくある誤解 / 落とし穴:** 「最初から状態管理パッケージ必須」→ 境界が分からないまま導入すると、**「何が Widget・何がドメインか」**が曖昧になる。

### ポイント5：テスト

`flutter_test` の **`WidgetTester`** で「タップ → 期待テキスト」は UI の契約を固定できる。`Scaffold` / `Material` を要するウィジェットは、テストでは **`MaterialApp` で包む**（本ハンズオンで実施）。

- **よくある誤解 / 落とし穴:** 「Widget テストは E2E」→ まずは **単一画面・単一ボタン**の golden path で十分効く。

### ポイント6：非同期・エラー・型（今日の入口で踏みがちな点）

API や `Future` の結果で UI を更新するとき、**`await` の後にそのまま `setState` すると、すでに `dispose` 済みでクラッシュ**しうる。実務では **`if (!context.mounted) return;`（Dart 3）** や、コールバック内での **`mounted` チェック**が定番。

- **よくある誤解 / 落とし穴:** 「`setState` の中で `await` すれば安全」→ **`setState` は同期ブロック**であり、非同期処理の完了タイミングは別。非同期完了後は **`mounted` を確認してから** `setState`。
- **型:** カウンターは `int` に固定し、`Text` には `'$_count'` のように **常に文字列化**（`null` を渡さない）。

---

## 4. ハンズオン（手順）（目安時間：27分）

**前提:** Flutter SDK をインストール済み。最初に **`flutter doctor`** で致命的なエラーがないことを確認する。作業は `tutorial` 配下を想定（本フォルダの `.gitignore` で `tutorial/` を除外済み）。

**つまずきメモ（優先順）:** デバイスが無い → `flutter run -d chrome` またはエミュレータ起動。パッケージ名エラー → `pubspec.yaml` の `name:` と `import 'package:counter_mini/...'` が一致しているか。テスト失敗 → 手順5の **`MaterialApp` で包む**ことと、`await tester.pump()` を忘れていないか。

### ステップ0 — `tutorial` と `.gitignore`

- **手順:** 本日の学習フォルダでは `.gitignore` に `tutorial/` を記載済み。別場所で学ぶ場合は作業ルートに同様の `.gitignore` を置く。
- **確認方法:** `git status` で `tutorial/` 内が無視される（または `.gitignore` に `tutorial/` がある）。

### ステップ1 — プロジェクト作成

```bash
mkdir -p tutorial && cd tutorial
flutter create counter_mini
cd counter_mini
flutter pub get
```

- **確認方法:** `flutter run` で **サンプルのカウンター画面**が起動する（このあと置き換える）。

### ステップ2 — デフォルトの `main.dart` を置き換える前提を理解する

`flutter create` 直後は `lib/main.dart` に **`MyApp` / `MyHomePage`** が入っている。**この教材では `main.dart` を下記の短い形に差し替え**、`lib/counter_page.dart` に画面本体を置く（責務の分離の練習）。

- **確認方法:** ステップ3〜4のコードに差し替えたあと、**AppBar タイトルが「Counter Mini」**になり、元の `MyHomePage` 文言が消えている。

### ステップ3 — `lib/counter_page.dart` を新規作成

`CounterPage` を `StatefulWidget` とし、`_count` と `_increment` を `State` に置く。

**`lib/counter_page.dart`:**

```dart
import 'package:flutter/material.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _count = 0;

  void _increment() => setState(() => _count++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter Mini')),
      body: Center(
        child: Text(
          '$_count',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### ステップ4 — `lib/main.dart` を差し替え

**既存の `lib/main.dart` の内容をすべて削除**し、次で置き換える。

**`lib/main.dart`:**

```dart
import 'package:flutter/material.dart';
import 'counter_page.dart';

void main() {
  runApp(const MaterialApp(home: CounterPage()));
}
```

- **確認方法:** `flutter run` で FAB を押すたびに数値が **1 ずつ増える**。ホットリスタート後は **0 に戻る**（永続化なし）。コンソールに **赤いエラーが出ない**。

### ステップ5 — Widget テスト 1 本（必須）

**テストでも `MaterialApp` で `CounterPage` を包む。** 単体で `pumpWidget(CounterPage())` だけにすると、`Material` 祖先不足などで挙動・警告が変わりうる。

**`test/counter_page_test.dart` を新規作成**（`counter_mini` がパッケージ名。`pubspec.yaml` の `name: counter_mini` と一致させる）:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_mini/counter_page.dart';

void main() {
  testWidgets('FAB を押すと表示が 0 から 1 に増える', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CounterPage()),
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
```

- **確認方法:** プロジェクト直下で **`flutter test`** がすべて成功する（exit code 0）。

**最小成果物:** `tutorial/counter_mini` でカウンターが動き、**`flutter test` が緑**。

---

## 5. 追加課題（時間が余ったら）（目安時間：4分）

### Easy — デクリメントボタンを追加

```dart
void _decrement() => setState(() => _count--);
// IconButton などで onPressed: _decrement
```

### Medium — `build` 内で副作用を書かず、表示用の getter に寄せる

```dart
String get _label => 'Count: $_count';
// body: Text(_label)
```

### Hard — `ValueNotifier<int>` + `ValueListenableBuilder` で同じ見た目（`dispose` で `dispose`）

```dart
final ValueNotifier<int> _count = ValueNotifier(0);

@override
void dispose() {
  _count.dispose();
  super.dispose();
}

// build 内:
ValueListenableBuilder<int>(
  valueListenable: _count,
  builder: (context, value, _) => Text('$value'),
)
// FAB: onPressed: () => _count.value++
```

---

## 6. 実務での使いどころ（具体例3つ）（目安時間：3分）

1. **レビュー投稿フォームの文字数表示:** 入力のたびに `setState` で `_length` だけ更新し、送信ボタンの活性は「140 文字以内」などを同じ `State` で判定（のちに `TextEditingController` へ）。
2. **社内ツールの「環境切替」ドロップダウン:** 開発 / ステージングの選択を `State` に保持し、次画面への引き渡しや Dio の baseUrl 切り替えのトリガにする（永続化は別レイヤ）。
3. **オンボーディングのページインジケータ:** `_pageIndex` と「次へ」でだけ UI を更新し、完了 API は `mounted` 確認のうえで `Navigator` 遷移（非同期の落とし穴を意識した構成の練習台）。

---

## 7. まとめ（今日の学び3行）（目安時間：2分）

- `StatefulWidget` / `State` / `setState` が、Compose の remember+State に近い「ローカル UI 状態」の入口。
- View は宣言とイベント転送に寄せ、`build` に副作用を混ぜない。非同期後は **`mounted` / `context.mounted`** を忘れない。
- Kotlin / Swift の状態・再描画の語彙と対応づければ、以降の Riverpod 等も「境界の移し替え」として理解しやすい。

---

## 8. 明日の布石（次のテーマ候補を2つ）（目安時間：2分）

1. `ChangeNotifier` + `ListenableBuilder` / `AnimatedBuilder` と、Widget からの購読の切り方
2. `TextEditingController`・フォーカス・キーボードと、`StatefulWidget` の `dispose` 必須リソース

---

## 補足

- **設計の選択と理由:** 本日は外部パッケージなしの `StatefulWidget` を選び、状態の置き場と再ビルドの境界を体験してから、通知ベースや DI に拡張する。
- **ファイル:** `lib/main.dart`, `lib/counter_page.dart`, `test/counter_page_test.dart`
- **実行:** プロジェクト直下で `flutter run` / `flutter test`
