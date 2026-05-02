# アプリ開発: API と UI をつなぐ（1日分教材）

この教材は [MDN: フェッチ API の使用](https://developer.mozilla.org/ja/docs/Web/API/Fetch_API/Using_Fetch) で推奨される **`response.ok` の確認・Promise/`async-await` と `response.json()`** に沿って書いています。外部ライブラリ（npm の追加インストール等）は使いません。

**全体の目安時間**: 読む＋手を動かす **約60分前後**（セクション直下の分数の合計を目安にしてください）。

---

## 1. 今日のゴール

**ブラウザ上の UI（ボタン1つ＋表示欄）から公開 API に `fetch` し、取得した JSON を画面に反映する。** 開発用の静的ファイルサーバーだけで動作確認でき、あわせて **API の応答が「今日のコードが期待する形」かを Node だけで自動確認**できる状態までを今日の最小リリースとする。

（目安時間: 2 分）

---

## 2. 事前知識チェック

次の各問について、頭の中で解答してから本文を読んでください。

1. **質問**: HTTP で「ページを開くとき」によく使われるメソッドはどれですか？  
   **回答**: **`GET`**。閲覧・取得が主目的のときは基本これです。

2. **質問**: ブラウザの DevTools で、ネットワーク上の応答コード **404** が出たとき、それはフロントの JavaScript が「クラッシュした」と同義ですか？  
   **回答**: **異なります。** サーバー側が「見つからない」を返しているだけです。`fetch()` はネットワーク上返ってくれば **`404 でも Promise は resolve することが多い`** ので、コード側では `response.ok` などで分岐します（後述）。

3. **質問**: JSON を「文字列」のまま `innerHTML` に入れるのと、`JSON.stringify` で整形して `textContent` に入れるのは、どちらが「確認用の表示」として安全寄りですか？  
   **回答**: **`textContent` + `JSON.stringify`** の方が、**HTMLとして解釈されにくく**確認用途として安全寄りです（`innerHTML` は XSS の入口になりやすい）。実務でも **ユーザー入力や外部データは `innerHTML` にそのまま流さない**のが前提です。

（目安時間: 5 分）

---

## 3. 理論（重要ポイント）

### 3-1. データフローは「イベント → 取得 → 整形 → 描画」の4つに分解する

- **要点**: ボタンクリックなど **ユーザー操作** を起点に **非同期で API** を呼び、返ってきたデータを **表示用** に整え、**DOM を更新**する。
- **よくある誤解/落とし穴**: 「`fetch` を書いたらすぐ画面に出る」と思うこと。`fetch` は非同期なので、**`await` するか `.then()` で「取得が終わったあと」に描画**します。

### 3-2. UI と API の境界は「この関数の行き先まで」で切る（今日の最小リリース）

- **要点**: 例えば **`loadPostAndRender()` の中だけが `fetch` と DOM** を触り、他は知らない、と決めると迷子になりにくいです。
- **よくある誤解/落とし穴**: HTML 内に URL や JSON の形が散らばると、あとで仕様変更に弱い。**URL と表示ロジックを 1か所に寄せる**のがコツです。

### 3-3. `fetch()` は「通信エラー」と「HTTP のエラーステータス」を混同しやすい

- **要点**: MDN の注意どおり、**`404` などでも `fetch` の Promise が拒否にならない**ことがあります。だから **`if (!response.ok) throw ...`** のように **HTTP エラーを明示的に扱う**のが定石です。
- **よくある誤解/落とし穴**: 「`try/catch` があれば全部拾える」→ **HTTP エラーは `response.ok` 側**で扱う必要があります。  
  さらに実務では、**オフライン・DNS 失敗・証明書エラー**などは `fetch` が **reject** することがあり、**HTTP エラーと通信例外は別物**として整理するとデバッグが速いです。

### 3-4. CORS と「file:// で開く」は詰まりどころ

- **要点**: 公開 API は **適切な CORS** が付いていればブラウザから呼べます。一方、**ファイルをダブルクリックだけで `file://` 実行**すると、環境によって挙動が変わり、学習中にハマりやすいです。**静的サーバー経由 (`http://localhost:...`)** が無難です。
- **よくある誤解/落とし穴**: 「API が壊れている」ではなく **`file://` やローカルの制限**のケースがあります。

### 3-5. 画面には「状態」が出ている（読み込み中・成功・失敗）

- **要点**: ユーザーから見えるのは結果だけではなく **`読み込み中` と `完了/失敗` のメッセージ**であり、これは UX の最低限になります。**どの状態のときボタンを押せるか**も設計になります。
- **よくある誤解/落とし穴**: 連打すると **複数リクエストが走り結果が競合**（遅い方が後から上書き）します。実務では **ボタン disable**、**リクエストID**、`AbortController` などで扱います（今日は追加課題へ）。

### 3-6. JSON の「型的な期待」とランタイムのギャップ

- **要点**: TypeScript が無くても、**最低限キーの存在チェック（`typeof` / `in`）** で「崩れたレスポンスをそのまま描画しない」ことはできます。`response.json()` は **本文が JSON として壊れていると throw** し得ます（HTTP 200 でも起き得る）。
- **よくある誤解/落とし穴**: 「サーバー契約があるから必ずこの形」と思い込むこと。**契約変更・プロキシ・部分的障害・キャッシュ**で形はズレます。今日は **`try/catch` で `response.json()` まで含める**ようにします。

### 【設計の選択肢と、今日の選択（1つ）】

**比較観点（今日はこれだけ）: `fetch` と `XMLHttpRequest`**

- **XMLHttpRequest**: 古くからある。コールバック中心で書き方が冗長になりがち。
- **`fetch`（今日の選択）**: **Promise ベースで読みやすく**、MDN でも現代的な書き方として紹介されています。**初中級が「読める・直せる」**ことを優先し `fetch` を使います。

（目安時間: 12 分）

---

## 4. ハンズオン（手順）

**想定環境**: macOS 想定。**Python 3** があれば標準ライブラリだけで静的サーバーが起動します（`python3 -m http.server`）。  
**補足**: **Node.js 18 以降**があると、教材フォルダの **`api_contract_check.mjs`**（依存なし）で **API の形の自動チェック**ができます。**Python が無く Node だけ**という場合でも、その Node で `python3` の代替として **単発の静的サーバー**として使う選択肢があります（末尾「サーバー代替」）。

**最初に決めること（迷子回避）**:

- 「親フォルダ」は **この教材の `.md` ファイルがあるフォルダ**と同じものを指します。ここへ **`tutorial/`** を作ります。
- **`index.html` と `app.js` は両方とも `tutorial/` に置く**こと（名前と階層を間違えると真っ白な画面になりがちです）。

### ステップ 0 — 作業フォルダを決める（目安: 3 分）

ターミナルで、この教材（`.md`）と **同じ階層**へ移動します。

**確認方法**: `pwd` の出力ディレクトリに、この教材ファイル名が **`ls`** で見えること。

### ステップ 1 — `tutorial/` を作り、Git で無視する（目安: 3 分）

```bash
mkdir -p tutorial
```

親フォルダ（`.md` がある階層）に **`.gitignore`** を置き、次だけを書きます。

**.gitignore（親フォルダ用・内容はこれだけでよい）**

```
tutorial/
```

**確認方法**: `cat .gitignore` で `tutorial/` が 1行あること。すでに同内容の `.gitignore` がある場合は上書き不要です。

### ステップ 2 — 最小 UI の `index.html` を作る（目安: 5 分）

`tutorial/index.html` を新規作成し、以下をそのまま保存します。

ファイル名: **`tutorial/index.html`**

```html
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="utf-8" />
  <title>API → UI 最小サンプル</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body { font-family: system-ui, sans-serif; margin: 1.5rem; line-height: 1.5; }
    #out { white-space: pre-wrap; border: 1px solid #ccc; padding: 0.75rem; min-height: 4rem; }
    button { padding: 0.5rem 0.75rem; }
    .muted { color: #666; font-size: 0.9rem; }
  </style>
</head>
<body>
  <h1>投稿を1件取得</h1>
  <p class="muted">JSONPlaceholder の公開 GET API を叩きます（ブラウザの fetch のみ）。</p>
  <button id="loadBtn" type="button">読み込む</button>
  <p id="status" class="muted"></p>
  <div id="out" aria-live="polite"></div>

  <script src="./app.js" defer></script>
</body>
</html>
```

**確認方法**:

- **`./app.js`** となっている（同一フォルダの `app.js` を読む）こと。
- まだ **`file://` で開かない**（静的サーバー起動後に `http://` で開く）。

### ステップ 3 — API 呼び出しと描画ロジック `app.js`（目安: 11 分）

`tutorial/app.js` を作成します。

ファイル名: **`tutorial/app.js`**

```javascript
const API_URL = "https://jsonplaceholder.typicode.com/posts/1";

function setStatus(message) {
  document.getElementById("status").textContent = message;
}

function assertPostLike(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("JSONのトップレベルがオブジェクトではありません");
  }
  if (typeof data.title !== "string" || typeof data.body !== "string") {
    throw new Error("期待した投稿データの形ではありません（title/body）");
  }
}

function renderPost(post) {
  const out = document.getElementById("out");
  // 今日は「一本道」を優先して JSON を整形表示（項目別 UI は追加課題へ）
  out.textContent = JSON.stringify(post, null, 2);
}

async function loadPostAndRender() {
  setStatus("読み込み中…");
  document.getElementById("out").textContent = "";

  const response = await fetch(API_URL, { method: "GET" });
  if (!response.ok) {
    throw new Error(`HTTPエラー: ${response.status}`);
  }

  const data = await response.json();
  assertPostLike(data);
  renderPost(data);
  setStatus("完了");
}

document.getElementById("loadBtn").addEventListener("click", async () => {
  try {
    await loadPostAndRender();
  } catch (e) {
    console.error(e);
    setStatus("失敗しました（詳細はコンソール）");
    document.getElementById("out").textContent = String(e.message ?? e);
  }
});
```

**確認方法**:

- **`API_URL`** が `tutorial/app.js` の先頭だけに書かれていること。
- `response.ok` を見ていること。
- `response.json()` と描画のあいだに **最低限の形チェック**（`assertPostLike`）があること。

### ステップ 4 — 静的サーバーで動かす（目安: 7 分）

**別ターミナルで既に同じポートを使っていないか**を確認します。`8765` が埋まっている場合は **`8766` など別ポート**に変えてください。

```bash
cd tutorial
python3 -m http.server 8765
```

ブラウザのアドレスバーに **`http://127.0.0.1:8765/`** と打ち込みます（**`file://` で `index.html` を開かない**）。

「読み込む」を押します。

**確認方法（期待される挙動）**:

- 画面の枠内に **`userId` / `id` / `title` / `body`** を含む JSON が表示される。
- DevTools の **Network** で `posts/1` が **ステータス 200**。
- 「完了」とステータス文が出る。

#### ハマったときの早見表（優先順）

| 症状 | まず疑うこと |
| --- | --- |
| Console に **Failed to fetch** | オフライン、URL  typo、ブラウザ拡張、企業プロキシ等（今日の題材は **HTTPS の公開API**なので、`file://` ではなく **`http://127.0.0.1:...` で開いているか**も確認） |
| 変更したのに挙動が変わらない | **強制リロード**（macOS Chrome 例: **Cmd + Shift + R**）または DevTools で **キャッシュ無効** |
| 真っ白 / ボタンが無反応 | `app.js` のパス、ファイル名、`id` の typo（`loadBtn` 等）、Console の **赤いエラー** |
| Address already in use | ポート変更、または別ターミナルのサーバーを止める |

**サーバー代替（Python が無いとき）**:

- **[MDN: ローカルテストサーバーのセットアップ](https://developer.mozilla.org/ja/docs/Learn/Common_questions/Tools_and_setup/set_up_a_local_testing_server)** の手順にある方法のいずれか。
- **Node.js 18+ だけがある場合**は、教材と同じフォルダにある **`serve_tutorial.mjs`**（依存なし）で `tutorial/` を配信できます。

```bash
# 教材（.md）と同じディレクトリで（tutorial/ と兄弟であること）
node serve_tutorial.mjs
```

**期待される出力**: `配信フォルダ: .../tutorial` と `http://127.0.0.1:8765/`。ポートが埋まっているときは `PORT=8766 node serve_tutorial.mjs`。

※ 学習用の **極小サーバー**です。実務のアプリでは専用ツールやフレームワークの開発サーバーを使いますが、今日の目的（**`http://` で開ける**こと）だけなら十分です。コピペが難しい場合は **Python の導入**か **VS Code の Live Server** 等でも構いません。

### ステップ 5 — テスト（目安: 5 分）

次の **2種類のうち、少なくとも1つは必ず**実施してください（実務ではどちらもよくセットで使います）。

#### A. 自動チェック（契約／形の確認）… **推奨（最低 1つ）**

教材と同じフォルダにある **`api_contract_check.mjs`** を実行します（**`tutorial/` の外**。Git で無視しないため、結果の再現がしやすいです）。

事前条件: **Node.js 18 以降**（ターミナルで `node -v` を確認）。

```bash
# 教材（.md）と同じディレクトリで
node api_contract_check.mjs
```

**期待される出力（1行）**:

```
OK: API の形が今日の前提と一致しています
```

**意味**: 今日の `assertPostLike` が期待する **最低限のキーと型**が、サンプル API 側で満たされていることを **スクリプトが検証**しました。API の URL を変えたら、このスクリプトの `API_URL` も合わせるのが実務の「契約テスト」に近い習慣です。

#### B. 手動スモーク（UI の最低限）

1. 「読み込む」後、**Network** で **`posts/1` が GET** され **200** である。
2. **飛行機モード**（オフライン）にして再実行し、**失敗表示**に切り替わる（または Console に通信エラーが出る）ことを確認する。  
   - 期待: **クラッシュではなく**、画面のステータスか表示欄に **失敗理由が読める**。

**確認方法**: **A の1行 OK** が出ていて、**B の1か2が確認できれば**、このステップ完了です。

### ここまでできれば今日のゴール達成

**API から JSON を取り、UI に反映する一連の流れ**と、**`fetch` + `response.ok` + `json()` + 最低限の形チェック`** の最小パターンが手元にあります。**テストとして `api_contract_check.mjs` の1本**があると、「明日 URL を変えたとき」の退行に気づきやすくなります。

（ハンズオン合計目安: 34 分）  
（セクション 1〜4 までの読み＋手を動かす合計の目安: **約53分**。セクション 6〜8 を含めると **約60分**。）

---

## 5. 追加課題（時間が余ったら）

### Easy（5〜10 分）

**課題**: ボタン連打で「読み込み中」が何度も走るのを防ぐ。**読み込み中はボタンを `disabled` にする。**

**回答コード例**（`loadPostAndRender` の前後に追記・改修するイメージ）:

```javascript
const btn = document.getElementById("loadBtn");

async function loadPostAndRender() {
  btn.disabled = true;
  try {
    setStatus("読み込み中…");
    document.getElementById("out").textContent = "";

    const response = await fetch(API_URL, { method: "GET" });
    if (!response.ok) throw new Error(`HTTPエラー: ${response.status}`);
    const data = await response.json();
    assertPostLike(data);
    renderPost(data);
    setStatus("完了");
  } finally {
    btn.disabled = false;
  }
}
```

### Medium（発展）

**課題**: `title` と `body` だけを **`<h2>` と `<p>`** に分けて表示する（`textContent` を使い、**`innerHTML` に生の JSON を流し込まない**）。

**回答コード例**:

```javascript
function renderPost(post) {
  const out = document.getElementById("out");
  out.replaceChildren(); // innerHTML に頼らず子要素だけ入れ替え

  const h2 = document.createElement("h2");
  h2.textContent = post.title ?? "";

  const p = document.createElement("p");
  p.textContent = post.body ?? "";

  out.appendChild(h2);
  out.appendChild(p);
}
```

### Hard（発展）

**課題**: **AbortController** で、通信中に再クリックしたら **前のリクエストを中断**する（[MDN: fetch の中止](https://developer.mozilla.org/ja/docs/Web/API/AbortController)）。

**回答コード例（骨子）**:

```javascript
let controller = null;

document.getElementById("loadBtn").addEventListener("click", async () => {
  controller?.abort();
  controller = new AbortController();

  try {
    setStatus("読み込み中…");
    const response = await fetch(API_URL, { signal: controller.signal });
    if (!response.ok) throw new Error(`HTTPエラー: ${response.status}`);
    const data = await response.json();
    assertPostLike(data);
    renderPost(data);
    setStatus("完了");
  } catch (e) {
    if (e.name === "AbortError") return;
    console.error(e);
    setStatus("失敗しました（詳細はコンソール）");
  }
});
```

---

## 6. 実務での使いどころ（具体例 3つ）

1. **EC の注文履歴**: 「期間フィルタを適用」→ `GET /orders?from=...&to=...` → 返却 JSON の `items[]` をテーブル行にマッピング（今日の **整形→描画** がそのまま増える）。失敗時は **トースト**や **インラインエラー**で状態を見せる。
2. **SaaS の「アカウント設定」画面の初期表示**: 画面表示時に `GET /me` でプロフィール取得 → フォームの初期値へ反映。**読み込み中スピナー**と **再試行**がセットで出るのが一般的です。
3. **社内オペレーション用ダッシュボード**: `GET /incidents/open` の件数と一覧を表示。オンメモリの最小実装でも **30秒おきに再取得（ポーリング）**するが、連打より **loading フラグで二重フェッチ抑制**することが多いです。

（目安時間: 4 分）

---

## 7. まとめ（今日の学び 3行）

- **ユーザー操作を起点に、非同期で取得 → 検証 → 整形 → DOM 更新** と分解すると、アプリ開発の「一本道」が見えやすい。  
- **HTTP エラー・通信エラー・JSON 破損**は別問題として扱うと、ログと UI の作り込みがブレません。  
- **`api_contract_check.mjs` のような極小の自動チェック**は、「URL と期待形が変わった瞬間」に気づける実務でも軽くて効く武器になります。

（目安時間: 2 分）

---

## 8. 明日の布石（次のテーマ候補を 2つ）

1. **フォーム入力 → POST/PUT で API に送り、結果を UI に反映する**（今日の読み取りに「書き込み」と **422 のフィールドエラー表示** を足す）。
2. **コンポーネント分割または薄い状態管理**（エラー／ローディング／データを **1つの状態機械**として表すと、競合や再入が見えやすい）。

（目安時間: 1 分）

---

## 参照リンク

- [MDN — フェッチ API の使用](https://developer.mozilla.org/ja/docs/Web/API/Fetch_API/Using_Fetch)  
- [MDN — response.ok](https://developer.mozilla.org/ja/docs/Web/API/Response/ok)
