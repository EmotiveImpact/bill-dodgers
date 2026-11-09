import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import assert from 'node:assert/strict';
import vm from 'node:vm';
const root = path.resolve(process.argv[2]);
const dist = path.join(root, 'dist');
const inventory = JSON.parse(fs.readFileSync(path.join(root,'export-inventory.json')));
for (const [name, data] of Object.entries(inventory.chunks)) {
 const digest = crypto.createHash('sha256'); let bytes=0;
 for (const part of data.parts) {
  const payload=fs.readFileSync(path.join(dist,part.file));
  assert.equal(payload.length,part.compressedSize ?? part.size);
  assert.ok(payload.length <= 20*1024*1024);
  if (part.sha256) assert.equal(crypto.createHash('sha256').update(payload).digest('hex'),part.sha256);
  const decoded = part.encoding === 'gzip' ? gunzipSync(payload) : payload;
  assert.equal(decoded.length,part.size);
  digest.update(decoded); bytes+=decoded.length;
 }
 const original=inventory.sourceFiles.find(f=>f.name===name);
 assert.equal(bytes,original.size); assert.equal(digest.digest('hex'),original.sha256);
 assert.ok(!fs.existsSync(path.join(dist,name)));
}
for (const original of inventory.sourceFiles.filter(f=>!inventory.chunks[f.name] && f.name!=='index.html')) {
 assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(dist,original.name))).digest('hex'),original.sha256);
}
for(const file of fs.readdirSync(dist)) assert.ok(fs.statSync(path.join(dist,file)).size <= 20*1024*1024);
const html=fs.readFileSync(path.join(dist,'index.html'),'utf8');
assert.ok(html.includes('viewport-fit=cover'));
assert.ok(html.includes('GODOT_CONFIG.canvasResizePolicy = 0'));
assert.ok(html.includes('env(safe-area-inset-left'));
assert.ok(html.includes('env(safe-area-inset-right'));
assert.ok(html.includes('ResizeObserver'));
assert.ok(html.includes("document.hidden) canvas.blur()"));
for(const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) if(match[1].trim()) new vm.Script(match[1]);
new vm.Script(fs.readFileSync(path.join(dist,'chunk-loader.js'),'utf8'));
console.log('PASS: full PCK/WASM chunk recombination hashes, unchanged engine/audio assets, file cap, safe-area/visibility shell, all JavaScript syntax.');
