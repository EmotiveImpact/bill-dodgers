import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const template = fs.readFileSync(new URL('./chunk-fetch-template.js', import.meta.url), 'utf8');
const bytes = new Uint8Array(64013).map((_, i) => (i * 17) % 251);
const parts = [bytes.slice(0, 32000), bytes.slice(32000)];
const manifest = { 'index.pck': { size: bytes.length, type: 'application/octet-stream', parts: parts.map((b, i) => ({ file: `pack.part${i}`, size: b.length })) } };
function harness(behavior = 'ok') {
  const calls = [];
  const nativeFetch = async (input, options) => {
    const url = String(input);
    calls.push(url);
    const index = /^https:\/\/demo\.example\/game\/pack\.part(\d)$/.exec(url)?.[1];
    if (index === undefined) return new Response('passthrough');
    if (behavior === 'http' && index === '1') return new Response('broken', { status: 404 });
    if (behavior === 'short' && index === '1') return new Response(parts[index].slice(1));
    if (behavior === 'long' && index === '1') return new Response(new Uint8Array(parts[index].length + 1));
    if (behavior === 'header') return new Response(parts[index], { headers: { 'Content-Length': '17' } });
    if (behavior === 'no-body') return new Response(null);
    if (options?.signal?.aborted) throw new DOMException('Aborted', 'AbortError');
    return new Response(parts[index], { headers: { 'Content-Length': String(parts[index].length) } });
  };
  const window = { fetch: nativeFetch, dispatchEvent() {} };
  vm.runInNewContext(template.replace('__CHUNK_MANIFEST__', JSON.stringify(manifest)), {
    window, document: { currentScript: { src: 'https://demo.example/game/chunk-loader.js' }, baseURI: 'https://demo.example/game/' },
    URL, Map, Headers, Response, ReadableStream, AbortController, DOMException, CustomEvent
  });
  return { fetch: window.fetch, calls };
}
const good = harness();
const response = await good.fetch('index.pck?cache=1');
assert.equal(response.headers.get('Content-Length'), String(bytes.length));
assert.equal(response.headers.get('Content-Type'), 'application/octet-stream');
assert.deepEqual(new Uint8Array(await response.arrayBuffer()), bytes);
assert.equal(good.calls.length, 2);
assert.equal(await (await good.fetch('https://other.example/index.pck')).text(), 'passthrough');
assert.equal(await (await good.fetch('elsewhere.pck')).text(), 'passthrough');
assert.equal(await (await good.fetch('index.pck', { method: 'POST' })).text(), 'passthrough');
const head = harness();
assert.equal((await head.fetch('index.pck', { method: 'HEAD' })).body, null);
assert.equal(head.calls.length, 0);
for (const behavior of ['http', 'short', 'long', 'header', 'no-body']) {
  const broken = harness(behavior);
  await assert.rejects(async () => (await broken.fetch('index.pck')).arrayBuffer());
}
const aborted = new AbortController();
aborted.abort();
await assert.rejects(harness().fetch('index.pck', { signal: aborted.signal }), { name: 'AbortError' });
const request = harness();
assert.deepEqual(new Uint8Array(await (await request.fetch(new Request('https://demo.example/game/index.pck'))).arrayBuffer()), bytes);
console.log('PASS: byte identity, content headers, query handling, origin/path isolation, HEAD, passthrough, Request input, HTTP/short/long/header/no-body failures, early abort.');
