// Dependency-free regression checks: node tests/test_web_party.mjs
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import vm from 'node:vm';
const source = readFileSync(new URL('../game/party.js', import.meta.url), 'utf8');
function storage(seed = {}, fail = false) {
  const data = new Map(Object.entries(seed).map(([key, value]) => [key, JSON.stringify(value)]));
  return { getItem(key) { if (fail) throw Error('storage disabled'); return data.get(key) ?? null; },
    setItem(key, value) { if (fail) throw Error('storage disabled'); data.set(key, value); }, data };
}
function boot(seed = {}, local = storage(seed), session = storage()) {
  const window = { localStorage: local, sessionStorage: session };
  vm.runInNewContext(source, { window });
  return { api: window.BDParty, local, session };
}
const plain = value => JSON.parse(JSON.stringify(value));
const cast = ['jp', 'maya', 'ama', 'leo', 'theo', 'mei'];
const campaign = { friend: 'mei', cleared: { '1-1': 1, '2-6': 1 }, coins: 57, seen: { '1-intro': 1 }, at4: '2-6', shown4: { 2: 1 }, receipts: ['one'], preview: true };
let ctx = boot({ 'bd-save': campaign, 'bd-mode': 'p2', 'bd-skills': ['jump'] });
assert.equal(ctx.api.read(), null, 'legacy walker is not an implicitly confirmed party');
assert.deepEqual(plain(ctx.api.defaults()), { version: 1, p1: 'mei', p2: 'jp', mode: 'p2' });
for (const mode of ['solo', 'cpu', 'p2']) for (const p1 of cast) for (const p2 of cast) {
  const saved = ctx.api.save({ mode, p1, p2 });
  assert.equal(saved.p1, p1); assert.equal(saved.mode, mode);
  assert.equal(mode === 'solo' ? saved.p2 === null : saved.p2 !== p1 && cast.includes(saved.p2), true);
  const nextPage = boot({}, ctx.local, ctx.session);
  assert.deepEqual(plain(nextPage.api.read()), plain(saved), 'party survives document navigation');
  const after = JSON.parse(ctx.local.getItem('bd-save'));
  assert.deepEqual({ ...after, friend: 'mei' }, campaign, 'party writes preserve campaign fields');
  assert.deepEqual(JSON.parse(ctx.local.getItem('bd-skills')), ['jump']);
  assert.equal(JSON.parse(ctx.local.getItem('bd-mode')), mode);
}
for (const bad of [null, [], {}, 'junk', { p1: 'unknown' }]) {
  assert.equal(boot({ 'bd-party': bad }).api.read(), null);
}
ctx = boot({ 'bd-party': { p1: 'maya', p2: 'maya', mode: 'bogus' } });
assert.deepEqual(plain(ctx.api.read()), { version: 1, p1: 'maya', p2: 'jp', mode: 'cpu' });
ctx = boot(); ctx.local.data.set('bd-party', '{'); ctx.local.data.set('bd-save', 'null');
assert.doesNotThrow(() => ctx.api.defaults()); assert.doesNotThrow(() => ctx.api.save({ p1: 'ama', mode: 'solo' }));
ctx = boot({}, storage({}, true)); ctx.api.save({ p1: 'theo', p2: 'leo', mode: 'cpu' });
assert.equal(boot({}, ctx.local, ctx.session).api.read().p1, 'theo', 'session fallback survives blocked local storage');
ctx = boot({ 'bd-party': { p1: 'jp', p2: 'maya', mode: 'cpu' } });
ctx.local.setItem = () => { throw Error('quota exceeded'); };
ctx.api.save({ p1: 'leo', mode: 'solo' });
assert.equal(boot({}, ctx.local, ctx.session).api.read().p1, 'leo', 'session fallback wins over a stale, unwritable local party');
ctx = boot({}, storage({}, true), storage({}, true));
assert.doesNotThrow(() => ctx.api.save({ p1: 'leo', mode: 'solo' }));
assert.equal(ctx.api.defaults().p1, 'jp');
const dir = new URL('../game/', import.meta.url);
const levels = readdirSync(dir).filter(name => /^[1-6]-[1-6S]$/.test(name));
assert.equal(levels.length, 42);
let scripts = 0;
for (const name of ['.', ...levels]) {
  const html = readFileSync(new URL(`${name}/index.html`, dir), 'utf8');
  for (const match of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)) {
    new vm.Script(match[1], { filename: `${name}/index.html` }); scripts++;
  }
  if (name === '.') continue;
  assert.equal((html.match(/src="\.\.\/party\.js"/g) || []).length, 1);
  assert.ok(html.includes("let state = savedParty ? 'loading' : 'title'"));
  assert.ok(html.includes('Object.assign(sel, window.BDParty.save(sel));'));
  assert.ok(html.includes("else if (id === 'again') { startLevel(); }"));
  assert.ok(!html.includes("state = 'select'; sel.step = 2;"), 'replay does not reopen selection');
  assert.ok(html.includes("const WAY = LAST ? '../index.html#credits' : '../index.html#map&next';"));
  assert.ok(html.includes("document.dispatchEvent(new CustomEvent('bd-clear'"));
  if (html.includes('if(B&&!seen(B))')) assert.ok(html.includes('window.BDStageStoryPending=true;'));
}
const map = readFileSync(new URL('index.html', dir), 'utf8');
assert.ok(map.includes('data-party>Change character</button>'));
assert.ok(map.includes("partySlot === 'p2' && k === partyDraft.p1"));
assert.ok(map.includes("if (play) play.click();"), 'map Play remains subject to the existing members-lock click handler');
console.log(`PASS: 108 party combinations, migration/storage/progress checks; ${levels.length} stage contracts; ${scripts} inline scripts parsed.`);
