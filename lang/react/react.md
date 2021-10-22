## Reactとは
- ReactはFacebook社が開発しているJavaScriptライブラリである
- WebのUIを作ることに特化している
- ReactはBackbone.jsやAngular.jsとは違い、Viewのみのライブラリ
-　Reactでは細かいコンポーネントの組み合わせでWebアプリケーションを形作っていくという考えから、大規模なアプリケーション制作に向いている

## Reactの特徴
- Virtual DOM
  - ブラウザが保持しているDOMとは別に、React内で仮想のDOMを管理
  - ReactではDOMと対構造になっているVirtual DOMを定義し、ページ内を変化させる場合はまずVirtual DOMを変化させ、変化の差分を算出し、その対応部分を実際のDOMに反映する
- JSX

## 開発環境構築
- create-react-app（ビルド設定などなしにReactの開発を簡単にはじめられることを目的としたFacebook社が提供する開発ツール）
- Reactの開発をはじめるにはNode.jsのインストールが必要
- Node.jsとはブラウザ以外のプラットフォームで動作するJavaScriptの実行環境
- create-react-appコマンドで必要な依存パッケージを含めた状態でアプリケーションフォルダが作成される