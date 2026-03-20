# React State 1日分学習教材（Architecture 版）

**テーマ**: useState / useReducer / derived state × Container–Presentational × ロジックは hooks  
**想定時間**: 60分（±10分）  
**対象**: 中級（フルスタックエンジニア向け）

---

## 0. この教材の立ち位置

状態の書き方だけでなく、**どこに何を置くか**を整理する。

| レイヤー | 役割 |
|----------|------|
| **Presentational（UI）** | props を受け取り、見た目とイベントを返すだけ。原則として state / reducer / 副作用を持たない。 |
| **Container（組み立て）** | カスタムフックを呼び、得た値とハンドラを Presentational に渡す。薄いラッパーに留める。 |
| **Custom hooks** | `useState` / `useReducer` / 派生値の計算・イベントに紐づくロジックをここに集約する。 |

**やることの要約**:

1. UI コンポーネントとロジックを分離する（見た目は Presentational、振る舞いは hooks）。
2. ロジックは **hooks に寄せる**（Container は「フックを呼んで props を繋ぐ」だけに近づける）。

---

## 1. 今日のゴール（目安: 2分）

- `useState` と `useReducer` の使い分けと、それぞれを **カスタムフックの中**でどう扱うかを説明できる。
- **derived state** を state にしない判断ができる（表示用の値は計算で足りる）。
- **Container / Presentational** の責務を切り分け、テストしやすい構造にできる。

---

## 2. 事前知識チェック（目安: 5分）

### Q1. 次の `doubled` は state にすべき？

```tsx
const [count, setCount] = useState(0);
const doubled = count * 2;
```

**A.** いいえ。`count` から一意に決まる **derived state** なので、レンダー時（または `useMemo` でコストが高いときだけ）に計算すればよい。

---

### Q2. 「ロジックを hooks に寄せる」とは、Container に何も書かないということ？

**A.** 違う。Container には **フックの呼び出しと props の受け渡し** が残る。ビジネスルールや状態遷移の詳細はフック側に閉じ、UI ファイルには JSX と props の型だけが目立つ状態を目指す。

---

### Q3. Presentational が `useState` を持ってはいけない？

**A.** 厳密な禁止ではない。例えば「開閉だけの UI ローカルなアコーディオン」は Presentational 近くに置いてもよい。ただし **ドメインに関わる状態**（一覧データ、フィルタ、フォームの意味のある束ね）は hooks か上位に寄せると再利用・テストが楽になる、という実務上の指針として覚える。

---

## 3. 理論（目安: 15分）

### 3.1 useState（フック内に閉じる）

- **関数型更新**: `setCount(prev => prev + 1)` で、連続更新や非同期に強い。
- **Container では**: `const logic = useCounter()` のように **名前で意図が伝わる API** を公開する（中で `useState`）。

### 3.2 useReducer（更新の型を action に集約）

- **向いている例**: 複数フィールド、複数の更新パターン、次の state が前の state に強く依存する場合。
- **フック内に置く**: `reducer` と `dispatch` をカスタムフックが返し、Presentational には `items` と `onAdd` のような **意味のある名前**だけ渡す（`dispatch` をそのままバラ撒かないのが理想に近い）。

### 3.3 Derived state

- **定義**: 他の state や props から計算で一意に決まる値。別の `useState` にしない。
- **hooks 内**: `const doubled = count * 2` のように、フックの戻り値に含めて Container → Presentational へ渡すと、「何が真実のソースか」が読みやすい。

### 3.4 Container / Presentational の最小パターン

```text
useXxx()           ← state / reducer / derived / イベント用の関数
    ↑ 呼ぶ
XxxContainer.tsx   ← 薄く、フックの結果を View に渡すだけ
    ↓ props
XxxView.tsx        ← 見た目のみ（可能なら stateless）
```

- **View** は `onClick` など **コールバックの型**だけ知り、中でどう reducer が動くかは知らない。
- **テスト**: View は props を与えて描画結果を検証。hooks は `@testing-library/react` の `renderHook`（または小さな Container 経由）で検証。

### 3.5 リフトアップとの関係

- 共有したい state は親の Container（または親が持つフック）へ。子 View は引き続き **表示とコールバック**だけ。

---

## 4. ハンズオン（目安: 33分）

**最終成果物**: `App` で Counter と Todo を表示。Counter は **useState + derived**、Todo は **useReducer**。それぞれ **View とフックに分離**した構造になる。

### 前提: プロジェクトセットアップ（5分）

1. 作業用ディレクトリで `npm create vite@latest . -- --template react-ts` などでプロジェクト作成。
2. `npm install` → `npm run dev` で起動確認。

---

### ステップ1: `useCounter` + `CounterView`（useState・derived）（8分）

**方針**: カウントと増減ロジックは `useCounter`。表示は `CounterView` に集約。

**`hooks/useCounter.ts`**

```ts
import { useCallback, useState } from 'react';

export function useCounter(initial = 0) {
  const [count, setCount] = useState(initial);

  const increment = useCallback(() => setCount((c) => c + 1), []);
  const decrement = useCallback(() => setCount((c) => c - 1), []);

  // derived state — 別の useState にしない
  const doubled = count * 2;

  return { count, doubled, increment, decrement };
}
```

**`components/CounterView.tsx`**

```tsx
export type CounterViewProps = {
  count: number;
  doubled: number;
  onIncrement: () => void;
  onDecrement: () => void;
};

export function CounterView({
  count,
  doubled,
  onIncrement,
  onDecrement,
}: CounterViewProps) {
  return (
    <div>
      <span data-testid="count">{count}</span>
      <span> × 2 = {doubled}</span>
      <button type="button" onClick={onIncrement}>
        +1
      </button>
      <button type="button" onClick={onDecrement}>
        -1
      </button>
    </div>
  );
}
```

**`components/CounterContainer.tsx`**

```tsx
import { useCounter } from '../hooks/useCounter';
import { CounterView } from './CounterView';

export function CounterContainer() {
  const { count, doubled, increment, decrement } = useCounter(0);
  return (
    <CounterView
      count={count}
      doubled={doubled}
      onIncrement={increment}
      onDecrement={decrement}
    />
  );
}
```

**確認**: クリックで増減し、`doubled` が常に `count` の 2 倍。

---

### ステップ2: `useTodoList`（useReducer）+ `TodoListView`（12分）

**方針**: reducer と入力用の一時 state（テキスト）はフック内。View はリスト表示とボタンだけ。

**`hooks/useTodoList.ts`**

```ts
import { useCallback, useReducer, useState } from 'react';

export type TodoItem = { id: number; text: string; done: boolean };
type TodoState = { items: TodoItem[] };

export type TodoAction =
  | { type: 'ADD'; text: string }
  | { type: 'TOGGLE'; id: number }
  | { type: 'DELETE'; id: number };

function todoReducer(state: TodoState, action: TodoAction): TodoState {
  switch (action.type) {
    case 'ADD':
      return {
        items: [
          ...state.items,
          { id: Date.now(), text: action.text, done: false },
        ],
      };
    case 'TOGGLE':
      return {
        items: state.items.map((i) =>
          i.id === action.id ? { ...i, done: !i.done } : i,
        ),
      };
    case 'DELETE':
      return { items: state.items.filter((i) => i.id !== action.id) };
    default: {
      const _exhaustive: never = action;
      return state;
    }
  }
}

export function useTodoList() {
  const [state, dispatch] = useReducer(todoReducer, { items: [] });
  const [draft, setDraft] = useState('');

  const add = useCallback(() => {
    const text = draft.trim();
    if (!text) return;
    dispatch({ type: 'ADD', text });
    setDraft('');
  }, [draft]);

  const toggle = useCallback((id: number) => {
    dispatch({ type: 'TOGGLE', id });
  }, []);

  const remove = useCallback((id: number) => {
    dispatch({ type: 'DELETE', id });
  }, []);

  return {
    items: state.items,
    draft,
    setDraft,
    add,
    toggle,
    remove,
  };
}
```

**`components/TodoListView.tsx`**

```tsx
import type { TodoItem } from '../hooks/useTodoList';

export type TodoListViewProps = {
  draft: string;
  onDraftChange: (value: string) => void;
  onAdd: () => void;
  items: TodoItem[];
  onToggle: (id: number) => void;
  onDelete: (id: number) => void;
};

export function TodoListView({
  draft,
  onDraftChange,
  onAdd,
  items,
  onToggle,
  onDelete,
}: TodoListViewProps) {
  return (
    <div>
      <input
        value={draft}
        onChange={(e) => onDraftChange(e.target.value)}
        aria-label="新しいTodo"
      />
      <button type="button" onClick={onAdd}>
        追加
      </button>
      <ul>
        {items.map((item) => (
          <li key={item.id}>
            <input
              type="checkbox"
              checked={item.done}
              onChange={() => onToggle(item.id)}
            />
            <span
              style={{
                textDecoration: item.done ? 'line-through' : 'none',
              }}
            >
              {item.text}
            </span>
            <button type="button" onClick={() => onDelete(item.id)}>
              削除
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

**`components/TodoListContainer.tsx`**

```tsx
import { useTodoList } from '../hooks/useTodoList';
import { TodoListView } from './TodoListView';

export function TodoListContainer() {
  const { items, draft, setDraft, add, toggle, remove } = useTodoList();
  return (
    <TodoListView
      draft={draft}
      onDraftChange={setDraft}
      onAdd={add}
      items={items}
      onToggle={toggle}
      onDelete={remove}
    />
  );
}
```

**確認**: 追加・トグル・削除が動く。`TodoListView` を Storybook 等に載せる場合は props を渡すだけでよい。

---

### ステップ3: `App` で統合・リフトアップ（8分）

親で `useCounter` を呼び、`CounterView` に props を渡す。**状態の真実のソースは親**、子 View は従来どおり「表示専用」。

**`App.tsx`**

```tsx
import { useCounter } from './hooks/useCounter';
import { CounterView } from './components/CounterView';
import { TodoListContainer } from './components/TodoListContainer';

export default function App() {
  const { count, doubled, increment, decrement } = useCounter(0);

  return (
    <div>
      <h2>カウンター（リフトアップ + View）</h2>
      <CounterView
        count={count}
        doubled={doubled}
        onIncrement={increment}
        onDecrement={decrement}
      />
      <h2>Todo（Container + View + useReducer）</h2>
      <TodoListContainer />
    </div>
  );
}
```

**確認**: Counter は親の state に従う。Todo は `TodoListContainer` 内で完結。

---

### ステップ4: テストの指針（任意・5分）

- **View**: `render(<CounterView count={1} ... />)` のように props だけで検証。
- **フック**: `renderHook(() => useCounter())` で increment 後の `count` を検証（Testing Library v14+）。

```tsx
// 例: CounterView
import { render, screen, fireEvent } from '@testing-library/react';
import { CounterView } from './CounterView';

test('shows doubled', () => {
  render(
    <CounterView
      count={3}
      doubled={6}
      onIncrement={() => {}}
      onDecrement={() => {}}
    />,
  );
  expect(screen.getByTestId('count')).toHaveTextContent('3');
  expect(screen.getByText(/× 2 = 6/)).toBeInTheDocument();
});
```

---

### 推奨フォルダ構成

```
src/
  hooks/
    useCounter.ts
    useTodoList.ts
  components/
    CounterView.tsx
    CounterContainer.tsx
    TodoListView.tsx
    TodoListContainer.tsx
  App.tsx
```

命名は `View` / `Container` の代わりに `Counter.tsx`（View）と `CounterScreen.tsx`（Container）など、チームの規約に合わせてよい。**責務の分離**が名前に反映されていれば目的は達成できる。

---

## 5. 追加課題（時間が余ったら）

### Easy: リセット

`useCounter` に `reset` を追加し、`CounterView` にボタンを足す。derived の `doubled` はそのまま追随する。

### Medium: フィルタは derived

`useTodoList` に `filter: 'all' | 'active' | 'done'` を `useState` で持ち、**表示用の配列**は `items` から `useMemo` で計算（または単純なら毎レンダー計算）。`filteredItems` を別 state にしない。

### Hard: dispatch を View に出さない

すでに `toggle` / `remove` のようにラップしている。さらに `ADD` を `addFromDraft` 一つにまとめ、View からは「追加」しか見えないようにする（API の厚みの設計練習）。

---

## 6. 実務での使いどころ

1. **フォーム**: `useReducer` で `values` と `errors` をまとめ、View には `field` ごとの `onChange` と `onSubmit` だけ渡す。
2. **一覧 + フィルタ**: フィルタ条件は state、表示行は derived。hooks の戻り値に `visibleRows` を含めると Container が読みやすい。
3. **レビューで見るポイント**: 「この JSX ファイルに `useReducer` が直書きで3つある」→ 分割・フック化を検討、など。

---

## 7. まとめ

| トピック | 置き場所の目安 |
|----------|----------------|
| useState | ドメインに関わるものはカスタムフック。UI だけの開閉などは View 近くでも可。 |
| useReducer | フック内の `reducer` と `dispatch`（またはラップした関数）に閉じる。 |
| derived state | state に重ねない。フックで計算し、View には結果だけ渡す。 |
| UI | Presentational は props in / イベント out。ロジックは hooks。 |
| Container | フックを呼び、View に渡す薄い層。 |

---

## 8. 明日の布石

1. **Context**: フックの戻り値を Provider で配ると、Container の階層をさらに薄くできる場面がある。
2. **useMemo / useCallback**: derived が重いとき・子を `memo` するときの境界の話につながる。
