# React Native（API + state）1日学習教材 — **Expo（Expo Go）版**

公式参考: [Networking](https://reactnative.dev/docs/network)、[Using Fetch (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch)、[Expo](https://docs.expo.dev/)、[create-expo-app](https://docs.expo.dev/more/create-expo-app/)

**方針:** ビルドは **Expo / React Native** の流れのまま扱いつつ、プロジェクトの作り方と起動は **Expo（管理対象ワークフロー + Expo Go）** に寄せる。`fetch` や `useState` の話は **RN と同一**（実行環境は Expo Go のランタイム）。

**「RN の開発って Expo がデファクト？」**  
**新規チーム・学習・多くの B2C アプリでは Expo が既定選択に近い。** 一方で、**既存ネイティブとの深い統合・ブラウンなプリ・要件で Expo 管理外のネイティブが主役**の案件では **RN CLI（bare）** もまだ普通に使う。**今日の教材は「Expo がメインストリームである」前提で、その入口に合わせている。**

---

**時間の前提（60 分運用）:** 表中の **合計は 58〜60 分**。**Node が入り、スマホに Expo Go（または PC のシミュレータ + Expo Go）**を用意できる状態を前提にする。**初めて Expo 環境を作る場合**はステップ 1 だけ **別枠 15〜30 分**と見積もり、詰まったら当日はステップ 2 以降に回す判断でよい（**CocoaPods / `run-ios` は不要**）。

| セクション           | 目安時間（分） |
| -------------------- | -------------- |
| 1. 今日のゴール      | 1              |
| 2. 事前知識チェック  | 3              |
| 3. 理論              | 10             |
| 4. ハンズオン        | 34             |
| 5. 追加課題（任意）  | 5〜15          |
| 6. 実務での使いどころ | 3              |
| 7. まとめ            | 2              |
| 8. 明日の布石        | 1              |

---

## 1. 今日のゴール

**目安時間（分）: 1**

公式サンプルと同様の `fetch` で JSON を取得し、`useState` で状態を分けて管理しながら **「ローディング → 一覧表示 → エラー表示」** までを **Expo Go 上で**一通り動かす。**`https://reactnative.dev/movies.json` に届かない環境向けに、同スキーマの `assets/movies.json` を同梱し、リモート失敗時に読み替える**（理論の項 7）。API 境界は **`unknown` を受けてから狭める**ユーティリティに寄せ、**テンプレ付属の Jest（jest-expo）でその変換を最低 1 本テスト**する（※本作業は `tutorial` フォルダ内でプロジェクトを作って進める）。アプリ側の UI コンポーネントは **`src/` 以下を `*.tsx` で揃える**（型とユーティリティは `*.ts` でよい）。

---

## 2. 事前知識チェック（3問）

**目安時間（分）: 3**

**Q1. React で `useState` を更新すると、コンポーネントはどうなるか。**  
**A1.** 状態が変わったとみなされ、（再レンダーの条件を満たす範囲で）再レンダーが走る。RN でも同様で、結果としてネイティブ側の View に変更が反映される。

**Q2. `fetch` は成功した HTTP レスポンスでも `catch` に入らないことがある。それはなぜか。**  
**A2.** `fetch` の Promise は「ネットワークレベルで失敗しなかった」ことまでしか保証しない。404 や 500 でも解決扱いになり得るため、**`response.ok` などで HTTP ステータスを別途確認する**。

**Q3. RN アプリから外部 API を叩くとき、ブラウザの CORS は通常どう関係するか。**  
**A3.** **ネイティブ実行では CORS の制約は基本的に絡まない**（CORS はブラウザのセキュリティモデル）。今回の「Web との違い」の比較軸はこれ 1 点に絞る。

---

## 3. 理論（重要ポイント）

**目安時間（分）: 10**

1. **RN でもデータ取得の基本形は Web と同じく `fetch` + `async/await`（または `then`）**  
   公式も `fetch` を前提に説明している。追加ライブラリは必須ではない。  
   **よくある誤解:** 「モバイルだから最初から Axios が必要」。小規模・学習ならまず標準で十分。

2. **状態は最低でも「loading / data / error」の 3 系統を分けて持つと、画面が説明しやすい**  
   ユーザーに見せる UI と state が 1 対 1 で対応しやすい。  
   **よくある落とし穴:** `data` だけ持って「空配列は未読込かエラーか」判別できず、表示がブレる。また **`loading === false` かつ `error === null` が「成功確定」を意味する**ようにそろえないと、`movies` だけ見て誤判定しやすい。

3. **副作用（API 呼び出し）は `useEffect` に置き、依存配列を意識する**  
   画面が伸びたら **`fetch` と `response.ok` / `json()` を UI から切り出した薄い API 関数**（今回の `fetchMovieList`）にまとめると、再読み込みやテストがしやすい。  
   **よくある落とし穴:** 依存配列を雑に `[]` 固定したまま props の ID だけ変えたい、など要件が増えたときに取り残される。

4. **`setState` は「DOM を直接いじる」代わりになる**  
   RN も React のモデルは同じ。**状態を更新 → 差分がネイティブ View に同期**される。  
   **よくある誤解:** 「ネイティブだから imperative に逐一触る」。基本は宣言的に state へ寄せる。

5. **HTTP エラー・JSON 破損・アンマウント後更新を混同しない**  
   - 404 は `fetch` 的には成功扱いになり得る → **`response.ok` で分岐**。  
   - `response.json()` は **不正 JSON だと reject** する（これは `catch` に入る）。  
   - レスポンスが遅い間に画面を離れると **遅れてきた `setState` が開発時警告や不整合の元**になる → **`useEffect` のクリーンアップでキャンセルフラグ**（今日の形）や `AbortController` でガード。  
   **よくある落とし穴:** `catch` が空、または `console.error` だけでユーザーに何も見せない。

6. **API の境界では `any` で飲むより `unknown` + 実行時の最低限検証**  
   型は「期待」を表すが、ネットワークの値は保証されない。**狭い関数（今回の `extractMovies`）に閉じ込める**と、画面コンポーネントが読みやすい。  
   **よくある落とし穴:** `as Movie[]` だけして一覧が真っ白／クラッシュ。最低限、配列かどうかとフィールド型を見る。

7. **教材で使う公式デモ URL は、環境によって一度も届かないことがある**  
   例として、**企業 LAN のプロキシ／ファイアウォール**、**DNS・VPN・キャプティブポータル**、**一時的な障害やレート制限**、**回線・地域による不安定さ**などがある。`fetch` が失敗しても学習を止めないため、本教材では **`https://reactnative.dev/movies.json` と同じスキーマの JSON を `assets/` に同梱し、失敗時に読み替える**運用を **標準手順**に含める（本番の「オフラインキャッシュ」とは別だが、**学習環境の再現性**には効く）。

### 設計の選択肢（今日の採用と理由）

- **選択肢 A:** `loading` / `error` / `movies` を **3 つの `useState`** で持つ  
- **選択肢 B:** `{ status, data, error }` を **1 つのオブジェクト state**（または `useReducer`）で持つ  

**今日の採用: A。** 初中級では「どの setter がどの表示に効いたか」が追いやすく、ハンズオンの完走優先に合う。B は状態遷移が増えたら再検討（追加課題へ）。

---

## 4. ハンズオン（手順）

**目安時間（分）: 34**（**内訳の目安:** ステップ 1 … 8〜15 分、2〜3 … 6 分、4〜5 … 10 分、6 … 4 分、7 … 6 分）

作業ルートは本フォルダの `tutorial` を使う（Git 管理外）。事前に本フォルダの `.gitignore` で `tutorial/` を除外済み。

### ステップ 1: Expo プロジェクト作成（`tutorial` 配下）

1. ターミナルで本日のフォルダへ移動し、`tutorial` に入る。  
2. **asdf で Node を使っている場合**は、**`npx` より先に** `tutorial`（またはホーム）で **`nodejs` の版が解決できる**状態にする。ここが空だと `No version is set for command npx` になる。

```bash
cd tutorial
asdf install nodejs 25.9.0    # バージョンは `asdf list all nodejs` / ホームの .tool-versions に合わせる
asdf set nodejs 25.9.0          # tutorial/.tool-versions に 1 行書く（0.16）
# または手で echo "nodejs 25.9.0" > .tool-versions
asdf reshim
node -v
which npx
```

（**日本語パス上**の `.tool-versions` で Node だけおかしいときは、**`~/.tool-versions` の `nodejs` を正しつつ**、試しに **`cd ~ && npx create-expo-app ...` でパスを ASCII のみにする**のも手。）

3. **Expo の TypeScript 空テンプレート**で作成する（プロジェクト名は例として `ApiMoviesApp`）。公式: [create-expo-app](https://docs.expo.dev/more/create-expo-app/)。

```bash
# いま tutorial にいる前提
npx create-expo-app@latest ApiMoviesApp --template blank-typescript
cd ApiMoviesApp
```

4. **Node の版だけ揃えればよい**（Expo Go 本教材では **Ruby / CocoaPods / `pod install` / `run-ios` は不要**）。プロジェクト作成**後**、必要なら **`ApiMoviesApp` で** Node を固定し直す。

```bash
# 例: プロジェクトルート ApiMoviesApp で
asdf set nodejs 25.9.0
# または printf "nodejs 25.9.0\n" > .tool-versions
asdf reshim
node -v
```

（asdf を使わないなら **Volta / fnm / 直インストールの Node** でよい。要件は **Expo が要求する Node 範囲**に入ること。）

5. **起動（Expo Go）:** 依存関係を入れたうえで開発サーバを立てる。

```bash
npx expo start
```

- **実機:** App Store / Google Play の **Expo Go** を入れ、ターミナルに出た QR を読み取る（同じ Wi‑Fi が確実）。  
- **iOS シミュレータ（macOS）:** 起動中の Expo CLI で **`i`** を押す（Xcode 前提。Expo Go がシミュレータに開く）。  
- **Android エミュレータ:** **`a`** を押す。

**今日の教材では `npx react-native run-ios` / `run-android` は使わない**（ネイティブプロジェクトを自分でビルドする前提ではない）。ネイティブをローカルビルドするのは **開発ビルド（expo-dev-client）** や `expo prebuild` 以降の話。

**確認方法（期待される出力/挙動）:** `tutorial/ApiMoviesApp` が生成され、ルートに **`App.tsx`** と **`package.json` に `expo`** がある。`npx expo start` 後、**Expo Go で Hello 程度の画面**が開ける（環境で詰まったら [Expo のセットアップ](https://docs.expo.dev/get-started/create-a-project/) を優先）。

---

### ステップ 2: ディレクトリ用意

次を新規作成する（フォルダがなければ作る）。

- `src/screens/MoviesScreen.tsx`（一覧 UI）  
- `src/utils/extractMovies.ts`（`unknown` → `Movie[]`）  
- `src/api/moviesApi.ts`（`fetch`・URL・HTTP 判定を 1 箇所に集約）

**確認方法:** 3 ファイルがエディタで開ける空またはプレースホルダ状態であること。

---

### ステップ 3: `extractMovies.ts`

```ts
// ファイル: src/utils/extractMovies.ts
export type Movie = {
  id: string;
  title: string;
  releaseYear: string;
};

function isMovie(value: unknown): value is Movie {
  if (value === null || typeof value !== 'object') {
    return false;
  }
  const o = value as Record<string, unknown>;
  return (
    typeof o.id === 'string' &&
    typeof o.title === 'string' &&
    typeof o.releaseYear === 'string'
  );
}

export function extractMovies(json: unknown): Movie[] {
  if (json === null || typeof json !== 'object') {
    throw new Error('invalid json');
  }
  const root = json as Record<string, unknown>;
  if (!Array.isArray(root.movies)) {
    throw new Error('movies is not an array');
  }
  return root.movies.filter(isMovie);
}
```

**確認方法:** 保存後、プロジェクトが TypeScript エラーなく解析できること。**不正な要素は `filter` で除外**され、クラッシュせずに「取りこぼし」に寄せられる点を押さえる。

---

### ステップ 4: `assets/movies.json` と `moviesApi.ts`（リモート優先・到達不能時は同梱 JSON）

教材の取得元は **`https://reactnative.dev/movies.json`**（React Native のネットワーク解説で使われる公式デモと同じデータ形）である。**ただしこの URL へ到達できない環境は実際にある**（理論の項 7）。到達できるかに依存せずハンズオンを完走できるよう、**同じスキーマの JSON をアプリにバンドルし、`fetch` が失敗したらそちらを使う**。

#### 4-1. `assets/movies.json` を置く

1. プロジェクトルートに **`assets/`** がなければ作成する（Expo の空テンプレートには通常ある）。  
2. その中に **`movies.json`** を置く。中身は **`{ "movies": [ { "id", "title", "releaseYear" } ... ] }` の形**であればよい。  
   - 手元のブラウザで `https://reactnative.dev/movies.json` が開けるなら、その内容を保存して使ってよい。  
   - 開けない場合は、チューター配布や手元のコピーを使い、**`extractMovies` が期待するフィールドだけ**一致させる。

公式デモと同形の一例（必要ならこのまま保存してよい）:

```json
{
  "title": "The Basics - Networking",
  "description": "Your app fetched this from a remote endpoint!",
  "movies": [
    {"id": "1", "title": "Star Wars", "releaseYear": "1977"},
    {"id": "2", "title": "Back to the Future", "releaseYear": "1985"},
    {"id": "3", "title": "The Matrix", "releaseYear": "1999"}
  ]
}
```

#### 4-2. `moviesApi.ts`（リモート → 失敗時は `assets`）

`src/api/moviesApi.ts` に次を書く。`import ... movies.json` が型エラーになる場合は **`tsconfig.json` の `compilerOptions` に `resolveJsonModule: true`** を足す（多くの Expo TypeScript テンプレートでは **既に有効**）。

```ts
// ファイル: src/api/moviesApi.ts
import {extractMovies} from '../utils/extractMovies';
import localMovies from '../../assets/movies.json';

const MOVIES_URL = 'https://reactnative.dev/movies.json';

/**
 * 公式デモと同じ URL を優先する。
 * 端末・回線・プロキシ等で reactnative.dev に届かない場合は、同梱の assets/movies.json を使う。
 */
export async function fetchMovieList() {
  try {
    const response = await fetch(MOVIES_URL);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const json: unknown = await response.json();
    return extractMovies(json);
  } catch {
    if (__DEV__) {
      console.warn(
        '[fetchMovieList] remote failed, using assets/movies.json (same schema as official demo)',
      );
    }
    return extractMovies(localMovies as unknown);
  }
}
```

**確認方法:** `fetchMovieList` を import できること。可能なら **機内モードやプロキシあり環境でも**一覧が **`assets/movies.json` 由来で表示される**ことを一度見る（開発時は上記 `console.warn` が出る）。

---

### ステップ 5: `MoviesScreen.tsx`（`useEffect` + キャンセルフラグ + `FlatList`）

1. マウント時にだけ取得する。クリーンアップで **`cancelled` を true** にし、**遅延レスポンスで `setState` しない**。  
2. 表示分岐は **`loading` → `error` → 一覧**の順。

```tsx
// ファイル: src/screens/MoviesScreen.tsx
import React, {useEffect, useState} from 'react';
import {
  ActivityIndicator,
  FlatList,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {fetchMovieList} from '../api/moviesApi';
import type {Movie} from '../utils/extractMovies';

export default function MoviesScreen() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [movies, setMovies] = useState<Movie[]>([]);

  useEffect(() => {
    let cancelled = false;

    const run = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchMovieList();
        if (!cancelled) {
          setMovies(data);
        }
      } catch (e) {
        const message = e instanceof Error ? e.message : 'Unknown error';
        if (!cancelled) {
          setError(message);
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void run();

    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator accessibilityLabel="読み込み中" />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorText}>エラー: {error}</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={movies}
        keyExtractor={item => item.id}
        renderItem={({item}) => (
          <View style={styles.row}>
            <Text style={styles.title}>{item.title}</Text>
            <Text style={styles.meta}>{item.releaseYear}</Text>
          </View>
        )}
        ListEmptyComponent={<Text>データがありません</Text>}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1, paddingTop: 48},
  centered: {flex: 1, alignItems: 'center', justifyContent: 'center'},
  row: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#ccc',
  },
  title: {fontSize: 16, fontWeight: '600'},
  meta: {fontSize: 12, color: '#666', marginTop: 4},
  errorText: {color: 'crimson'},
});
```

**確認方法:** Expo Go で **スピナー → タイトル一覧**が出る。**ステップ 4 のフォールバック込み**のため、機内モードでも **一覧は `assets/movies.json` で表示される**（エラー画面にはならない）。**エラー表示の動作確認**をしたいときは、一時的に `fetchMovieList` のフォールバックを外す、`assets/movies.json` を意図的に壊して `extractMovies` が throw する状態にする、など読者側で場面を変える。

---

### ステップ 6: `App.tsx` から画面を差し込む

Expo の空テンプレートは **`App.tsx` がエントリ**。ステータスバーは **`expo-status-bar`**。  
**`SafeAreaView` は `react-native` のものが非推奨**になっているため、**`react-native-safe-area-context`** を使う（Expo では `npx expo install react-native-safe-area-context`）。

```tsx
// ファイル: App.tsx（既存を置き換え例）
import React from 'react';
import {StyleSheet} from 'react-native';
import {StatusBar} from 'expo-status-bar';
import {SafeAreaProvider, SafeAreaView} from 'react-native-safe-area-context';
import MoviesScreen from './src/screens/MoviesScreen';

export default function App(): React.JSX.Element {
  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.safe} edges={['top', 'left', 'right']}>
        <StatusBar style="dark" />
        <MoviesScreen />
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  safe: {flex: 1},
});
```

**確認方法:** 起動直後から **映画タイトル一覧**が主画面になる。

---

### ステップ 7: Jest（jest-expo）で `extractMovies` を 1 本テストする

`blank-typescript` には **`jest` + `jest-expo`** が入っていることが多い。無い場合は [Expo の Unit testing](https://docs.expo.dev/develop/unit-testing/) に従って追加する。

プロジェクト直下に `__tests__/extractMovies.test.ts` を置く。

```ts
// ファイル: __tests__/extractMovies.test.ts
import {extractMovies} from '../src/utils/extractMovies';

describe('extractMovies', () => {
  it('検証を通った要素だけ返す', () => {
    const json = {
      movies: [
        {id: '1', title: 'A', releaseYear: '2020'},
        {id: '2', title: 'B' /* releaseYear 欠落 */},
      ],
    };
    const got = extractMovies(json);
    expect(got).toHaveLength(1);
    expect(got[0].title).toBe('A');
  });

  it('movies が無い場合は throw する', () => {
    expect(() => extractMovies({})).toThrow('movies is not an array');
  });
});
```

プロジェクト直下で次を実行する（`package.json` の `test` に合わせる）。

```bash
npm test -- --runInBand
```

**確認方法:** テストが **緑**（パス）になる。

---

**ここまでできれば今日のゴール達成**（API 取得 → state 更新 → UI 反映 + 変換ロジックのユニット検証、を Expo Go で完走）。

---

## 5. 追加課題（時間が余ったら）

**目安時間（分）: Easy 5〜10 / Medium 15〜25 / Hard 20〜40**

### Easy（5〜10 分）

`Button` で **再読み込み**する。`fetchMovieList()` を再度呼び、**`loading` が一瞬 true** に戻ることを確認する。

**回答コード例（`MoviesScreen.tsx` に `fetchMovieList` import 済み想定）:**

```tsx
import {Button, View} from 'react-native';

const handleReload = () => {
  void (async () => {
    setLoading(true);
    setError(null);
    try {
      setMovies(await fetchMovieList());
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  })();
};

<View style={{paddingHorizontal: 16, paddingBottom: 8}}>
  <Button title="再読み込み" onPress={handleReload} />
</View>
```

---

### Medium（発展）

`loading` / `error` / `movies` を **1 つの state オブジェクト**にまとめ、`useReducer` で `idle | loading | success | error` の遷移を明示する。

**回答コード例（要点のみ）:**

```tsx
type State =
  | {status: 'loading'}
  | {status: 'success'; movies: Movie[]}
  | {status: 'error'; message: string};

type Action =
  | {type: 'start'}
  | {type: 'success'; movies: Movie[]}
  | {type: 'error'; message: string};

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'start':
      return {status: 'loading'};
    case 'success':
      return {status: 'success', movies: action.movies};
    case 'error':
      return {status: 'error', message: action.message};
    default:
      return state;
  }
}
```

---

### Hard（発展）

`AbortController` を `useEffect` と組み合わせ、**アンマウント時に fetch を中止**する（`cancelled` フラグとの役割分担もコメントで整理する）。

**回答コード例（要点のみ）:**

```tsx
useEffect(() => {
  const controller = new AbortController();
  const run = async () => {
    const response = await fetch(MOVIES_URL, {signal: controller.signal});
    // ... response.ok / json / extractMovies
  };
  void run();
  return () => controller.abort();
}, []);
```

---

## 6. 実務での使いどころ（具体例3つ）

**目安時間（分）: 3**

1. **社内の一覧 API（ワークフロー承認キューなど）:** 担当者がモバイルで「未処理だけ」を `FlatList` 表示し、422 / 401 なら **そのまま `error` に載せず**メッセージを整形して再ログイン導線を出す、までを同じ state 分岐パターンで足していく。  
2. **EC のカタログ先読み:** カテゴリ ID ごとに GET し、「取得中スケルトン → 0 件は `ListEmptyComponent`」を揃える。オフラインモード時は `catch` を **「ネットワークに接続できません」** にマッピングする。  
3. **機能フラグ／メンテナンス表示:** 軽量 JSON を起動時・フォアグラウンド復帰時に取得し、**正常時だけモジュールを出し分ける**。`extractX` のように **パースを関数に閉じ、Jest で契約テスト**しておくとリリースが楽になる。

---

## 7. まとめ（今日の学び3行）

**目安時間（分）: 2**

- **Expo Go** でも **`fetch` + 薄い API 関数 + `useState` + `useEffect`** の型はそのまま使える。  
- **`response.ok` と `response.json()` の失敗**は別物として扱い、ユーザー向け文面は state に載せる。  
- **`unknown` を手元のモデルに狭める関数 + Jest 1 本**が、変な JSON への耐力を上げる最小セット。  
- **学習用 URL は届かないことがある**ため、**同スキーマのバンドル JSON にフォールバック**して環境差を吸収する。

---

## 8. 明日の布石（次のテーマ候補を2つ）

**目安時間（分）: 1**

1. **expo-router** または **React Navigation** で一覧 → 詳細し、詳細で別エンドポイントを読む。  
2. **`RefreshControl` 付き `FlatList`** と、**EAS Build / 開発ビルド**の入口（Expo Go で足りないときに何を足すか）だけ触る。

---

## 参考リンク

- React state の考え方: [State の記憶](https://react.dev/learn/state-a-components-memory)  
- RN Networking: https://reactnative.dev/docs/network  
- 公式デモ JSON（ブラウザで取得できれば `assets/movies.json` の元になる）: https://reactnative.dev/movies.json  
- Expo ドキュメント: https://docs.expo.dev/  
