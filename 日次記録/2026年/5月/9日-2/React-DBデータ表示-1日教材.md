# React: DBデータ表示（1日教材）

## 1. 今日のゴール（目安時間：2分）

**目安時間（分）**：2

ローカルで動く React アプリから「API 経由（のつもり）で取得したリスト」を表示し、**再取得ボタンで最新表示に更新**できる。あわせて、**取得結果の解析**を関数に切り出し、**Node 標準テストで最低1つ**検証できる状態にする。

---

## 2. 事前知識チェック（目安時間：5分）

**目安時間（分）**：5

次の3問を読んでから答えを見る。

### Q1. `useEffect` は何のために使う？

- **回答**：React の描画結果（DOM）と**外部システム**（タイマー、通信、購読、ブラウザ API など）を同期するため。データ取得の「開始タイミング」をここに置くのが典型だが、**すべてを `useEffect` に押し込むのが正解**というわけではない（後述）。

### Q2. `fetch` はコンポーネントの render（関数本体）の中でそのまま呼んでよい？

- **回答**：原則 **よくない**。render は何度でも呼ばれうるため、通信が増殖したり、Strict Mode 開発時の再実行と相性が悪い。取得の開始は **`useEffect` やイベントハンドラ**など、意図したタイミングに寄せる。

### Q3. 「リストの state を更新する」とは、具体的に何をしている？

- **回答**：新しい配列（やオブジェクト）を `setState` に渡して、React に「次回 render はこのデータを前提にして」と伝えること。**同一配列を mutate（`push` など）しても再 render されない**ので、immutable 更新（コピーして作り直す）が基本。

---

## 3. 理論（目安時間：11分）

**目安時間（分）**：11

公式の入口として、[Synchronizing with Effects](https://react.dev/learn/synchronizing-with-effects) と [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) を併読すると迷いが減る。

### 重要ポイント1：サーバー由来データは「ソース・オブ・トゥルース」ではない（クライアント上）

- **要点**：DB の正はサーバー側。React の `useState` はあくまで**画面表示用のコピー**。「最新かどうか」は再取得・楽観的更新などで担保する。
- **よくある誤解**：`useState` に入れた瞬間が永久に正、と思い込む。**再取得しない限り古いまま**。

### 重要ポイント2：ローディング / エラー / データの3状態を分ける

- **要点**：取得中は UI をブロックしすぎない。**`loading`・`error`・`data`**（命名は任意）を state で持つと実装が単純になる。
- **落とし穴**：`data` だけ持って「`null` なら全部ローディング」にすると、**初回未取得**と**空配列**の区別が付きにくい。
- **実務メモ**：一覧が空なのが正常か、取得失敗かをログや Empty 状態 UI で区別できると運用が楽になる。

### 重要ポイント3：依存配列は「この Effect が参照する値」を正直に書く

- **要点**：`useEffect(() => { ... }, [deps])` は **deps に載せた値が変わったら再実行**される。再取得ボタンは **`refetch` フラグや `key`**、もしくは **Effect 外（イベント）で `fetch` を直接叩く**のが分かりやすい。
- **落とし穴**：`eslint-plugin-react-hooks` の警告を無視して deps を空固定にすると、**古い props/state を掴んだまま**（stale）動く事故が起きる。

### 重要ポイント4：非同期は「遅い・失敗する・重複する」を前提に設計する

- **要点**：`fetch` は**いつ完了するか不定**で、**ネットワークエラー・HTTP 4xx/5xx・壊れた JSON**がありうる。開発時は React Strict Mode で Effect が**一瞬二重に走る**こともある（クリーンアップと `AbortController` で打ち切り可能）。
- **落とし穴**：連打で **複数リクエストが並走**し、古い応答が遅れて上書きする（**競合**）。今日は入口のため詳細は追加課題に回すが、実務では `AbortController`・リクエスト ID・サーバー状態ライブラリで潰すことが多い。

### 重要ポイント5：リスト表示は「安定した key」を優先する

- **要点**：DB の主キー（`id`）を `key` に使う。順序変更・追加削除で React が要素を再利用できる。
- **落とし穴**：**配列 index を key**にすると、並び替えで入力状態がズレる等の不具合が出やすい（デモ用途を除き避ける）。

### 重要ポイント6：無闇に「再レンダー抑制」しない（今日の比較観点はこの1つ）

- **比較観点（1つに絞る）**：**`useMemo` / `useCallback` / `memo` で再レンダーを抑える** vs **まず普通に書いて必要になってから最適化する**。
- **今日の選び方**：初中級のデータ取得画面では、まず **hooks と state 分割だけ**で読みやすく書く。一覧が重い等の理由が出たら計測のうえで最適化する（ premature optimization を避ける）。
- **よくある誤解**：再レンダーは常に悪。**モデル更新の結果として起きる正常動作**がほとんど。

### 重要ポイント7：API 同期の形は「初期取得」と「ユーザー操作での再取得」に分けると説明が簡単

- **要点**：マウント時に1回、`useEffect` で取る。更新ボタンは **`fetch`＋解析を関数にまとめ、Effect と共有**する。
- **落とし穴**：同じ処理を Effect とボタンにコピペすると、**修正漏れ**が必ず出る。

### 重要ポイント8：型（TypeScript）は実務で「契約」になる

- **要点**：本番の React 案件では **レスポンス形を型で固定**し、さらに **`zod` 等で runtime 検証**する現場も多い。壊れた API に早期に気づける。
- **今日**：**TypeScript で `Item` 型と `parseItemsJson` の戻り値を宣言**する。実行時は **「配列かどうか」まで検証**し、要素の中身は **`as Item[]` で一度受ける**（深入りは追加課題）。**境界を1モジュールに置く**イメージを持つ。

---

## 4. ハンズオン（手順）（目安時間：38分）

**目安時間（分）**：38

以下はすべて **`tutorial/` フォルダ配下**に作業環境を置く想定。本番 UI 用の取得ライブラリ（axios 等）は使わない。**テスト実行のためだけ**に devDependency として **`tsx`**（TypeScript をそのまま実行する CLI のパッケージ名）を1つ入れる。

**この教材のコードはすべて TypeScript とする。** 手順に出てくるアプリ本体・テストは **`*.ts` / `*.tsx`** と **フェンスも `ts` / `tsx` のみ**とする。静的データの **`*.json`** や、設定の **`package.json`**、ランタイム名の **Node.js** はデータ・メタ情報として別カテゴリである（言語を JavaScript に戻す意味ではない）。

**前提**：ターミナルで `node -v` が **v18 以上**（`node --test` と `node --import tsx` を使うため）。未満なら Node を上げてから始める。

### ステップ0：作業場所の作成

1. 学習用の親フォルダで `tutorial` を作る（まだなら）。この教材では **`tutorial/react-db-viewer`** にプロジェクトを作る。

**確認方法**：`tutorial` ディレクトリが存在する。

---

### ステップ1：Vite + React + TypeScript プロジェクト作成

```bash
cd tutorial
npm create vite@latest react-db-viewer -- --template react-ts
cd react-db-viewer
npm install
npm install -D tsx
npm run dev
```

**迷いどころ**：

- コマンドが対話モードになる環境では、プロジェクト名とテンプレートを聞かれる。**`react-ts` テンプレート（React + TypeScript）**を選ぶ。
- **`npm install -D tsx` はスキップしない。** ステップ4の `npm run test` が `node --import tsx` を使うため、ここで入れておく（`package.json` の `devDependencies` に `tsx` が載る状態にする）。
- ターミナルに `Local:  http://localhost:5173/` のような URL が出る。**ポートが 5173 以外**なら、以降の URL も読み替える。

**確認方法**：表示された URL を開き、Vite のデフォルト画面が出る。

**つまずいたら**：

- **真っ白**：ブラウザの開発者ツール Console にエラーが出ていないか確認。
- **`npm` が無い**：[Node.js](https://nodejs.org/) をインストールしてからやり直す。

**補足（拡張子の方針）**：このハンズオンで手を動かすコードは **`src/**/*.ts` / `src/**/*.tsx` のみ**とする。テンプレートがルートに `eslint.config.js` を出す場合、**`eslint.config.mjs` にリネーム**してよい（中身はそのまま、ESLint が読み込める形式なら可）。

---

### ステップ2：`.gitignore` で `tutorial/` を除外（Git を使う場合）

学習用の生成物をコミットしたくない場合、**自分の Git リポジトリのルート**（`git rev-parse --show-toplevel` で分かる）に次を追記する。

`.gitignore`（追記例）：

```gitignore
tutorial/
```

**確認方法**：`git check-ignore -v tutorial/react-db-viewer` などで無視される（リポジトリとパスは環境に合わせる）。Git を使っていなければこのステップはスキップでよい。

---

### ステップ3：疑似 DB（静的 JSON）を置く

`react-db-viewer/public/items.json` を作成する。

`public/items.json`：

```json
[
  { "id": 1, "title": "Buy milk", "done": false },
  { "id": 2, "title": "Write README", "done": true }
]
```

**確認方法**：dev サーバー起動中に、ブラウザで `http://localhost:5173/items.json` を開き、JSON が表示される。

**つまずいたら**：

- **404**：ファイルパスが `public/items.json` か確認（`src` 配下に置いていないか）。

---

### ステップ4：解析関数とテスト（先に境界を固定する）

`src/itemsApi.ts` を新規作成する。

`src/itemsApi.ts`：

```ts
export type Item = {
  id: number;
  title: string;
  done: boolean;
};

/**
 * API の生テキスト（JSON）を Item 配列に変換する。実務ではここを「契約の入り口」にしがち。
 * 今日は「トップレベルが配列か」と TypeScript の宣言で形を固定する（要素の深い検証は zod 等が本命）。
 */
export function parseItemsJson(text: string): Item[] {
  const data: unknown = JSON.parse(text);
  if (!Array.isArray(data)) {
    throw new Error("Unexpected payload: expected JSON array");
  }
  return data as Item[];
}
```

`src/itemsApi.test.ts` を作成する。

`src/itemsApi.test.ts`：

```ts
import test from "node:test";
import assert from "node:assert/strict";
import { parseItemsJson } from "./itemsApi";

test("parseItemsJson: 正しい配列 JSON を受け付ける", () => {
  const items = parseItemsJson(`[{"id":1,"title":"a","done":false}]`);
  assert.equal(items.length, 1);
});

test("parseItemsJson: オブジェクトだけなら契約違反として失敗する", () => {
  assert.throws(
    () => parseItemsJson(`{"not":"array"}`),
    /Unexpected payload/,
  );
});

test("parseItemsJson: 壊れた JSON は SyntaxError（ここは自前で握り潰さない）", () => {
  assert.throws(() => parseItemsJson(`{broken`), SyntaxError);
});
```

`package.json` の `"scripts"` に次を追加する（カンマ位置に注意）。

```json
"test": "node --import tsx --test src/itemsApi.test.ts"
```

**必須（tsx）**：この `test` スクリプトは **`tsx` パッケージ**に依存する。**ステップ1**で `npm install -D tsx` をまだ実行していなければ、**いま実行する**（`devDependencies` に `"tsx"` が無いと、次の `npm run test` で `Cannot find package 'tsx'` になる）。

プロジェクトルート（`react-db-viewer/`）で実行：

```bash
npm run test
```

**確認方法**：3 テストがすべて成功する。

**つまずいたら**：

- **`Cannot find package 'tsx'`**：上記のとおり `npm install -D tsx` を実行してから再度 `npm run test`。

**落とし穴（非同期・状態と無関係だが実務で効く）**：`JSON.parse` が投げる `SyntaxError` と、自前の「形が違う」エラーは**別物**。UI ではどちらもユーザーに伝わる文面に整えるか、ログに分ける。

**補足**：`tsx` は **Node が `src/itemsApi.test.ts` を実行できるようにする devDependency** であり、ブラウザ向けの本番バンドルには乗らない。

---

### ステップ5：`App.tsx` で取得・一覧・再取得（解析は import で共有）

`src/App.tsx` を置き換える（Vite テンプレートの `main.tsx` は `App.tsx` を参照しているので、そのままでよい）。

`src/App.tsx`：

```tsx
import { useEffect, useState } from "react";
import type { Item } from "./itemsApi";
import { parseItemsJson } from "./itemsApi";

function isAbortError(e: unknown): boolean {
  return (
    (e instanceof DOMException && e.name === "AbortError") ||
    (e instanceof Error && e.name === "AbortError")
  );
}

async function loadItems(signal?: AbortSignal): Promise<Item[]> {
  const res = await fetch("/items.json", { signal });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`);
  }
  const text = await res.text();
  return parseItemsJson(text);
}

export default function App() {
  const [items, setItems] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    const ac = new AbortController();
    let cancelled = false;

    setLoading(true);
    setError(null);

    loadItems(ac.signal)
      .then((data) => {
        if (!cancelled) setItems(data);
      })
      .catch((e: unknown) => {
        if (isAbortError(e)) return;
        if (!cancelled) setError(e);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
      ac.abort();
    };
  }, []);

  async function handleRefresh() {
    setLoading(true);
    setError(null);
    try {
      setItems(await loadItems());
    } catch (e: unknown) {
      setError(e);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ fontFamily: "system-ui", padding: 16, maxWidth: 720 }}>
      <h1>Items</h1>
      <p>
        <button type="button" onClick={handleRefresh} disabled={loading}>
          再取得
        </button>
      </p>

      {loading ? <p>読み込み中…</p> : null}
      {error ? (
        <p role="alert">
          エラー:{" "}
          {error instanceof Error ? error.message : String(error)}
        </p>
      ) : null}

      {!loading && !error ? (
        items.length === 0 ? (
          <p>データはありません（空配列が返りました）。</p>
        ) : (
          <ul>
            {items.map((it) => (
              <li key={it.id}>
                <strong>{it.title}</strong>{" "}
                <span>{it.done ? "（完了）" : "（未完了）"}</span>
              </li>
            ))}
          </ul>
        )
      ) : null}
    </div>
  );
}
```

**設計の選択肢と、なぜ今日はこうしたか（1つ）**：

- **選択**：`loadItems` は **HTTP と解析を1つにまとめつつ**、`parseItemsJson` と **`Item` 型**は **別モジュール**に切り出してテスト可能にした。
- **理由**：実務でも「**通信は環境依存**・**形の検証は純粋**」に分けると、バグの切り分けがしやすい。肥大化したら `hooks/useItems.ts` へ寄せる。

**確認方法**：

- 初期表示で2件がリストされる。
- `public/items.json` を編集して保存し、**再取得**を押すと内容が更新される。
- `items.json` を一時的に `[]` にして再取得すると、「データはありません」と表示される（**空と失敗の差**が確認できる）。

**落とし穴（今日の範囲）**：再取得を**高速に連打**すると、リクエストが並走し**古い結果で上書き**される可能性がある。実務では Abort やリクエスト ID で「最新だけ採用」する（追加課題）。

---

### ゴール達成の宣言

**ここまでできれば今日のゴール達成**（DB 相当データを取得して一覧表示し、再取得で同期でき、**解析境界にテストが付いている**）。

---

## 5. 追加課題（時間が余ったら）

### Easy（目安：5〜10分）

**課題**：未完了件数を `items.filter` で計算し、見出し下に表示する。

**回答例**：`App` 関数内で `return` の**前**に置き、`return` の JSX 内に差し込む。

```tsx
  const openCount = items.filter((it) => !it.done).length;

  return (
    <div style={{ fontFamily: "system-ui", padding: 16, maxWidth: 720 }}>
      <h1>Items</h1>
      <p>未完了: {openCount} 件</p>
      {/* 以下、既存の button / リスト */}
```

---

### Medium（発展）

**課題**：再取得連打で **最新の応答だけ**を採用する。`handleRefresh` 内で `AbortController` を持ち、前回の `abort()` を呼んでから新しい `fetch` を開始する（または `requestId` を増やし、古い ID の `setState` を無視する）。

**回答例（Abort のイメージ）**：`isAbortError` は `App.tsx` と同じ実装を前提とする。

```ts
function isAbortError(e: unknown): boolean {
  return (
    (e instanceof DOMException && e.name === "AbortError") ||
    (e instanceof Error && e.name === "AbortError")
  );
}

// コンポーネント外はアンチパターンになりやすい。実装は useRef<AbortController | null> 推奨。
let refreshAbort: AbortController | null = null;

async function handleRefresh() {
  refreshAbort?.abort();
  const ac = new AbortController();
  refreshAbort = ac;
  setLoading(true);
  setError(null);
  try {
    setItems(await loadItems(ac.signal));
  } catch (e: unknown) {
    if (isAbortError(e)) return;
    setError(e);
  } finally {
    setLoading(false);
  }
}
```

（`useRef` 版に直すのが React 的。ここは発展課題として十分。）

---

### Hard（発展）

**課題**：同一データでも「最終取得時刻」を state に持ち、`memo` + `useCallback` で行コンポーネントの再レンダーを抑える。**Profiler で効果を確認**できると実務に近い。

**回答例（抜粋）**：

```tsx
import { memo, useCallback, useState } from "react";

type ItemRowProps = {
  title: string;
  done: boolean;
  onToggle: () => void;
};

const ItemRow = memo(function ItemRow({ title, done, onToggle }: ItemRowProps) {
  return (
    <li>
      <strong>{title}</strong>{" "}
      <button type="button" onClick={onToggle}>
        {done ? "完了" : "未完了"}
      </button>
    </li>
  );
});

// 親側: 行ごとの onToggle は useCallback + id 固定で組む（中級）
```

---

## 6. 実務での使いどころ（具体例3つ）（目安時間：2分）

**目安時間（分）**：2

1. **社内 CMS の記事一覧**：`/api/articles?status=draft` を取得し、編集者が「更新」ボタンで直近の差分（他者の編集）を取り込む。一覧は `id` を `key` にし、**空配列は「下書きゼロ」**と **通信失敗**を別表示にする。
2. **コールセンター向けチケットキュー**：`/api/tickets?assignee=me` を数十秒おきではなく、オペレーターの「最新化」ボタンで叩き、**保留件数**をヘッダに出す（ポーリングにするかは SLA とサーバー負荷で判断）。
3. **BtoB 受注の明細モーダル**：親画面の一覧は軽量サマリのみ、行クリックで `GET /orders/:id/lines` を取り、**明細だけ再取得**してモーダルに流し込む。壊れた JSON や型崩れは **解析境界で検知**しサポート調査に繋ぐ。

---

## 7. まとめ（今日の学び3行）（目安時間：1分）

**目安時間（分）**：1

- 画面に載せるデータは `useState` で保持し、**初回 Effect** と **ユーザー操作**の取得を分けつつ、処理は **`loadItems` のような1箇所**に寄せると破綻しにくい。
- **ローディング・エラー・空一覧**を分けると、オペレーション上の「正常なゼロ件」と「おかしい」を切り分けやすい。
- **解析（JSON→利用可能な配列）を純粋関数化**し、**型宣言とテスト**を付けると、後から **zod 等のスキーマ検証**を足す足場になる。

---

## 8. 明日の布石（次のテーマ候補2つ）（目安時間：1分）

**目安時間（分）**：1

1. **カスタムフック化**：`useItems()` を `hooks/useItems.ts` に抽出し、画面コンポーネントを薄くする（テストもしやすくする）。
2. **ミューテーション後の再同期**：`POST` 成功後に一覧を再取得する／楽観的更新で一瞬 UI を先に進める、の**どちらで整合を取るか**を1パターン選んで実装する。

---

## 参考（公式）

- Effects とデータ取得の考え方：[Synchronizing with Effects](https://react.dev/learn/synchronizing-with-effects)
- Effect にしない方がよいもの：[You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)
- リストと key：[Rendering Lists](https://react.dev/learn/rendering-lists)
