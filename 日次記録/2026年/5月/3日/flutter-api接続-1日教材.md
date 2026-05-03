# Flutter（API接続）1日学習教材

公式参照: [Fetch data from the internet](https://docs.flutter.dev/cookbook/networking/fetch-data)（Flutter Cookbook）

---

## 1. 今日のゴール

**目安時間（分）: 2**

JSON API から 1 件取得し、読み込み中・成功・失敗の UI を出し分けられる画面を、ローカルで実行できる状態にする（外部パッケージは [`http`](https://pub.dev/packages/http) のみ）。モデルは **`lib/todo_item.dart` に分離**し、テストで `main.dart` 全体を引きずらない構成にする。

---

## 2. 事前知識チェック（3問）

**目安時間（分）: 5**

1. **`async` / `await` は何のためにある？**  
   **答え:** 時間のかかる処理（ネットワークなど）を「待つ」ときに、コードを順番に読みやすくし、結果や例外を通常の制御フローで扱うため。

2. **`StatefulWidget` の `State` に置くべきものと、`build()` の中で毎回計算すべきでないものの例は？**  
   **答え:** 画面の「表示に影響するデータ」や「一度だけ開始したい Future」は `State` に置く。API 呼び出しを `build()` に書くと再描画のたびに再実行されやすいので避ける（[Cookbook の説明](https://docs.flutter.dev/cookbook/networking/fetch-data#why-is-fetchalbum-called-in-initstate)）。

3. **`FutureBuilder` は何を簡略化する部品？**  
   **答え:** `Future` の待機中・成功・失敗の 3 状態に応じた UI の切り替え（ローディング表示など）。

---

## 3. 理論（重要ポイント）

**目安時間（分）: 10**

1. **通信と UI は「非同期」でつなぐ**  
   API は完了タイミングが不定。`await` で待ったあと、**状態を更新**して `build` が走ると UI が変わる（`setState` または `FutureBuilder` が状態変化のきっかけになる）。

2. **「成功？」は HTTP 200 と JSON の形の両方を見る**  
   ステータスが 200 でも、本文が JSON でなかったりキーが違うと **パースやキャストで例外**になる。Cookbook でも「404 などは例外にして `snapshot.hasError` を真にする」と整理されている。

3. **よくある誤解: `build()` の中で `fetch` を呼ぶ**  
   **落とし穴:** 再ビルドのたびにリクエストが増え、遅くなったり課金・レート制限の原因になる。**最初の取得は `initState()`、再取得はボタンなどで意図的に Future を差し替える**のが安全。

4. **非同期完了後の `setState`（実務で必ず踏む）**  
   `await` の後にウィジェットがすでに破棄されていると **`setState` や `context` 利用で例外や警告**が出る。画面を出し替える実装では、**`if (!context.mounted) return;`**（Flutter 3.7 以降、`BuildContext` の extension）で打ち切るのが定石。今日の再読み込みは `FutureBuilder` 任せなので最小だが、Medium の手動 `setState` パターンでは必須になる。

5. **よくある誤解: 例外を握りつぶす**  
   **落とし穴:** `try/catch` で何もせず `null` を返すと、UI が「永遠にローディング」や「空表示」になり原因が見えない。まずは **例外を上げる or エラー状態を明示**する。

6. **`FutureBuilder` の表示条件は `connectionState` も見ると安全**  
   **落とし穴:** データ再取得で `Future` を差し替えた直後、`snapshot.hasData` が前回のまま残る一瞬があり得る。実務では **`snapshot.connectionState == ConnectionState.waiting` のときはローディング**に寄せると、チラつきや古い成功表示の混入を防げる（今日のハンズオンではこの形にする）。

7. **比較（今日はこれ 1 つだけ）: UI 状態の持ち方「`FutureBuilder`」vs「手動 `setState`」**  
   - **`FutureBuilder`:** `Future` と `snapshot` に合わせて UI を書く。公式 Cookbook に近く、1〜2 画面の取得に向く。  
   - **手動 `setState`:** `loading` / `data` / `error` をフィールドで持ち明示的に更新。分岐が増える画面や、取得以外の操作と束ねたいときに向きやすい。  
   **今日の選択:** **三状態をフラットに扱いつつ Cookbook の流れに沿うため `FutureBuilder` + `connectionState` を採用**する。

8. **プラットフォームのネットワーク**  
   - **Android:** `INTERNET` パーミッション（[Cookbook](https://docs.flutter.dev/cookbook/networking/fetch-data)）。  
   - **macOS:** `com.apple.security.network.client` エンタイトルメント。  
   - **iOS:** 一般的な **HTTPS** なら追加設定はほぼ不要（HTTP 直は ATS で弾かれやすい）。  
   - **Web:** ブラウザの **CORS** に引っかかる API がある。今日の JSONPlaceholder は学習用に使いやすいが、社内 API では失敗することがある（対策は別日テーマ）。

---

## 4. ハンズオン（手順）

**目安時間（分）: 34**

作業ルートはすべて **`tutorial/` 配下** とする（このフォルダはリポジトリでは追跡しない想定）。

### ステップ 0: フォルダと .gitignore

1. 作業したいディレクトリ（例: TIL の日付フォルダの親やホーム）で、まだ無ければ `mkdir -p tutorial` を実行する。  
2. 教材と同じ場所などに、**`tutorial/` を除外する `.gitignore`** を置く（既に用意済みならスキップ）。

**確認方法:** `tutorial/` 内にダミーファイルを置いても `git status` に出てこない（`.gitignore` が効いている）。

---

### ステップ 1: プロジェクト作成と実行先の確認

```bash
cd tutorial
flutter create api_connect_demo
cd api_connect_demo
flutter devices
```

**確認方法:** `flutter devices` で、使うエミュレータ・実機・Chrome など **少なくとも 1 台**が表示される。  
**実行例:** `flutter run`（複数あるときは `flutter run -d <deviceId>`）。

---

### ステップ 2: 依存追加（公式どおり最小）

```bash
flutter pub add http
```

**確認方法:** `flutter pub get` がエラーなく終わる。`pubspec.yaml` の `name:` が **`api_connect_demo`** になっていること（後続の `import` と一致させる）。

---

### ステップ 3: Android / macOS のネットワーク設定（該当する環境だけ）

- **Android:** `android/app/src/main/AndroidManifest.xml` を開き、**`<application ...>` の直前**など、`<manifest>...</manifest>` 内の分かりやすい位置に次を入れる（兄弟要素として `application` と並ぶイメージ）。

```xml
<!-- Required to fetch data from the internet. -->
<uses-permission android:name="android.permission.INTERNET" />
```

- **macOS:** `macos/Runner/DebugProfile.entitlements` と `macos/Runner/Release.entitlements` の `<dict>` 内に:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

**確認方法:** 次のステップの `flutter run` で API に届く。届かないときは **ファイアウォール・プロキシ・社内 VPN** も疑う。

---

### ステップ 4: モデルと API 取得（2 ファイル）

#### `lib/todo_item.dart`（新規）

**JSONPlaceholder** の `/todos/1` の形に合わせる（実務ではキー欠落に備え `json['title'] as String?` などに広げる）。

```dart
class TodoItem {
  const TodoItem({
    required this.userId,
    required this.id,
    required this.title,
    required this.completed,
  });

  final int userId;
  final int id;
  final String title;
  final bool completed;

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      userId: json['userId'] as int,
      id: json['id'] as int,
      title: json['title'] as String,
      completed: json['completed'] as bool,
    );
  }
}
```

#### `lib/main.dart`（置き換え）

要点: **`http.get` → ステータス確認 → `jsonDecode`**。UI は **`connectionState` でローディング**を優先。

```dart
import 'dart:convert';

import 'package:api_connect_demo/todo_item.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Future<TodoItem> fetchTodo() async {
  final response = await http.get(
    Uri.parse('https://jsonplaceholder.typicode.com/todos/1'),
    headers: {'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    return TodoItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  } else {
    throw Exception('Failed to load todo (status: ${response.statusCode})');
  }
}

void main() => runApp(const ApiConnectApp());

class ApiConnectApp extends StatefulWidget {
  const ApiConnectApp({super.key});

  @override
  State<ApiConnectApp> createState() => _ApiConnectAppState();
}

class _ApiConnectAppState extends State<ApiConnectApp> {
  late Future<TodoItem> _futureTodo;

  @override
  void initState() {
    super.initState();
    _futureTodo = fetchTodo();
  }

  void _reload() {
    setState(() {
      _futureTodo = fetchTodo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Connect',
      home: Scaffold(
        appBar: AppBar(title: const Text('API Connect')),
        body: Center(
          child: FutureBuilder<TodoItem>(
            future: _futureTodo,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (snapshot.hasData) {
                final todo = snapshot.data!;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(todo.title, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('completed: ${todo.completed}'),
                  ],
                );
              }
              return const Text('No data');
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _reload,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
```

**確認方法:**

- 起動直後はインジケータ → Todo の `title` と `completed` が表示される。  
- FAB で再読み込みし、一瞬ローディングに戻ってから再表示される。  
- 機内モード等でオフラインにすると `Error:` 表示になる（`SocketException` などが `snapshot.error` に乗る）。

**実行:**

```bash
flutter run
# または
flutter run -d chrome
```

対象ファイル: **`lib/todo_item.dart`**、**`lib/main.dart`**

---

### ステップ 5: テスト 1 本（パースの単体テスト）

`test/todo_item_test.dart` を新規作成。`main.dart` は import しない（**分析対象をモデルに限定**）。

```dart
import 'dart:convert';

import 'package:api_connect_demo/todo_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TodoItem.fromJson parses JSONPlaceholder shape', () {
    final json = jsonDecode(
      '{"userId": 1, "id": 1, "title": "delectus aut autem", "completed": false}',
    ) as Map<String, dynamic>;

    final todo = TodoItem.fromJson(json);
    expect(todo.userId, 1);
    expect(todo.id, 1);
    expect(todo.title, 'delectus aut autem');
    expect(todo.completed, isFalse);
  });

  test('TodoItem.fromJson throws if key type is wrong', () {
    final json = <String, dynamic>{
      'userId': 1,
      'id': 1,
      'title': 123,
      'completed': false,
    };
    expect(() => TodoItem.fromJson(json), throwsA(isA<TypeError>()));
  });
}
```

**確認方法:**

```bash
flutter test test/todo_item_test.dart
```

がパスする（**通信なし**。API 仕様変更や誤キャストを早めに検知する）。

---

### 今日のゴール達成の宣言

**ここまでできれば今日のゴール達成** — API から 1 件取得し、`FutureBuilder` でローディング／成功／失敗を分け、再読み込みで状態更新→UI 反映までできている。モデルは別ファイルに分け、テストはそのファイルだけを狙って書けている状態です。

---

## 5. 追加課題（時間が余ったら）

### Easy（目安: 5〜10 分）

**課題:** 成功時に `id` と `userId` もテキストで表示する。

**回答例（`hasData` 分岐の `Column` に追加）:**

```dart
Text('userId: ${todo.userId}, id: ${todo.id}'),
```

---

### Medium

**課題:** 「手動 `setState`」版に書き換え、`loading` / `TodoItem?` / `Object?`（エラー）の 3 フィールドで同じ UI を出し分ける。`await` 後は **`if (!context.mounted) return;`** を入れる。`FutureBuilder` との違いをコメントに 1 行だけ残す。

**回答例（抜粋・`State` フィールドと `fetch`）:**

```dart
class _ApiConnectAppState extends State<ApiConnectApp> {
  bool _loading = true;
  TodoItem? _todo;
  Object? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final todo = await fetchTodo();
      if (!context.mounted) return;
      setState(() {
        _todo = todo;
        _loading = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // build 内: _loading / _error / _todo で分岐（FutureBuilder は使わない）
}
```

---

### Hard

**課題:** `http.Client` を引数で差し替えられる `fetchTodo(http.Client client)` にし、テストで `MockClient`（`package:http/testing.dart` の `MockClient`）を使って **200 と 404** を検証する。  
（発展: [Mock dependencies](https://docs.flutter.dev/cookbook/testing/unit/mocking)。）

**回答例（概念）:**

```dart
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// テスト側:
final client = MockClient((request) async {
  return http.Response('{}', 404);
});
```

---

## 6. 実務での使いどころ（具体例 3 つ）

**目安時間（分）: 4**

1. **起動直後の「お知らせ」1 件 GET** — バックエンドのメンテナンス通知や強制アップデートフラグを取得し、`FutureBuilder` 相当のパターンでダイアログやバナーを出す（今日の「1 件取得＋三状態」と同型）。  
2. **顧客・案件などマスタの詳細 1 件** — `/customers/{id}` を開いた画面で、ローディング中はスケルトン、422/403 はメッセージ表示（HTTP とドメインエラーの切り分けは次の段階で拡張）。  
3. **設定画面の「現在のプラン／利用状況」** — アカウント API を叩いて表示し、**Pull to refresh** で `Future` を差し替える（今日の FAB 再読み込みの延長）。

---

## 7. まとめ（今日の学び 3 行）

**目安時間（分）: 2**

- **API 呼び出しは `build()` ではなく `initState` やユーザー操作から始める**と、無駄な多重リクエストを防げる。  
- **`FutureBuilder` では `connectionState` を見る**と、再取得時のチラつきや古い成功表示の混入を抑えやすい。  
- **モデルを `lib` の別ファイルに分け、テストはそのファイルを import** すると、ウィジェット全体を引きずらず実務に近い検証ができる。

---

## 8. 明日の布石（次のテーマ候補を 2 つ）

**目安時間（分）: 3**

1. **リスト API + 無限スクロール or ページング**（`ListView` とロード状態の組み合わせ）。  
2. **`Riverpod` / `Provider` 等で「画面をまたいだ API 状態」**をどう置くか（今日の `State` 置き場の延長）。

---

## 参考リンク

- [Fetch data from the internet](https://docs.flutter.dev/cookbook/networking/fetch-data)  
- [JSON and serialization](https://docs.flutter.dev/data-and-backend/serialization/json)  
- [FutureBuilder](https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html)
