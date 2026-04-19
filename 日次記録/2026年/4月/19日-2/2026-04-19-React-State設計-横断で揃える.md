# React / 設計：State設計を横断で揃える（1日分）

公式参照: [Managing State](https://react.dev/learn/managing-state)、[useReducer](https://react.dev/reference/react/useReducer)、[You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)（派生値はレンダー中に計算）

---

## 1. 今日のゴール（目安時間：2分）

**`useState` と `useReducer` の使い分けの芯を掴み、派生stateを整理した TypeScript + React のミニアプリと reducer の単体テスト（Vitest）まで一気通しで動かす。**

---

## 2. 事前知識チェック（目安時間：5分）

次の3問に答えられるか確認する（答え付き）。

| # | 質問 | 答え（要点） |
|---|------|----------------|
| 1 | `useState` の更新関数に「前の値」を渡す書き方は？ | `setCount(c => c + 1)` のように **関数型更新**。連続更新や非同期タイミングで古い値を踏みにくい。 |
| 2 | React が「再レンダー」を起こす主なきっかけは？ | **state の更新**（`setState` / `dispatch`）や **親からの props 変更** など。派生値だけを `let` で計算しても state ではないので再レンダーの原因にはならない。 |
| 3 | 「派生 state」とは何か、一言で？ | **別の state や props から計算できる値**。原則 **state に持たず、レンダー中に計算**する（必要なら `useMemo` で最適化は後回しでよい）。 |

---

## 3. 理論（目安時間：13分）

### 重要ポイント（今日の横断ルールはこれ1本）

**比較観点（1つに絞る）：「単一の真実の源泉（canonical state）」をどこに置くか**

アプリ内のどこかで数字や一覧を「正」として決め、それ以外は **計算（派生）** か **イベント経由の更新（dispatch/setState）** に寄せる。Go/Kotlin/Swift/Python でも同じ軸で整理できる（UI層の書き方は違っても、「正は1つ、あとは導出・操作」は共通）。

### ポイント2：`useState` は局所・単純、`useReducer` は「次の状態が規則で書ける」とき

- **useState**：フィールドが少なく、更新が単純なら最速で読める。
- **useReducer**：複数フィールドが一緒に動く、イベント名で意図が伝わる方がよい、**reducer を純関数として切り出してテストしたい**ときに強い（[Extracting State Logic into a Reducer](https://react.dev/learn/extracting-state-logic-into-a-reducer)）。

**よくある誤解**：「複雑になったらすぐ `useReducer`」。実際は **更新規則が増えて読みづらい**ときが目安。小さく始めて、分岐が増えたら移行でもよい。

### ポイント3：派生 state を `useState` + `useEffect` で同期しない（基本）

例：「カウントの2倍」を state に持ち、`useEffect` で `count` を追従させるのは **二重の真実** になりやすい。公式も「Adjusting some state when some props or state change」は Effect より **レンダー中の計算**を推奨する場面が多い（[You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)）。

**落とし穴**：「とりあえず全部 `useEffect`」→ 依存配列ミスで **古い値・無限ループ** の温床。

### ポイント4：`dispatch` 直後に `state` を読んでも「まだ古い」

`dispatch` は **次のレンダー向け**。ログや分岐で「更新後の値」を即座に使いたい場合は、reducer の戻り値やイベント引数側で扱う（[useReducer の注意](https://react.dev/reference/react/useReducer)）。

### ポイント5：reducer は純関数（副作用は置かない）

API 呼び出しや `console.log` への依存を増やすとテストと Strict Mode の二重呼び出しで苦しくなる。**副作用はイベントハンドラや Effect**へ。

### ポイント6：言語横断メモ（比較は「canonical + 導出」だけ）

| 技術 | 「正」の置き場のイメージ | 派生・更新のイメージ |
|------|-------------------------|----------------------|
| **React** | `useState` / `useReducer` の state | レンダー中の変数、`useMemo`（必要時） |
| **Go** | struct のフィールド | メソッドや関数が新しい値を返す（immutable に寄せることも多い） |
| **Kotlin** | `data class` のプロパティ | `copy`、または `StateFlow` の変換 |
| **Swift** | `struct` / `@Observable` のプロパティ | computed property、Reducer（TCA 等は別日） |
| **Python** | インスタンス属性・dict | `@property`、純関数で新 dict を返す |

### 実務で踏みやすい落とし穴（短く）

| 観点 | ありがちなこと | 一言の対処 |
|------|----------------|------------|
| **非同期** | `await` したあとに古い `state` を参照して `dispatch` する | サーバ結果で上書きする値は **レスポンスや reducer** に寄せる。必要なら `useEffect` で「IDが変わったら捨てる」など競合対策。 |
| **状態** | 同じ事実を props と state の両方に持つ | 親が持つなら **子は派生だけ**（[Replacing state with props](https://react.dev/learn/choosing-the-state-structure) の考え方）。 |
| **エラー** | reducer 内で `fetch` して失敗を握りつぶす | **ローディング／エラーは state に載せる**なら、更新は「結果が返ったあと」の `dispatch` に分ける。 |
| **型** | `action.type` の typo が実行時まで気づかない | **判別共用型（`CounterAction` など）**で `dispatch` の形をコンパイル時に寄せる（ハンズオンで触れる）。 |
| **テスト** | UI だけ見て reducer をテストしない | **純関数の入出力**だけ切り出せば、Vitest や Node でも十分価値がある。 |

---

## 4. ハンズオン（手順）（目安時間：30分）

作業はすべて **`tutorial/` 配下**に進める（このリポジトリでは `tutorial/` は `.gitignore` 済み）。**事前に教材リポジトリ内へファイルは作らない**前提で、自分の手で作る。

**どこで作業するか（最初に固定する）**

1. 教材の md ファイルと **同じディレクトリ**（例：`…/19日-2/`）を開く。
2. その直下で `mkdir tutorial && cd tutorial` まで進む。以降のパスは **`tutorial/react-state-mini/`** を根に読む。

**設計の選択肢と理由（1つ）**

- **選択**：カウントとステップは `useReducer` の1つの state にまとめ、**「表示用の product」は state に入れない**。
- **理由**：`count * step` は常に決まる **派生** のため。ここを state にすると、`count` / `step` との **二重管理** になりやすい（横断で「正」を増やさない）。

### ステップ1：`tutorial` を作り、Vite + React + TypeScript を用意する

1. 上記のとおり **`…/19日-2/tutorial/`** まで `cd` する（自分の環境のパスに合わせる）。
2. `npm create vite@latest react-state-mini -- --template react-ts`
3. `cd react-state-mini && npm install && npm run dev`

**対話プロンプトが出た場合**：プロジェクト名は `react-state-mini`、テンプレートは **React** と **TypeScript** を選ぶ。別の名前にした場合は、以降の `cd` だけその名前に読み替える。

**確認方法**：ターミナルに `Local: http://127.0.0.1:5173/` のような URL が出るのでブラウザで開き、Vite のデフォルト画面が見える。

**つまずいたとき**：`npm` のバージョンが古いと `--template` が効かないことがある。その場合は `npm create vite@latest` だけ実行し、対話で **React** と **TypeScript** を選ぶ。

---

### ステップ2：`src/counterReducer.ts` を新規作成する（純関数）

`tutorial/react-state-mini/src/counterReducer.ts`：

```typescript
export type CounterState = {
  count: number;
  step: number;
};

/** UI から dispatch する想定の action（判別共用型） */
export type CounterAction =
  | { type: 'increment' }
  | { type: 'decrement' }
  | { type: 'set_step'; value: number }
  | { type: 'reset' };

export const initialState: CounterState = { count: 0, step: 1 };

/** テストで不正な type を渡す場合もあるので、第2引数は広めに取る */
export function counterReducer(
  state: CounterState,
  action: CounterAction | { type: string }
): CounterState {
  switch (action.type) {
    case 'increment':
      return { ...state, count: state.count + state.step };
    case 'decrement':
      return { ...state, count: state.count - state.step };
    case 'set_step': {
      if (!('value' in action) || typeof action.value !== 'number') return state;
      return { ...state, step: Math.max(1, action.value) };
    }
    case 'reset':
      return { ...initialState };
    default:
      return state;
  }
}
```

**なぜ `reset` は `{ ...initialState }` か**：スプレッドで **新しいオブジェクト**を返し、`initialState` 定数を誤って共有変更しにくくするため。

**確認方法**：ファイル保存後、TypeScript のエラーが出ていないこと。

---

### ステップ3：`App.tsx` で `useReducer` を接続する

`src/App.tsx` を次の内容に**まるごと**置き換える（Vite のサンプルは上書きでよい）。

```tsx
import { useReducer } from 'react';
import { counterReducer, initialState } from './counterReducer';

export default function App() {
  const [state, dispatch] = useReducer(counterReducer, initialState);
  const product = state.count * state.step; // 派生：レンダー中に計算（canonical は count と step のみ）

  return (
    <div style={{ fontFamily: 'system-ui', padding: '1rem' }}>
      <p>count: {state.count}</p>
      <p>step: {state.step}</p>
      <p>count × step（派生の例）: {product}</p>
      <button type="button" onClick={() => dispatch({ type: 'decrement' })}>-</button>
      <button type="button" onClick={() => dispatch({ type: 'increment' })}>+</button>
      <button type="button" onClick={() => dispatch({ type: 'reset' })}>reset</button>
      <div>
        <label>
          step:{' '}
          <input
            type="number"
            min={1}
            value={state.step}
            onChange={(e) =>
              dispatch({ type: 'set_step', value: Number(e.target.value) || 1 })
            }
          />
        </label>
      </div>
    </div>
  );
}
```

**確認方法**：`+` / `-` で `count` が変わり、`step` を変えると増減幅と「派生の product」が一貫して変わる。`reset` で `0` と `1` に戻る。

---

### ステップ4：`useState` を1か所だけ足す（局所 UI 用）

同じ `App.tsx` を、**見た目用の一時フラグ**だけ `useState` で足した完成形に置き換える（横断ルール：「グローバルにしない局所」は `useState` のまま）。

```tsx
import { useReducer, useState } from 'react';
import { counterReducer, initialState } from './counterReducer';

export default function App() {
  const [state, dispatch] = useReducer(counterReducer, initialState);
  const product = state.count * state.step;
  const [showHint, setShowHint] = useState(false);

  return (
    <div style={{ fontFamily: 'system-ui', padding: '1rem' }}>
      <p>count: {state.count}</p>
      <p>step: {state.step}</p>
      <p>count × step（派生の例）: {product}</p>
      <button type="button" onClick={() => dispatch({ type: 'decrement' })}>-</button>
      <button type="button" onClick={() => dispatch({ type: 'increment' })}>+</button>
      <button type="button" onClick={() => dispatch({ type: 'reset' })}>reset</button>
      <div>
        <label>
          step:{' '}
          <input
            type="number"
            min={1}
            value={state.step}
            onChange={(e) =>
              dispatch({ type: 'set_step', value: Number(e.target.value) || 1 })
            }
          />
        </label>
      </div>
      <button type="button" onClick={() => setShowHint((v) => !v)}>
        ヒントを{showHint ? '隠す' : '表示'}
      </button>
      {showHint && <p>派生値 product は state に入れていません。</p>}
    </div>
  );
}
```

**確認方法**：ヒントの表示・非表示が、カウントの state と混ざらずに独立して動く。

---

### ステップ5：Vitest で reducer を単体テストする（`.ts` をそのまま）

TypeScript のテストを追加のトランスパイルなしで回すため、**開発用に Vitest を1つ入れる**（Vite 公式エコシステムに沿う）。

1. `react-state-mini` で次を実行する。

```bash
npm install -D vitest
```

2. プロジェクト直下の `vite.config.ts` を、次のように **Vitest の `test` 設定を足した形**に置き換える（`@vitejs/plugin-react` はそのまま）。

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'node',
  },
});
```

3. `package.json` の `"scripts"` に次を追加する（既存の `dev` / `build` は残す）。

```json
"test": "vitest run"
```

4. プロジェクト直下に `counterReducer.test.ts` を置く。

```typescript
import { describe, it, expect } from 'vitest';
import { counterReducer, initialState, type CounterState } from './src/counterReducer';

describe('counterReducer', () => {
  it('increment uses step', () => {
    const s = counterReducer({ count: 2, step: 3 }, { type: 'increment' });
    expect(s.count).toBe(5);
  });

  it('set_step clamps to minimum 1', () => {
    const s = counterReducer(initialState, { type: 'set_step', value: 0 });
    expect(s.step).toBe(1);
  });

  it('unknown action does not mutate state', () => {
    const before: CounterState = { count: 1, step: 2 };
    const after = counterReducer(before, { type: 'typo_increment' });
    expect(after).toEqual(before);
  });
});
```

**実行**（`react-state-mini` ディレクトリで）：

```bash
npm run test
```

**確認方法**：`Test Files` / `Tests` が **3 passed** のように表示される。失敗したら `vite.config.ts` の `import`（`vitest/config`）か、`counterReducer.test.ts` の import パスを確認する。

---

**ここまでできれば今日のゴール達成**（reducer ミニ構成・派生の整理・言語横断メモの軸・単体テスト3本まで）。

---

## 5. 追加課題（時間が余ったら）（目安時間：3分）

### Easy（目安：5〜10分）

**課題**：`{ type: 'set_count', value }` を追加し、0 未満にならないようにする。

**回答例**：`CounterAction` に `{ type: 'set_count'; value: number }` を足し、`switch` に次を追加する。

```typescript
    case 'set_count':
      return { ...state, count: Math.max(0, action.value) };
```

---

### Medium

**課題**：「Undo 1回」用に **直前の `{ count, step }` だけ** を state に持つ（履歴全体は持たない）。`dispatch({ type: 'undo' })` を実装する。

**回答例**（`past` に直前スナップショットを1つだけ持つ。`increment` / `decrement` / `set_step` の前に保存し、`reset` で捨てる）：

```typescript
export type CounterState = {
  count: number;
  step: number;
  past: { count: number; step: number } | null;
};

export type CounterAction =
  | { type: 'increment' }
  | { type: 'decrement' }
  | { type: 'set_step'; value: number }
  | { type: 'reset' }
  | { type: 'undo' };

export const initialState: CounterState = { count: 0, step: 1, past: null };

export function counterReducer(
  state: CounterState,
  action: CounterAction | { type: string }
): CounterState {
  switch (action.type) {
    case 'increment':
      return {
        ...state,
        past: { count: state.count, step: state.step },
        count: state.count + state.step,
      };
    case 'decrement':
      return {
        ...state,
        past: { count: state.count, step: state.step },
        count: state.count - state.step,
      };
    case 'set_step': {
      if (!('value' in action) || typeof action.value !== 'number') return state;
      return {
        ...state,
        past: { count: state.count, step: state.step },
        step: Math.max(1, action.value),
      };
    }
    case 'reset':
      return { ...initialState };
    case 'undo':
      if (!state.past) return state;
      return {
        ...state,
        count: state.past.count,
        step: state.past.step,
        past: null,
      };
    default:
      return state;
  }
}
```

`App.tsx` に `<button type="button" onClick={() => dispatch({ type: 'undo' })}>undo</button>` を追加する。

※ 実務では履歴を reducer の外（専用モジュールやコマンドパターン）に置くことも多い。**本課題は「スナップショット1つ」の感触用**。

---

### Hard

**課題**：`useReducer` の第3引数 `init` で `localStorage` から初期復元（SSR なし想定）。reducer は純関数のまま、**読み書きは `useEffect` またはイベント**に寄せる。

**回答例**（初期化関数のイメージのみ。`CounterState` はハンズオンの型に合わせる）：

```typescript
import type { CounterState } from './counterReducer';

function initFromStorage(arg: CounterState): CounterState {
  try {
    const raw = localStorage.getItem('counter');
    if (!raw) return arg;
    const parsed = JSON.parse(raw) as Partial<CounterState>;
    return { ...arg, ...parsed };
  } catch {
    return arg;
  }
}

// useReducer(counterReducer, initialState, initFromStorage)
```

永続化の `useEffect` は「同期のため」ではなく **外部ストアへの保存**が目的なら Effect でよい（公式の Effect の使い所と同じ考え方）。

**保存側の回答例**（`App.tsx`、state が変わるたびに書く。キー名は任意）：

```tsx
import { useEffect } from 'react';
// useReducer の直後あたりに追加
useEffect(() => {
  try {
    localStorage.setItem(
      'counter',
      JSON.stringify({ count: state.count, step: state.step })
    );
  } catch {
    /* 容量超過などは握りつぶしでもログでも可 */
  }
}, [state.count, state.step]);
```

`initialState` に `past` などを足している場合は、**永続に含めるか**は要件次第（本課題では `count` と `step` だけでよい）。

---

## 6. 実務での使いどころ（具体例3つ）（目安時間：3分）

1. **申込・注文フロー**：画面ステップ番号・入力した氏名・住所などを reducer の state にまとめ、**送料や税込合計**は「住所やカート明細から計算できる値」として派生させる。サーバの確定レスポンスが返るまでは **楽観的表示とサーバ正の二重管理**に注意し、確定後は `dispatch` で置き換える。  
2. **EC カート**：`lineItems`（商品ID・数量）を正とし、**行小計・クーポン適用後・税**はセレクタ（レンダー中の計算や `useMemo`）に寄せる。同じ金額を state と props の両方で持たない。  
3. **管理画面の検索条件**：フィルタ条件を reducer（または URL クエリと同期）に置き、**「結果件数」や「空メッセージを出すか」**は `rows.length === 0` のような派生で分岐する。API 失敗時は **error を state** に載せ、reducer 内では `fetch` しない。

---

## 7. まとめ（今日の学び3行）（目安時間：2分）

- **「正」は一つに寄せ、それ以外は派生かイベント経由**にすると、画面が増えても破綻しにくい。  
- **`useReducer` は規則・テスト可能性、`useState` は局所・単純**、という住み分けが実務では扱いやすい。  
- **派生を state + Effect で同期**しないことを最初の癖にすると、React のデータフローに乗りやすい。

---

## 8. 明日の布石（次のテーマ候補を2つ）（目安時間：2分）

1. **Context + `useReducer` で「局所 reducer をツリーに配る」**（どこまでをコンテキストにするかの境界）。  
2. **`useMemo` / `useCallback` を「計測してから」入れる**（先に派生整理ができていることが前提になる）。
