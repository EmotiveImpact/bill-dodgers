#!/usr/bin/env node
// Evaluate only this repository's trusted scene definitions, never its DOM player.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = fs.readFileSync(path.join(root, 'game/cutscenes/cs.js'), 'utf8');
const boundary = '/* Bill Dodgers cutscene player.';
const offset = source.indexOf(boundary);
if (offset < 0 || source.indexOf(boundary, offset + 1) >= 0) throw Error('Ambiguous player boundary');
const prefix = source.slice(0, offset);
if (!prefix.trimEnd().endsWith('})();')) throw Error('Scene definition closure not complete');
const context = vm.createContext(Object.create(null), {codeGeneration: {strings: false, wasm: false}});
// No host objects/functions enter the realm. This is defense in depth for trusted
// checked-in source, not a claim that node:vm safely executes arbitrary input.
vm.runInContext('globalThis.window = Object.create(null)', context, {timeout: 1000});
vm.runInContext(prefix, context, {timeout: 1000, filename: 'trusted-story-definitions.js'});
const raw = vm.runInContext('JSON.stringify({meta:window.BD_CS_META,worlds:window.BD_CS_WORLDS,scenes:window.BD_CS_SCENES})', context, {timeout: 1000});
const data = JSON.parse(raw);
if (data.worlds.length !== 6 || !data.scenes['1-intro']) throw Error('Invalid story definitions');
const output = JSON.stringify({source: 'game/cutscenes/cs.js', source_sha256: createHash('sha256').update(source).digest('hex'), definition_sha256: createHash('sha256').update(prefix).digest('hex'), ...data}, null, 2) + '\n';
const destination = path.join(root, 'godot/content/story.json');
if (process.argv.includes('--check')) {
  if (!fs.existsSync(destination) || fs.readFileSync(destination, 'utf8') !== output) throw Error('Story export is stale. Run node scripts/extract-story.mjs');
} else { fs.mkdirSync(path.dirname(destination), {recursive:true}); fs.writeFileSync(destination, output); }
console.log(`Story: ${data.worlds.length} worlds, ${Object.keys(data.scenes).length} scenes, ${Object.values(data.scenes).reduce((n,s)=>n+s.shots.length,0)} shots`);
