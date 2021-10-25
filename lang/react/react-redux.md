## Reduxとは
- ReactとReduxを組み合わせるのを手助けしてくれるライブラリ

## Reduxの特徴
- Container ComponentとPresentational Component
- Container Component
  - Reactのコンポーネントをラップしたコンポーネントである
  - ReduxのStoreやActionを受け取りReactコンポーネントのPropsとして渡す役割を担う
  - Container Componentの責務はReactとReduxの橋渡しのみであり、ここでJSXを記述するのは誤り
- Presentational Component
  - Redux依存のない純粋なReactコンポーネント
- react-reduxには大きく分けて1.<Provider>、2.connect、という機能がある
- <Provider store>