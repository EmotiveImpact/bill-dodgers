// Builds the public web version of Bill Dodgers into dist/ from the full game in game/.
//
//   node scripts/build-web.mjs           Worlds 1 and 2 only, with the members lock on Worlds 3 to 6 (ourcommune.io/arcade)
//   node scripts/build-web.mjs --all     every world, no lock (for the members' version in the Commune app later)
//
// game/ is the full game exactly as the lead game thread builds it (map4/build_full.py). Nothing in game/ is edited here.
// The web build:
//   1. copies game/ to dist/, leaving out the level folders of the locked worlds, so their files are never public
//   2. changes links that end in index.html to end in a slash ("1-1/index.html" -> "1-1/", "../index.html#map" -> "../#map"),
//      because ourcommune.io strips index.html from addresses, which would break the levels' relative links
//   3. adds the members lock (web/lock.js) to the title and map page: Play on a locked level opens the lock card
//   4. writes 404.html, which sends a locked or missing level back to the map with the lock card open
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const GAME = join(ROOT, 'game');
const DIST = join(ROOT, 'dist');
const ALL = process.argv.includes('--all');
const FREE_WORLDS = [1, 2];
const LEVEL_DIR = /^([1-6])-([1-7S])$/;

const locked = (name) => {
  const m = LEVEL_DIR.exec(name);
  return !ALL && !!m && !FREE_WORLDS.includes(+m[1]);
};

rmSync(DIST, { recursive: true, force: true });
mkdirSync(DIST, { recursive: true });

const kept = [], left = [];
for (const name of readdirSync(GAME)) {
  if (locked(name)) { left.push(name); continue; }
  cpSync(join(GAME, name), join(DIST, name), { recursive: true });
  if (LEVEL_DIR.test(name)) kept.push(name);
}

// links: drop index.html so the website's clean addresses never cut a level off from its files
const relink = (html) => html
  .replace(/(["'(])((?:\.\.\/)?)index\.html(?=[#"'?)])/g, '$1$2')   // "../index.html#map" -> "../#map", "index.html" -> ""
  .replace(/"([1-6]-[1-7S])\/index\.html"/g, '"$1/"');            // "1-1/index.html" -> "1-1/"

const levelPages = [];
const walk = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p);
    else if (name === 'index.html' && dir !== DIST) levelPages.push(p);
  }
};
walk(DIST);
for (const p of levelPages) writeFileSync(p, relink(readFileSync(p, 'utf8')));

let index = relink(readFileSync(join(DIST, 'index.html'), 'utf8'));
if (!ALL) {
  const lock = readFileSync(join(ROOT, 'web', 'lock.js'), 'utf8')
    .replace('__FREE_WORLDS__', JSON.stringify(FREE_WORLDS));
  const tag = `<script>/* bd-web-lock */\n${lock}</script>`;
  if (!index.includes('/* bd-web-lock */')) {
    const at = index.lastIndexOf('</body>');
    index = at >= 0 ? index.slice(0, at) + tag + '\n' + index.slice(at) : index + tag;
  }
}
writeFileSync(join(DIST, 'index.html'), index);
writeFileSync(join(DIST, '404.html'), readFileSync(join(ROOT, 'web', '404.html'), 'utf8'));
if (existsSync(join(ROOT, 'web', 'card.jpg'))) cpSync(join(ROOT, 'web', 'card.jpg'), join(DIST, 'card.jpg'));

let bytes = 0, files = 0;
const size = (dir) => { for (const n of readdirSync(dir)) { const p = join(dir, n); const s = statSync(p); if (s.isDirectory()) size(p); else { bytes += s.size; files++; } } };
size(DIST);
console.log(`Bill Dodgers web build: ${ALL ? 'every world' : 'Worlds ' + FREE_WORLDS.join(' and ') + ' free'}, ` +
  `${kept.length} levels in, ${left.length} locked levels left out, ${files} files, ${(bytes / 1e6).toFixed(0)} MB`);
