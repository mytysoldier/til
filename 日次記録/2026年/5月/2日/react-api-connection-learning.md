# React + TypeScript: API接続の入口（1日教材）

## 1. 今日のゴール（1〜2行）

**目安時間（分）: 2**

1日の終わりに、「外部APIを叩き、loading / error / success を state で表現して UI に載せる」最小画面が **TypeScript 付き**でローカルで動き、**API 境界の1関数について自動テストが通る**状態になること。

---

## 2. 事前知識チェック（3問）※回答も付ける

**目安時間（分）: 5**

### Q1. `fetch` は何を返す？

**A.** `Promise<Response>` を返す。本文（JSON）は `await response.json()` のように **別の非同期** で取り出す。`await fetch(...)` だけでは本文はまだ読めていない。

### Q2. React で「APIの結果を画面に出す」とき、なぜ `useState` が必要？

**A.** 取得完了まで時間がかかるため、**初回レンダー時点ではデータがない**。取得後に state を更新し、再レンダーで UI を差し替える。TypeScript では `useState<User | null>(null)` のように **ジェネリクスで「未定義をどう表すか」**を明示すると安全。

### Q3. CORS エラーは「React のバグ」？

**A.** いいえ。**ブラウザのセキュリティ**と**サーバー側の CORS 設定**の問題。フロントだけでは直せないことが多い（開発時は Vite の[プロキシ](https://vite.dev/config/server-options.html#server-proxy)や同一オリジンの BFF 経由で回避）。

**（補足）** `res.json()` を TypeScript で扱うときは **`Promise<unknown>` 扱い**が基本。**画面に載せる形**は `as` かスキーマ検証で決める（本教材は `as`、発展は Zod 等）。

---

## 3. 理論（重要ポイント3〜6個）

**目安時間（分）: 10**

### ポイント1: 非同期は「いまの状態」を state に落とす

API 呼び出し中は **loading**、失敗は **error**、成功は **data** のように、**いまユーザーに見せたい真実** を state に持つ。

- **よくある誤解**: 「`fetch` の戻り値をそのまま JSX に書けばいい」→ `Promise` は子要素にならない。`await` または `then` で値にしてから state へ。

### ポイント2: `fetch` の失敗は2種類ある（混同しやすい）

- **HTTP エラー（4xx/5xx）**: 原則 **`catch` には入らない**。`response.ok === false` なので **`assertResponseOk` 等で明示的に `throw`** するのが定石。  
- **ネットワーク断・DNS・タイムアウト等**: **`catch` に入る**（`AbortError` もこちら側に寄りがち）。  
- **`await response.json()`**: 本文が壊れた JSON なら **ここで例外**。「HTTP 200 なのにパースできない」は実務でもある。

### ポイント3: 副作用（初回ロードの取得）は `useEffect` に固定する

ページ表示時に1回叩くなら `useEffect(..., [])`。レンダー中に `fetch` を開始しない（レンダーは純粋に保つ）。

- **落とし穴**: 依存配列を付け忘れると **毎レンダーで再リクエスト** になる。

### ポイント4: 開発環境の Strict Mode で `useEffect` が2回走ることがある

`createRoot` + `StrictMode` では開発時、マウント→アンマウント→再マウントの検証で **effect が連続実行**されうる。**古い応答で state を上書きしない**（`cancelled` フラグや `AbortController`）は、ここでバグが顔を出す。

- **落とし穴**: 「開発だけ変なチラつき／2重リクエスト」は **本番挙動では起きない場合もある** が、クリーンアップ無しは将来の「画面遷移が早いルート」でも同種のバグになる。

### ポイント5: UI の責務は「state を表示」、HTTPの細部は境界に寄せる

URL・`response.ok`・共通ヘッダを **小さなモジュール（API 境界）** に集約すると、画面は分岐が読みやすく、**テストもしやすい**。

- **落とし穴**: JSX 内で `fetch` を直接呼ぶと、条件次第で **レンダーループや多重リクエスト** になりうる。

### ポイント6: `unknown` と「型の逃がし」

`catch` の **`e` は `unknown`**。メッセージ出しは `instanceof Error` で絞り込むか、小さな `toMessage(e: unknown)` に寄せる。**API レスポンスに `as SomeType`** は記述は楽だが **実行時は無検証**。チームが育ったら **スキーマ検証**へ寄せる。

- **落とし穴**: 「`.d.ts` があるから安全」ではない。**境界で形を保証**できて初めて TS の効きが実務レベルになる。

### （比較観点は1本）`fetch` を選ぶ理由（教材方針）

**axios** はインターセプタやタイムアウトの扱いが楽な場面があるが、本教材は **依存ゼロ増**で **標準 API の挙動**（`ok` と `catch` の違いなど）を体に染み込ませる。チームで axios が標準なら「境界レイヤだけラップ」し、画面側のパターンは同じでよい。

---

## 4. ハンズオン（手順）

**目安時間（分）: 36**

以下はすべて **`tutorial/` フォルダ配下** にプロジェクトを作る想定です。  
この日付フォルダ直下に **`tutorial/` を `.gitignore` で除外** しておくと、試作がリポジトリに混ざりません。

### 事前: `tutorial/` 用 `.gitignore`

**日付フォルダの直下**（この md と同じ階層）に `.gitignore` を作り、次を1行書く。

```
tutorial/
```

**確認方法**: `git status` で `tutorial/` 以下が未追跡として大量に出てこない。

---

### ステップ1: Vite + React + TypeScript プロジェクトを `tutorial/` に作る

**前提**: Node.js **18 以上**（ステップ7のテストは **22 以上**を推奨。理由はステップ7に記載）。

```bash
cd /Users/yoshiki/src/github.com/mytysoldier/til/日次記録/2026年/5月/2日
npm create vite@latest tutorial -- --template react-ts
cd tutorial
npm install
npm run dev
```

**よくある詰まりどころ**

- `npm create` でパッケージマネージャを聞かれたら **npm で統一**してよい。  
- 画面が真っ白なら **ブラウザの開発者ツール Console** を開く（import パスや型エラーが多い）。  
- **`src/main.tsx` はこの教材では変更不要**（`App` を読み込んでいればよい）。  
- エディタで `tsc` エラーが出たら **`npm run build`** を一度叩くと、Vite の型解決と差分が見えることがある。

**確認方法**: ターミナルに表示された URL を開き、Vite の初期画面が見える。

---

### ステップ2: 使う公開 API を決める（JSON がそのまま取れるもの）

例として **JSONPlaceholder** の users を使う（学習用。商用は各サービスの規約を確認）。

- 例: `https://jsonplaceholder.typicode.com/users/1`

**確認方法**: ブラウザで URL を開き、JSON が表示される。

---

### ステップ3: API 境界ファイルを作る（`response.ok` を1か所に集約）

**狙い**: 画面コンポーネントから **`if (!res.ok)` の重複をなくす**。ここを **自動テストで叩ける**ようにする。

ファイル: `tutorial/src/api/http.ts`（フォルダ `api` も新規）

```ts
export function assertResponseOk(response: Response): void {
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
}
```

**このテンプレでの import**: 相対パスは **`.ts` / `.tsx` を付けたまま**書く（例: `./api/http.ts`）。`tsconfig` の `moduleResolution: "bundler"` と `allowImportingTsExtensions` 向け。**別設定の話**: `moduleResolution: "NodeNext"` ではソースが `.ts` でも import に **`.js`**（emit 後のファイル名）を書く慣習があるが、**本教材・この Vite 初期設定では使わない**。**`dist/` 以下の `.js` はビルド成果物**で、手で増やすものではない。**`res.json()`** の `json` は **メソッド名**（JSON 本文を読む）で、**ソースの拡張子 `.js` とは無関係**。

**確認方法**: ファイルを保存し、パスが `tutorial/src/api/http.ts` になっている。

---

### ステップ4: `ApiUserCard.tsx` を新規作成（loading / error / success）

**方針**: `loading` / `error` / `user` を **別々の `useState`** にする。エラーは **`unknown`** で受け、表示だけ共通関数に寄せる。

ファイル: `tutorial/src/ApiUserCard.tsx`

```tsx
import { useEffect, useState } from "react";
import { assertResponseOk } from "./api/http.ts";

const API_URL = "https://jsonplaceholder.typicode.com/users/1";

/** 教材用: JSONPlaceholder の user 形（必要フィールドのみ） */
type PlaceholderUser = {
  id: number;
  name: string;
  username: string;
  email: string;
};

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

async function fetchUser(): Promise<PlaceholderUser> {
  const res = await fetch(API_URL);
  assertResponseOk(res);
  // 実行時検証は発展。ここでは教材都合で型アサーション。
  return res.json() as Promise<PlaceholderUser>;
}

export function ApiUserCard() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [user, setUser] = useState<PlaceholderUser | null>(null);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchUser();
        if (!cancelled) setUser(data);
      } catch (e: unknown) {
        if (!cancelled) setError(e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) return <p>読み込み中…</p>;
  if (error != null) return <p>エラー: {errorMessage(error)}</p>;
  if (!user) return <p>データがありません</p>;

  return (
    <section>
      <h2>{user.name}</h2>
      <p>@{user.username}</p>
      <p>{user.email}</p>
    </section>
  );
}
```

**確認方法**: `npm run build` かエディタで **型エラーが出ていない**こと。

---

### ステップ5: `App.tsx` で表示する

ファイル: `tutorial/src/App.tsx`（中身を差し替え）

```tsx
import "./App.css";
import { ApiUserCard } from "./ApiUserCard.tsx";

function App() {
  return (
    <>
      <h1>API 接続ミニ画面</h1>
      <ApiUserCard />
    </>
  );
}

export default App;
```

**確認方法**: ブラウザで **氏名・メール** が表示される。

---

### ステップ6: エラー UI を確認する（手動・回帰の最小）

次のいずれかで **意図的に失敗**させる。

- DevTools の **Network** で該当 URL を **Block request URL** する  
- 一時的に `API_URL` を存在しないパスへ変更する（例: `.../users/99999` は 404 になりやすい）

**確認方法**: 「エラー: HTTP …」またはネットワーク系のメッセージが出る。元に戻すと成功表示に戻る。

---

### ステップ7: 自動テストを1本（追加のアプリ用ライブラリ不要）

**境界関数**の契約を検証する。`Response` のモックは **完全ではない**が、**`ok` / `status`** だけ見る本関数には十分。

ファイル: `tutorial/src/api/http.test.ts`

```ts
import test from "node:test";
import assert from "node:assert/strict";
import { assertResponseOk } from "./http.ts";

test("404 のとき HTTP ステータス付きで throw する", () => {
  const res = { ok: false, status: 404 } as unknown as Response;
  assert.throws(
    () => assertResponseOk(res),
    (err: unknown) => err instanceof Error && err.message === "HTTP 404"
  );
});

test("200 のとき throw しない", () => {
  const res = { ok: true, status: 200 } as unknown as Response;
  assert.doesNotThrow(() => assertResponseOk(res));
});
```

**実行**（`tutorial` ディレクトリで）:

**Node.js 22 以上**（[Experimental TypeScript stripping](https://nodejs.org/api/typescript.html)）:

```bash
cd tutorial
node --experimental-strip-types --test src/api/http.test.ts
```

**Node.js 22 未満**の場合: 組み込みの **TypeScript テスト実行**（strip types）が使えない。**ステップ7の `node --test` は省略してよい**。その代わり、プロジェクトはすべて `.ts` / `.tsx` のままなので、次で **型検証**を行う（Vite テンプレートならビルドに型チェックが含まれることが多い）。

```bash
cd tutorial
npm run build
```

テストファイル `http.test.ts` 自体はリポジトリに残しておき、**Node を 22 以上に上げたあと**で次を実行すればよい。外部ツールで **TypeScript のまま**テストしたい場合は、チーム方針に合わせて **Vitest** 等を追加する（発展）。

**確認方法**: `tests 2 passed` のような出力になる。

---

### ステップ8: 最終チェックリスト（60秒）

1. 成功時: 名前が表示される  
2. ブロック／404: エラー表示になる（真っ白にならない）  
3. Node 22+ なら `node --experimental-strip-types --test` が緑。未満なら **ステップ7は省略**し `npm run build` が通ること

**ここまでできれば今日のゴール達成**。

---

## 5. 追加課題（時間が余ったら）

### Easy（目安 5〜10分）

**課題**: 「再取得」ボタンを追加する。

**回答コード例**（`load` を `useCallback` で切り出し、`useEffect` とボタンの両方から呼ぶ）

```tsx
import { useCallback, useEffect, useState } from "react";
import { assertResponseOk } from "./api/http.ts";

const API_URL = "https://jsonplaceholder.typicode.com/users/1";

type PlaceholderUser = {
  id: number;
  name: string;
  username: string;
  email: string;
};

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

async function fetchUser(): Promise<PlaceholderUser> {
  const res = await fetch(API_URL);
  assertResponseOk(res);
  return res.json() as Promise<PlaceholderUser>;
}

export function ApiUserCard() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const [user, setUser] = useState<PlaceholderUser | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchUser();
      setUser(data);
    } catch (e: unknown) {
      setError(e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <section>
      <p>
        <button type="button" onClick={() => void load()} disabled={loading}>
          再取得
        </button>
      </p>
      {loading && <p>読み込み中…</p>}
      {error != null && <p>エラー: {errorMessage(error)}</p>}
      {!loading && error == null && user && (
        <>
          <h2>{user.name}</h2>
          <p>@{user.username}</p>
          <p>{user.email}</p>
        </>
      )}
    </section>
  );
}
```

### Medium

**課題**: `fetchUser` を `src/api/user.ts` に移し、コンポーネントは「表示と state」に寄せる。

**回答コード例**

```ts
// tutorial/src/api/user.ts
import { assertResponseOk } from "./http.ts";

export type PlaceholderUser = {
  id: number;
  name: string;
  username: string;
  email: string;
};

export async function fetchUserById(id: number): Promise<PlaceholderUser> {
  const res = await fetch(
    `https://jsonplaceholder.typicode.com/users/${id}`
  );
  assertResponseOk(res);
  return res.json() as Promise<PlaceholderUser>;
}
```

```tsx
// ApiUserCard.tsx の effect 内
import { fetchUserById } from "./api/user.ts";
const data = await fetchUserById(1);
```

### Hard

**課題**: `AbortController` でアンマウント時に中断し、`AbortError` は UI に出さない。

**回答コード例**

```tsx
useEffect(() => {
  const ctrl = new AbortController();

  (async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(API_URL, { signal: ctrl.signal });
      assertResponseOk(res);
      const data = (await res.json()) as PlaceholderUser;
      setUser(data);
    } catch (e: unknown) {
      if (e instanceof DOMException && e.name === "AbortError") return;
      setError(e);
    } finally {
      setLoading(false);
    }
  })();

  return () => ctrl.abort();
}, []);
```

（環境によって `AbortError` の型が `DOMException` になりうるため、**チームのターゲット lib に合わせてガードを統一**するのが実務向き。）

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）: 4**

1. **社内向けダッシュボードの「自分のプロフィール」取得**: 画面マウント時に `GET /api/me`（または BFF 経由の同一オリジン）を1発叩き、**スピナー→権限エラー（401）→表示**の3状態をそのまま業務オペレータに見せる。型は **`ApiMeResponse`** を境界で `parse` してから UI へ。  
2. **契約・注文の「詳細ドロワー」**: 一覧は軽量、詳細を開いた瞬間だけ `GET /api/orders/:id`。**loading でドロワー内スケルトン**、**409/423 は業務メッセージ**にマッピングする。TS では **`Result` 型や union** で「業務エラー」と「通信エラーを分けたくなる。  
3. **リリース制御（feature flag）の初回取得**: アプリ起動時に設定 JSON を1回だけ読み、**失敗時は既知のデフォルトにフォールバック**。**`FeatureFlags` 型と default を同じモジュール**に置くと、`unknown` の迷子が減る。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）: 2**

- API は非同期なので、**結果は必ず state 経由**で UI に載せ、**HTTP 失敗とネットワーク失敗**を混同しない。  
- **`catch (e: unknown)` と `errorMessage`** のように、**安全にメッセージを出す型作法**を最初から入れる。  
- **`response.ok` の判定は API 境界に寄せる**と、画面が読みやすく **テストで守れる**（JSON の形は別途、実行時検証へ）。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）: 1**

1. **React + TypeScript: フォーム送信と API（POST）** — `method` / `body`、`z.safeParse`、二重送信防止。  
2. **React + TypeScript: 一覧＋検索** — 空配列の型、`AbortController` と `useEffect` の依存、`useDeferredValue` の入口。

---

## 参考（公式ドキュメント）

- React: [Synchronizing with Effects](https://react.dev/learn/synchronizing-with-effects)  
- React: [Strict Mode の開発時の挙動](https://react.dev/reference/react/StrictMode)  
- TypeScript: [React / Using the `unknown` type](https://www.typescriptlang.org/docs/handbook/2/narrowing.html#the-unknown-type)  
- React TypeScript Cheatsheet: [Hooks + TypeScript](https://react-typescript-cheatsheet.netlify.app/docs/basic/getting-started/hooks)  
- Vite: [Server proxy 設定](https://vite.dev/config/server-options.html#server-proxy)  
- MDN: [Using Fetch](https://developer.mozilla.org/docs/Web/API/Fetch_API/Using_Fetch)  
- Node.js: [Running TypeScript with `node`（strip types）](https://nodejs.org/api/typescript.html) · [テストランナー](https://nodejs.org/api/test.html)
