# React Native（UI比較）— 1日分の学習教材

公式ドキュメント: [React Native ドキュメント](https://reactnative.dev/docs/getting-started)（Getting Started / Components / `useState` は [React: useState](https://react.dev/reference/react/useState)）、モバイルUIは [`View`](https://reactnative.dev/docs/view) / [`Text`](https://reactnative.dev/docs/text) / [`Pressable`](https://reactnative.dev/docs/pressable) 等。新規プロジェクトの作り方は [Create a project (Expo)](https://docs.expo.dev/get-started/create-a-project/) または [React Native: Environment setup](https://reactnative.dev/docs/set-up-your-environment)。比較の軸は **1つ** のみ: **「状態が変わると、宣言的UIはどこから再描画が走るか（単方向: 状態 → UI）」**。

---

## 1. 今日のゴール（目安時間: 1分）

**`tutorial` 内（Expo `blank-typescript` 想定）の **`App.tsx`** を編集し、**画面でカウンタが動作し、** Flutter / SwiftUI /（Webの）React と「状態 → UI」の1軸で比較表を1枚完成させる。加えて、下記の受入テスト（TC-01）を1本パスする。**

---

## 2. 事前知識チェック（目安時間: 4分）※3問、回答付き

**Q1. JavaScript/TypeScript の関数コンポーネントで、再レンダー間で値を保持するための React の基本フックは？**  
**A.** `useState`（[useState - React](https://react.dev/reference/react/useState)）。返り値は `[現在の値, 更新関数]`。

**Q2. React（および React Native）の「宣言的UI」とは、ざっくり何を指す？**  
**A.** 画面の「今の見た目」を **状態（state）と props から計算で表現**し、**ユーザー操作 → 状態更新** を経て **UI が再描画** される、という考え方。命令的に DOM や各ネイティブ View を都度手で差し替えるスタイルの対比で語られることが多い。

**Q3. React Native でテキストを表示するとき、Web の `<div>` や `<p>` 相当の最小セットは？**  
**A.** レイアウト・コンテナは [`View`](https://reactnative.dev/docs/view)、文字は必ず [`Text`](https://reactnative.dev/docs/text) 内に置く。`View` 直下の生文字列は避け、**数値表示も `Text` 内**に揃えるのが安全（挙動と警告のブレを防げる）。

---

## 3. 理論（目安時間: 9分）

**重要ポイント（初学者がつまずきやすい順。実装で出たらこの順に疑う。）**

1. **状態（state）と再描画**  
   `useState` の更新関数が呼ばれると、そのコンポーネントを起点に**再描画**が走り、`return` 内の `View` / `Text` ツリーが**もう一度評価**される。  
   *よくある誤解:* 毎回「手で子 View を挿入している」わけではない。React が**差分**をネイティブへ届ける。  
   *落とし穴（ミュータブル）:* 配列に `push` しても参照が同じだと再描画が抜けがち。イミュータブル更新か、専用 API を使う。今日の数値1つは `setCount(c => c+1)` で十分。  
   *落とし穴（非同期）:* `onPress` 内で `async` + `await fetch` してから `setState` する場合、**失敗時の `catch`** と **二重タップ**（`disabled` や「処理中」フラグ）を忘れると、沈黙の失敗や不整合の原因になる。本日のカウンタは同期のまま。  
   *落とし穴（stale state）:* 前の `count` を閉包が掴み続けるとバグる。**直前の state に基づく更新**は `setCount((c) => c + 1)` の**関数型更新**（[React 公式](https://react.dev/reference/react/useState#updating-state-based-on-the-previous-state)）を優先。

2. **React Native では文字は `Text` 内**  
   *誤解:* ブラウザのように `View` の子に文字を書ける。→ **原則 `Text` へ**。

3. **タップは `Pressable` を第一候補**（[Pressable - React Native](https://reactnative.dev/docs/pressable)）  
   `TouchableOpacity` 等に比べ、プレス段階・`style` 関数（`pressed`）が扱いやすい。小さすぎるヒット領域は `hitSlop` や `padding` で実務上よく補う。  
   *落とし穴:* 親 `ScrollView` 内のボタンでジェスチャが奪われる、などの話は**追加課題**で触れる程度（今日は深追いしない）。

4. **比較の軸（1つ）: 状態 → 画面**  
   **React / RN** は `setCount` → 関数コンポーネント再実行 → `return`。**Flutter** は `setState` → `build`。**SwiftUI** は `@State` 更新 → `body` 再評価。APIは違うが**「UI は状態の関数」**は共通。

5. **（設計の選択肢と理由 — 1つ）なぜ 1 コンポーネント＋`useState` だけ？**  
   目的が「**画面内の一塊**」のときは局所 `useState` が最安。**画面やチームをまたぐ**安定した真実源が必要になったら `Context` / サーバー同期 / 外部ストアを検討。今日のスコープでは**過剰な抽象化を避ける**方が、後から移行の理由が説明しやすい。

6. **型・赤画面・今日のテスト方針（まとめ）**  
   *型:* 本教材は **`App.tsx`（`blank-typescript`）** 前提。`useState(0)` で数と推論。`useState<number | null>(null)` は **`null` 分岐**忘れに注意。`--template blank`（`.js`）のときは **JSDoc** 補助が現場ではよくある。  
   *エラー:* 構文/型はエディタ・`tsc`、実行時は **Metro** の真っ赤なオーバーレイ。まず**メッセージのファイル:行**を読み、**保存→リロード**で切り分け。Expo も**バンドルエラー**同様。  
   *本日のテスト:* 必須は下記 **TC-01（手動1本）**。**`npm test` が**雛形にあれば**緑**まで。**15分以上**かかるなら[Expo: Unit testing](https://docs.expo.dev/develop/unit-testing/)等は**次回**。CI の単体/E2Eゲートは**チーム方針**。

---

## 4. ハンズオン（手順）（目安時間: 40分）

作業は **`tutorial/` 配下** だけで行う。リポジトリ用に **`.gitignore` で `tutorial/` 除外** 済みなら、生成物を本流に混ぜない。

**本日の方針（初手で迷子を減らす）:** ビルド経路を **1本** に寄せる。**推奨: Expo + `blank-typescript` テンプレート**（[テンプレ一覧](https://docs.expo.dev/more/create-expo/) / [expo-template-blank-typescript](https://github.com/expo/expo/tree/main/templates/expo-template-blank-typescript)）— ナビ無しの **`App.tsx` 起点**・**TypeScript 有効**。[`blank`](https://github.com/expo/expo/tree/main/templates/expo-template-blank) は **JavaScript（`App.js`）** 向けなので、本教材のコード例（`.tsx`）と揃えるなら **`blank-typescript` 一択**。`default` テンプレは **Expo Router + `app/`** が多いので、**本教材では使わない**（慣れてからでよい）。

**前提:** Node **LTS**、仮想デバイスまたは実機、片方の OS ツール（iOS: Xcode、Android: Android Studio）が動くこと。Expo 実機なら [Expo Go](https://expo.dev/go) も選択肢。初回起動・依存取得は**10〜15分**かかることがあるので、**ステップ1〜2は時間の多く**を想定する。

**設計:** カウンタは `count` の **単一 `useState`**。増分のみ本編。減算・永続化は追加課題。

### ステップ0: フォルダの確認

1. 本教材と同階層に `tutorial` ディレクトリがあること。`.gitignore` に `tutorial/` があるとよい。  
2. ターミナルで **`cd` 先を必ず** `.../日付/tutorial` まで下げる（`create-expo-app` を**親ディレクトリで打って**フォルダが散らばる事故を防ぐ）。

**確認方法:** `pwd` で `.../tutorial` にいること。`ls` は空か、過去の試行の残骸がない程度でよい。

---

### ステップ1: プロジェクト作成（推奨コマンドを固定）

1. `tutorial` に移動した状態で、次を実行（アプリ名は `RNCounterLab` でも任意でもよい。本教材は **TypeScript 前提**）。  
   ```bash
   npx create-expo-app@latest RNCounterLab --template blank-typescript
   ```  
2. 完了したら、**必ず** プロジェクトに入る:  
   ```bash
   cd RNCounterLab
   ```  
3. JavaScript だけで始めたい場合は代替として **`--template blank`**（`App.js`）もあるが、**以降のコード例は `App.tsx` 向け**— そのときは本教材の `tsx` から**型行を取り除いて**同じUIを再現する。  
4. 公式 `default` テンプレにした人は、ルートが **`app/` ディレクトリ**のことが多い。紛失したら **本教材用に `blank-typescript` で上から作り直す**のが最速（今日のゴールに集中するため）。

**確認方法:** `RNCounterLab/package.json` があり、ルートに **`App.tsx`**（TypeScript テンプレの標準）が存在すること。`expo` が dependencies にあること。`tsconfig.json` があること。

**落とし穴:** `npx` の対話（パッケージマネージャ選択）で止まる場合は、**ターミナルで** `--yes` 相当が効くPMを選ぶ、または [create-expo](https://docs.expo.dev/more/create-expo/) の表記に従う。ファイアウォール等で**ネットワークが弾**かれないかも確認。

---

### ステップ2: 起動とデフォルト画面

1. プロジェクト内で:  
   ```bash
   npx expo start
   ```  
2. ターミナル表示の **`i`（iOS）** または **`a`（Android）** でエミュレータ、または **QR を Expo Go で読取**（実機・同一LAN）。初回は **Metro のビルドに数分**かかることがある。  
3. 歓迎画面相当が出れば OK。

**確認方法:** 赤画面が出た場合は、赤い本文の**エラーメッセージ**を**最初から1行**メモ。よくあるのは、Node/Watchman/ポート競合。  
**落とし穴:** 別プロジェクトの Metro が残っている（ポート **8081** 使用済み）— 他ターミナルの Metro を止める、または [Metro のポート案内](https://reactnative.dev/docs/metro) に従う。古い `node_modules` をコピーしてきた**混在**は避ける。必ず**この雛形の `npm install` 完走後**の状態で起動。

---

### ステップ3: カウンタUIの実装

**編集するファイル:** `blank-typescript` なら**ほぼ必ず** プロジェクト直下の **`App.tsx` のみ**（他ファイルをいじる必要はない）。  
- 下の例はそのまま貼り替え可。`--template blank`（**JS**）で作った場合は **`App.js`** 相当にし、**型注釈行があれば**削る。  
- **ファイルが見つからない**ときは、プロジェクトルートで `ls` と `App.*` の探索、または ステップ1 を **`--template blank-typescript`** でやり直し。

**最小コード例（`App.tsx` 全体。内容を root コンポーネントの `return` まで置き換えてよい）:**

```tsx
import { useState } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';

export default function App() {
  const [count, setCount] = useState(0);

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Count</Text>
      <Text style={styles.value} testID="counter-value" accessibilityLabel="count value">
        {count}
      </Text>
      <Pressable
        onPress={() => setCount((c) => c + 1)}
        style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
        accessibilityRole="button"
        accessibilityLabel="increment"
      >
        <Text style={styles.buttonText}>+1</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  label: { fontSize: 16, marginBottom: 8 },
  value: { fontSize: 32, fontWeight: '600', marginBottom: 16 },
  button: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: '#2563eb',
    borderRadius: 8,
  },
  buttonPressed: { opacity: 0.8 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
```

- **`setCount((c) => c + 1)`** は連打や将来の非同期併用でも **stale state を避けやすい**推奨形。  
- **`accessibilityLabel` / `accessibilityRole`:** スクリーンリーダー＆将来の E2E の土台。実務の「テスト可能なUI」の最小。  
- **`testID`:** 自動化テスト用フック（[View#testID](https://reactnative.dev/docs/view#testid)）。

**確認方法（期待される挙動）:**  
- `Count` / `0` / `+1` が見える。`+1` タップで 1 ずつ増える。  
- 押下中、ボタンに押下の視覚的フィードバック（上記 `opacity`）。

**落とし穴:** 貼り付け後、**import の綴り**と **`export default`** 消し。別名でエクスポートした場合は `index` 側の import 名が一致しているか。  
**落とし穴（型）:** `blank-typescript` で **strict な設定**のとき、スタイル名の typo はビルドで出る。メッセージの**ファイル名:行**を追う。

---

### ステップ3.5: 受入テスト1本（必須）＋ 自動テスト（あれば必須）

**（A）全員: 手動受入 — TC-01（本日の品質ゲート。これで「1本のテスト」とする）**

| ID | 前提 | 操作 | 期待 |
|----|------|------|------|
| **TC-01** | アプリ起動直後 | `+1` を **正確に 3 回** 押す | 表示の数が **3** である。ホットリロード後の初期値戻りは**別バグ**ではなく通常（永続化なし） |

学習メモ用に **1行** 残す: 「TC-01 手動: OK / 日時」— 自己確認の**記録**が実務のテスト管理の素（チケット・PR に貼る文化の足がかり）。

**（B）`package.json` に `"test": "..."` があるプロジェクト（React Native CLI 初期化などで付くことが多い）:**  
- 同じリポ内で次を実行し、**成功**するまで**赤いテスト1本**以上を緑にする:  
  ```bash
  npm test
  ```  
- **最小**の例: 既存 `__tests__` のスナップショットが古い場合は、**`App` のスモーク**（`import` 可能・レンダーで投げない）に差し替えて OK。`react-test-renderer` は React に付属しがちだが、**Jest プリセット（`jest-expo` 等）未設定**で落ちる場合は、**（A）のみで本日完走**にして、自動化は**追加課題 Hard** へ（無理に15分以上使わない）。

**（B）が無い（Expo `blank` / `blank-typescript` 初期状態に `npm test` スクリプトがないなど）:** **（A）の TC-01 のみ**で本編の「テスト完了」とする。CI に載せるには [Expo: Unit testing with Jest](https://docs.expo.dev/develop/unit-testing/) 参照。

**確認方法:** （A）を満たすこと。（B）可の環境は `npm test` の exit 0。  
**ここで「最低1本のテスト」＝ TC-01（手動）を必須。自動は環境に応じて必須。**

---

### ステップ4: 比較表（同じ1軸のみ）

| 枠 | 状態の置き方 | 更新のきっかけ | 「画面」再計算（イメージ） |
|----|----------------|----------------|------------------------------|
| **React / RN** | `useState(0)` | `setCount(...)` | コンポーネントの `return` |
| **Flutter** | `State` 内 | `setState` | `build` |
| **SwiftUI** | `@State` | 代入 | `body` |
| **React（Web）** | 同 | 同 | 同（先端は DOM、RN はネイティブView） |

**深掘り比較はしない。**

**確認方法:** 紙/メモに表を写し、1文で要約できる（例: 「いずれも状態の変更が、宣言されたツリーの再評価を起こす」）。

---

### ステップ5: 仕上げ

- 保存 → ホットリロードで **TC-01** が再パス。  
- 比較表のメモが完了。

**トラブル時の切り分け（短いチェックリスト）**  
- 赤画面 → **全文を読む** → 行番号へ。  
- 白画面 only → コンソール/Metro に **「Unable to resolve module」** がないか。  
- 数が増えない → `onPress` が**本当にこの `Pressable`**か、`onPress` の閉包が**別の state**を見ていないか。

**ここまでできれば今日のゴール達成。**

---

## 5. 追加課題（時間が余ったら）（目安時間: 本編外・任意。Easy 5〜10分 / Medium 15〜20分 / Hard 30分〜。取り組まない場合は0分）

### Easy（目安: 5〜10分）— 減少ボタン

- `-1` 用 `Pressable` を追加。  
- **期待:** 減算される。0 未満にしない、もあれば `Math.max` で。

**回答例（抜粋）:**

```tsx
<Pressable
  onPress={() => setCount((c) => Math.max(0, c - 1))}
  style={[styles.button, { marginTop: 8, backgroundColor: '#64748b' }]}
  accessibilityLabel="decrement"
>
  <Text style={styles.buttonText}>-1</Text>
</Pressable>
```

### Medium（目安: 15〜20分）— リセットと偶数

- `Reset` で `0`。  
- 偶数のときだけ「偶数です」を表示（`const isEven = count % 2 === 0`）。

**回答例（抜粋）:**

```tsx
const isEven = count % 2 === 0;
// ...
{isEven ? <Text>偶数です</Text> : null}
<Pressable onPress={() => setCount(0)} accessibilityLabel="reset">...</Pressable>
```

### Hard（目安: 30分以上）— Jest + レンダー or 記事読み＋1本

- Expo: [Unit testing with Jest and jest-expo](https://docs.expo.dev/develop/unit-testing/) に従い `jest` を通す。`@testing-library/react-native` は**チーム導入が多い**が依存追加。  
- あるいは **「非同期＋`setState`」** の**ミニ**例（`onPress` で `setTimeout` 100ms 後 `setCount`）を書き、**stale/二重**をコメントで説明。テストはスモーク1本に留める。  
- **回答例（最小幅。`jest` / `react-native` の preset が有効な前提。落ちる場合は上記ドキュメントでモック整備。）**

```js
// __tests__/App.smoke.test.js
import App from '../App';

it('default export は関数（コンポーネント）', () => {
  expect(typeof App).toBe('function');
});
```

**もう一段:** [@testing-library/react-native](https://callstack.github.io/react-native-testing-library/) を入れ、**`getByTestId('counter-value')` に `0` がある**とアサートする、が**実務でよく使う**。依存追加の手順は同ライブラリを参照。失敗し続けるなら**Hard＝Jest 設定完走**をゴールにし、**本日の本編は TC-01 で十分**。

---

## 6. 実務での使いどころ（目安時間: 3分）— 具体例3つ

1. **一時的な A/B やフィーチャーフラグ表示**  
   リモート設定やユーザー属性の結果を**ローカル state には持たず**、取得結果を1つの真実源に。ただ **UI 上の展開/折りたたみ**や「説明文を出すか」など**局所**は `useState`＋`Pressable` で足す、という**層**の分け方がよくある。深いグローバル化は**必要になってから**。

2. **問い合わせフォームの1画面**  
   各フィールド `value`＋`onChangeText`、送信ボタンは**送信中** `disabled`＋`ActivityIndicator`（[ActivityIndicator - RN](https://reactnative.dev/docs/activityindicator)）— **非同期＋二重送信防止**の最小パターン。バリデーションは**表示用メッセージ**を `Text` で宣言的に出す。  
3. **オンボーディングのステップ数**  
   ステップ `0..n-1` を `useState`、次へ/戻るは `setStep`。ステップ数が増え、**戻ると入力が消えては困る**なら state を**オブジェクト1つ**に寄せる or **フォーム専用の小さな Reducer**— **設計の分岐点**をコードレビューで指摘し合う。  

---

## 7. まとめ（目安時間: 2分）— 今日の学び3行

- **状態 → 再描画** の1軸で、React Native と Flutter / SwiftUI / React（Web）を**同じ図**で説明できる基礎ができた。  
- モバイルは **`Text` / `View` / `Pressable`**、**関数型 `setState`**、**a11y 属性＋`testID`** まで一気通貫で触れた。  
- **本日の合格ライン**は **TC-01**。自動化は雛形に合わせ、足りなければ**公式手順**で次回以降。  

---

## 8. 明日の布石（目安時間: 1分）— 次のテーマ候補2つ

1. **ナビゲーション** — [React Navigation](https://reactnavigation.org/) 等で画面を2枚にし、**各画面の局所 state** と**パラメータ**の境界を体験。  
2. **単体テストの導入** — `jest-expo` または社内のテンプレで **`@testing-library/react-native`** まで1本。TC-01 の手動を**E2E化**する話はさらにその先。  

---

*新しい Expo SDK では [create-a-project](https://docs.expo.dev/get-started/create-a-project/) の推奨コマンドが変わることがある。詰まったら**公式の現行**を優先し、本教材の方針は **`--template blank-typescript`（本編は `App.tsx`）** として残す。*
