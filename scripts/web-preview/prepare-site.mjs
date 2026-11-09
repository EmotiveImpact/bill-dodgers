import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { gzipSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';
const [sourceArg, targetArg] = process.argv.slice(2);
if (!sourceArg || !targetArg) throw new Error('Usage: node prepare-site.mjs EXPORT_DIR SITE_DIR');
const source = fs.realpathSync(sourceArg);
const target = path.resolve(targetArg);
if (source === target || target.startsWith(source + path.sep)) throw new Error('The hosting checkout must be separate from the export.');
const dist = path.join(target, 'dist');
if (fs.existsSync(dist)) throw new Error('dist already exists. Preserve or move it before preparing a new export.');
if (!fs.existsSync(path.join(source, 'index.html'))) throw new Error('Missing Godot index.html export.');
fs.mkdirSync(dist, { recursive: true });
const chunkSize = 19 * 1024 * 1024;
const manifest = {};
const inventory = [];
for (const name of fs.readdirSync(source)) {
  const input = path.join(source, name);
  if (name === 'export-manifest.json') continue;
  const stat = fs.lstatSync(input);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error(`Unexpected export entry: ${name}`);
  if (!/\.(html|js|pck|wasm|png|ico|svg|json|webmanifest)$/.test(name)) throw new Error(`Unexpected export file type: ${name}`);
  const bytes = fs.readFileSync(input);
  const hash = crypto.createHash('sha256').update(bytes).digest('hex');
  inventory.push({ name, size: bytes.length, sha256: hash });
  if (bytes.length <= chunkSize) {
    fs.copyFileSync(input, path.join(dist, name));
    continue;
  }
  if (!/\.(pck|wasm)$/.test(name)) throw new Error(`Large file is not a chunkable Godot binary: ${name}`);
  const parts = [];
  for (let offset = 0, index = 0; offset < bytes.length; offset += chunkSize, index += 1) {
    const part = bytes.subarray(offset, Math.min(offset + chunkSize, bytes.length));
    const compressed = gzipSync(part, { level: 9 });
    const wireHash = crypto.createHash('sha256').update(compressed).digest('hex');
    const prefix = part.subarray(0,16).toString('hex');
    if (prefix === compressed.subarray(0,16).toString('hex')) throw new Error('Ambiguous compressed and raw prefix.');
    const filename = `${name}.${hash.slice(0,16)}.part${String(index).padStart(3,'0')}.${wireHash.slice(0,16)}.gz`;
    fs.writeFileSync(path.join(dist, filename), compressed);
    parts.push({ file: filename, size: part.length, compressedSize: compressed.length, encoding: 'gzip', prefix, sha256: wireHash });
  }
  manifest[name] = { size: bytes.length, type: name.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream', parts };
}
const template = fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), 'chunk-fetch-template.js'), 'utf8');
fs.writeFileSync(path.join(dist, 'chunk-loader.js'), template.replace('__CHUNK_MANIFEST__', JSON.stringify(manifest)));
const exportedHTML = fs.readFileSync(path.join(dist, 'index.html'), 'utf8');
const configMatch = /const GODOT_CONFIG = (\{[^\n]+\});/.exec(exportedHTML);
if (!configMatch) throw new Error('Cannot locate the exact Godot export configuration.');
const config = JSON.parse(configMatch[1]);
if (config.executable !== 'index' || config.gdextensionLibs.length || config.serviceWorker || config.ensureCrossOriginIsolationHeaders) throw new Error('Unexpected export mode: requires manual hosting review.');
let html = fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), 'mobile-shell.html'), 'utf8');
html = html.replace('__GODOT_CONFIG__', JSON.stringify(config)).replace('__DOWNLOAD_MB__', String(Math.round(Object.values(config.fileSizes).reduce((a,b)=>a+b,0) / 1048576)));
fs.writeFileSync(path.join(dist, 'index.html'), html);
fs.writeFileSync(path.join(dist, '_headers'), '/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: same-origin\n\n/index.pck.*\n  Content-Type: application/gzip\n  Cache-Control: private, max-age=31536000, immutable, no-transform\n\n/index.wasm.*\n  Content-Type: application/gzip\n  Cache-Control: private, max-age=31536000, immutable, no-transform\n\n/*.wasm\n  Content-Type: application/wasm\n');
fs.writeFileSync(path.join(target, 'export-inventory.json'), JSON.stringify({ sourceFiles: inventory, chunks: manifest }, null, 2) + '\n');
fs.writeFileSync(path.join(target, 'README.md'), '# Bill Dodgers Godot Preview\n\nSeparate owner-private browser preview of the mobile Godot build. The original browser game and its hosting project are not part of this checkout.\n\nThe binary assets are split into 19 MiB chunks, stored as explicit lossless .gz assets for static hosting. `chunk-loader.js` streams native gzip decompression back to the original bytes for the unchanged Godot export loader (Safari 16.4+); it does not use a service worker.\n\nGenerated source files and chunk hashes are recorded in `export-inventory.json`.\n');
console.log(JSON.stringify({ target, sourceFiles: inventory, chunkedFiles: Object.keys(manifest), servedFiles: fs.readdirSync(dist).length, maxAssetBytes: Math.max(...fs.readdirSync(dist).map(name=>fs.statSync(path.join(dist,name)).size)) }));
