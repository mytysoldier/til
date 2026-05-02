#!/usr/bin/env node
/**
 * 今日の教材で使う JSONPlaceholder の「形」だけを確認する最小チェックです。
 * 依存パッケージなし（Node 18 以降の組み込み fetch を使用）。
 *
 * 実行（教材と同じフォルダで）:
 *   node api_contract_check.mjs
 *
 * 期待される出力:
 *   OK: API の形が今日の前提と一致しています
 */
const API_URL = "https://jsonplaceholder.typicode.com/posts/1";

const res = await fetch(API_URL, { method: "GET" });
if (!res.ok) {
  throw new Error(`HTTP エラー: ${res.status}`);
}

let data;
try {
  data = await res.json();
} catch (e) {
  throw new Error("response.json() に失敗（本文が JSON ではない可能性）", { cause: e });
}

if (data === null || typeof data !== "object" || Array.isArray(data)) {
  throw new Error("トップレベルがオブジェクトではありません");
}
for (const key of ["userId", "id", "title", "body"]) {
  if (!(key in data)) {
    throw new Error(`必須キーが欠けています: ${key}`);
  }
}
if (typeof data.title !== "string" || typeof data.body !== "string") {
  throw new Error("title / body が string ではありません");
}

console.log("OK: API の形が今日の前提と一致しています");
