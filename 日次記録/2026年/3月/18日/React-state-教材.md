# React State 1日分学習教材

**テーマ**: useState / reducer / derived state  
**想定時間**: 60分（±10分）  
**対象**: 中級（フルスタックエンジニア向け）

---

## 1. 今日のゴール（目安: 2分）

- `useState` と `useReducer` の使い分け基準を理解し、状態の更新パターンに応じて適切に選べるようになる
- derived state（派生状態）の考え方を身につけ、冗長な state を減らしてバグを防げるようになる

---

## 2. 事前知識チェック（目安: 5分）

### Q1. 次のコードの実行結果は？

```tsx
function Counter() {
  const [count, setCount] = useState(0);
  const doubled = count * 2;
  return <button onClick={() => setCount(count + 1)}>{doubled}</button>;
}
```

**A.** ボタンをクリックするたびに `0, 2, 4, 6...` と表示される。`doubled` は state ではなく、`count` から計算される derived state なので、別の state は不要。

---

### Q2. `useState` と `useReducer` の主な違いは？

**A.** `useReducer` は「状態の型が複雑」「更新ロジックが複数パターンある」「次の状態が前の状態に依存する」場合に向いている。`useState` は単純な値の更新に適している。

---

### Q3. 親から渡された props をそのまま state にコピーして使うことの危険性は？

**A.** props が変わっても state は自動で更新されないため、親と子で値が食い違う（props と state の同期ずれ）。可能なら derived state として計算するか、完全に制御されたコンポーネントにする。

---

## 3. 理論（目安: 12分）

### 3.1 useState の基本と「関数型更新」

- **ポイント**: `setState(newValue)` の代わりに `setState(prev => next)` を使うと、非同期更新のタイミングに依存せず、常に最新の前状態から計算できる。
- **落とし穴**: イベントハンドラ内で複数回 `setCount(count + 1)` を呼んでも、同じ `count` を参照するため 1 回分しか増えない。関数型更新なら正しく増える。

```tsx
// ❌ バグ: クリック1回で1しか増えない
onClick={() => {
  setCount(count + 1);
  setCount(count + 1);
}}

// ✅ 正しい
onClick={() => {
  setCount(prev => prev + 1);
  setCount(prev => prev + 1);
}}
```

---

### 3.2 useReducer の役割と選び方

- **ポイント**: 状態の更新ロジックを `reducer` に集約できる。`(state, action) => newState` の形で、action の種類に応じて更新を分岐させる。
- **落とし穴**: 単純なトグルやカウントだけなら `useState` で十分。無理に `useReducer` にするとコードが重くなる。「複雑さ」の判断は、更新パターンの数と依存関係で行う。
- **落とし穴（実務）**: `action.type` の typo（`'ADD'` と `'add'` の混同）で意図しない action が無視される。`switch` の `default` で必ず `return state` を返すこと。そうしないと未知の action で `undefined` が返り、状態が消える。

**設計の選択肢**: フォーム（複数フィールド）やステップウィザードなど、状態の形がオブジェクトで、更新パターンが複数ある場合は `useReducer` を検討する。

---

### 3.3 Derived State（派生状態）

- **ポイント**: 他の state や props から計算できる値は、state に持たずにレンダー時に計算する。`useMemo` は計算コストが高い場合のみ使う。
- **落とし穴**: props を state にコピーして「初期値」として使うと、親の props が変わっても子の state は更新されない。`key` でコンポーネントを再マウントしてリセットするか、完全制御コンポーネントにする。

```tsx
// ❌ 危険: props が変わっても state は更新されない
const [name, setName] = useState(props.initialName);

// ✅ 制御コンポーネント（親が唯一の真実の源）
<input value={props.name} onChange={e => props.onChange(e.target.value)} />
```

---

### 3.4 状態の持ち場所（リフトアップ）

- **ポイント**: 複数コンポーネントで共有する状態は、共通の親に持たせる。子は props で受け取り、更新はコールバックで親に委譲する。
- **落とし穴**: 状態を必要以上に上に上げると、props のバケツリレーが発生する。その場合は Context や状態管理ライブラリを検討する。

---

### 3.5 初期化の遅延（lazy initialization）

- **ポイント**: `useState(expensiveComputation())` だと毎レンダーで計算される。`useState(() => expensiveComputation())` にすると初回マウント時のみ実行される。
- **落とし穴**: 初期値が props に依存する場合、props 変更時には再計算されない。その場合は `key` で再マウントするか、`useEffect` で同期する（ただし設計を見直す方がよい場合が多い）。

---

## 4. ハンズオン（目安: 33分）

**最終成果物**: App に Counter と TodoList を両方表示し、それぞれ独立して動作するアプリ。カウントの増減・リフトアップ、Todo の追加・完了・削除がすべて動く状態を目指す。

---

### 前提: プロジェクトセットアップ（5分）

**手順**:
1. `tutorial` フォルダに移動する（`cd tutorial`）
2. フォルダが空なので、その中で `npx create-react-app . --template typescript` を実行する（カレントディレクトリに TypeScript テンプレートで作成）
3. または `npm create vite@latest . -- --template react-ts` で Vite を使う（Vite の場合はテストは後述のセットアップが必要）
4. `npm start` で起動し、画面が表示されることを確認する

**確認方法**: ブラウザで React のロゴが表示され、コンソールエラーがないこと。

---

### ステップ1: カウンター（useState 基本）（4分）

**手順**:
- `tutorial/src` に `Counter.tsx` を作成
- `useState(0)` でカウントを管理し、+1 / -1 ボタンを配置
- 関数型更新 `setCount(prev => prev + 1)` を使う
- テスト用に `data-testid="count"` を span に付ける

**確認方法**: ボタンをクリックすると数値が増減する。複数回連打しても正しくカウントされる。

```tsx
// Counter.tsx（最小例）
import { useState } from 'react';

export default function Counter() {
  const [count, setCount] = useState<number>(0);
  return (
    <div>
      <span data-testid="count">{count}</span>
      <button onClick={() => setCount(prev => prev + 1)}>+1</button>
      <button onClick={() => setCount(prev => prev - 1)}>-1</button>
    </div>
  );
}
```

---

### ステップ2: 派生状態（doubled）（4分）

**手順**:
- 同じ `Counter` に「2倍の値」を表示する
- `count` から計算する変数 `doubled` を追加（state にはしない）

**確認方法**: カウントが 3 のとき「6」と表示される。state は `count` のみで、`doubled` はレンダー時に計算されている。

```tsx
const doubled = count * 2;
return (
  <div>
    <span data-testid="count">{count}</span>
    <span> × 2 = {doubled}</span>
    {/* ... */}
  </div>
);
```

---

### ステップ3: useReducer で Todo 風リスト（10分）

**手順**:
- `tutorial/src` に `TodoList.tsx` を作成
- `useReducer` で `{ items: [] }` を管理
- action: `ADD`, `TOGGLE`, `DELETE` を実装（`default` で `return state` を忘れずに）
- 入力欄と追加ボタン、各アイテムのチェック・削除ボタンを配置

**確認方法**: テキスト入力 → 追加でリストに表示。チェックで完了表示、削除で消える。

```tsx
// TodoList.tsx（最小例）
import { useReducer, useState } from 'react';

type TodoItem = { id: number; text: string; done: boolean };
type TodoState = { items: TodoItem[] };
type TodoAction =
  | { type: 'ADD'; text: string }
  | { type: 'TOGGLE'; id: number }
  | { type: 'DELETE'; id: number };

function reducer(state: TodoState, action: TodoAction): TodoState {
  switch (action.type) {
    case 'ADD':
      return { items: [...state.items, { id: Date.now(), text: action.text, done: false }] };
    case 'TOGGLE':
      return { items: state.items.map(i => i.id === action.id ? { ...i, done: !i.done } : i) };
    case 'DELETE':
      return { items: state.items.filter(i => i.id !== action.id) };
    default: {
      const _exhaustive: never = action;  // 新しい action 追加時に型エラーで検知
      return state;
    }
  }
}

export default function TodoList() {
  const [state, dispatch] = useReducer(reducer, { items: [] });
  const [input, setInput] = useState<string>('');

  const add = () => {
    if (input.trim()) dispatch({ type: 'ADD', text: input });
    setInput('');
  };

  return (
    <div>
      <input value={input} onChange={e => setInput(e.target.value)} />
      <button onClick={add}>追加</button>
      <ul>
        {state.items.map(item => (
          <li key={item.id}>
            <input type="checkbox" checked={item.done} onChange={() => dispatch({ type: 'TOGGLE', id: item.id })} />
            <span style={{ textDecoration: item.done ? 'line-through' : 'none' }}>{item.text}</span>
            <button onClick={() => dispatch({ type: 'DELETE', id: item.id })}>削除</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

---

### ステップ4: App に統合・リフトアップ（7分）

**手順**:
1. `Counter.tsx` を修正し、`count`, `onIncrement`, `onDecrement` を props で受け取る形にする（制御コンポーネント化）
2. `App.tsx` を編集し、`count` の state を `App` で管理する
3. `Counter` と `TodoList` を両方表示する

**確認方法**: 親と子の両方で同じ数値が表示され、子のボタンで親の表示も変わる。TodoList も独立して動作する。

```tsx
// Counter.tsx（制御コンポーネント版に修正）
interface CounterProps {
  count: number;
  onIncrement: () => void;
  onDecrement: () => void;
}

export default function Counter({ count, onIncrement, onDecrement }: CounterProps) {
  const doubled = count * 2;
  return (
    <div>
      <span data-testid="count">{count}</span>
      <span> × 2 = {doubled}</span>
      <button onClick={onIncrement}>+1</button>
      <button onClick={onDecrement}>-1</button>
    </div>
  );
}
```

```tsx
// App.tsx
import { useState } from 'react';
import Counter from './Counter';
import TodoList from './TodoList';

export default function App() {
  const [count, setCount] = useState<number>(0);
  return (
    <div>
      <h2>カウンター（リフトアップ）</h2>
      <Counter
        count={count}
        onIncrement={() => setCount(c => c + 1)}
        onDecrement={() => setCount(c => c - 1)}
      />
      <h2>Todo</h2>
      <TodoList />
    </div>
  );
}
```

---

### ステップ5: テスト（7分）

**手順**:
- create-react-app の場合は `@testing-library/react` が既に入っている。`tutorial/src/App.test.tsx` を作成する
- `data-testid="count"` を使って `toHaveTextContent` で検証する（`getByText('1')` は「1×2=2」など複数マッチしやすいため避ける）
- Vite の場合は `vitest` と `@testing-library/react` を別途インストールする必要がある

**確認方法**: `npm test` でテストが通る。

```tsx
// App.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import App from './App';

test('increments count on +1 click', () => {
  render(<App />);
  const countEl = screen.getByTestId('count');
  expect(countEl).toHaveTextContent('0');
  fireEvent.click(screen.getByText('+1'));
  expect(countEl).toHaveTextContent('1');
});
```

---

### フォルダ構成と .gitignore

```
日次記録/2026年/3月/18日/
├── React-state-教材.md
├── .gitignore          # tutorial/ を除外
└── tutorial/           # ハンズオン用（create-react-app . --template typescript で作成）
    └── src/
        ├── App.tsx
        ├── App.test.tsx
        ├── Counter.tsx
        └── TodoList.tsx
```

`.gitignore` に `tutorial/` を追加して、tutorial 配下をリポジトリから除外する。

---

## 5. 追加課題（時間が余ったら）

### Easy: リセットボタン

カウンターに「0に戻す」ボタンを追加する。

**回答**: `setCount(0)` を呼ぶボタンを追加するだけ。関数型更新は不要（固定値なので）。

---

### Medium: フィルタ付き Todo

TodoList に「すべて / 未完了のみ / 完了のみ」のフィルタを追加する。フィルタ状態は `useState`、表示リストは derived state で計算する。

**回答**: `const [filter, setFilter] = useState<'all' | 'active' | 'done'>('all')` を追加し、`const filtered = filter === 'all' ? state.items : state.items.filter(...)` で表示用リストを計算。state に `filteredItems` を持たない。

---

### Hard: フォームを useReducer で管理

名前・メール・メッセージの3フィールドフォームを `useReducer` で管理する。action は `CHANGE_FIELD` と `RESET` のみで、`payload: { field, value }` の形にする。

**回答**: `state` を `{ name: '', email: '', message: '' }` とし、`Action` を `{ type: 'CHANGE_FIELD'; payload: { field: 'name' | 'email' | 'message'; value: string } } | { type: 'RESET' }` のように型定義する。`CHANGE_FIELD` で `{ ...state, [action.payload.field]: action.payload.value }` を返す。`RESET` で初期状態に戻す。

---

## 6. 実務での使いどころ

1. **フォーム（複数フィールド）**: `useReducer` で `{ field1, field2, errors }` をまとめて管理する。例: `validate` で `action.payload` をチェックし、不正なら `{ ...state, errors: { field1: '必須です' } }` を返す。送信成功時に `RESET` で全フィールドを '' に戻す。
2. **ステップウィザード**: 現在のステップと各ステップの入力値を `useReducer` で管理し、`NEXT` / `PREV` / `UPDATE_STEP` などの action で遷移と更新を一元化する。`step === 3` のときだけ送信ボタンを有効にする、なども reducer 内で扱える。
3. **フィルタ・ソート付きリスト**: 元データは props または上位 state、フィルタ条件とソートは `useState`、表示リストは derived state で計算。`useMemo` はリストが 500 件以上など、実際に遅いと測定してから検討する。

---

## 7. まとめ

- **useState**: 単純な値の更新に適している。非同期更新を考慮するときは関数型更新を使う。
- **useReducer**: 複雑な状態・複数の更新パターンに適している。action の設計が重要。`default` で `return state` を忘れずに。
- **Derived state**: 計算で得られる値は state に持たず、レンダー時に計算する。props と state の二重管理は避ける。

---

## 8. 明日の布石

1. **Context API**: 状態の共有と props のバケツリレー解消
2. **useMemo / useCallback**: パフォーマンス最適化と「いつメモ化すべきか」の判断基準
