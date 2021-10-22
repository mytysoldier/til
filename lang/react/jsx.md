## JSXとは
- JSXはJavaScriptを拡張した言語である
- Reactを用いた開発においてJSXの利用は必須ではないが、Reactと一緒に利用することが推奨されている
- JSXでは出力するHTMLの構造をそのまま記述でき、直感的にこのコードによって何が出力されるのか簡単に把握できる
- JSXのタグは、React.createElement関数の呼び出しに変換されるため、参照できるスコープにReactが無いと実行時にエラーになってしまう
- HTMLタグの属性名は、camelケースで記述する
- JavaScriptの予約後と被ってしまうため、JSXでは、class属性の代わりにclassNameを、for属性の代わりにhtmlForを使用する