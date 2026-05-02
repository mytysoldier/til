#!/usr/bin/env node
/**
 * tutorial/ を静的に配信する最小サーバー（依存パッケージなし）。
 * Python が無く Node 18+ だけある環境向け。
 *
 * 実行（このファイルと tutorial/ が同じ親にある想定で、親フォルダで）:
 *   node serve_tutorial.mjs
 *
 * 開く:
 *   http://127.0.0.1:8765/
 *
 * ポートが埋まっているとき:
 *   PORT=8766 node serve_tutorial.mjs
 */
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "tutorial");
const port = Number(process.env.PORT ?? 8765);

function contentType(filePath) {
  if (filePath.endsWith(".html")) return "text/html; charset=utf-8";
  if (filePath.endsWith(".js")) return "text/javascript; charset=utf-8";
  if (filePath.endsWith(".css")) return "text/css; charset=utf-8";
  if (filePath.endsWith(".json")) return "application/json; charset=utf-8";
  return "application/octet-stream";
}

const server = http.createServer((req, res) => {
  const urlPath = (req.url ?? "/").split("?")[0] || "/";
  const rel = urlPath === "/" ? "index.html" : urlPath.slice(1);
  const resolved = path.resolve(path.join(root, rel));
  const rootResolved = path.resolve(root);

  if (!resolved.startsWith(rootResolved + path.sep) && resolved !== rootResolved) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.readFile(resolved, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    res.setHeader("Content-Type", contentType(resolved));
    res.end(data);
  });
});

server.listen(port, () => {
  console.log(`配信フォルダ: ${root}`);
  console.log(`http://127.0.0.1:${port}/`);
});
