// Optional automatic launcher for the dependency-free in-browser regression.
// Requires an installed Playwright and Chromium. The HTML runner also works
// directly: serve the repo, open /tests/web-party-browser.html, click Run.
// node tests/test_web_party_browser.mjs [game|dist] [--all]
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFileSync, statSync } from 'node:fs';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const build = process.argv.includes('dist') ? 'dist' : 'game';
const server = createServer((req, res) => {
  let file = resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
  if (!file.startsWith(root + sep) && file !== root) { res.writeHead(403).end(); return; }
  try {
    if (statSync(file).isDirectory()) file += '/index.html';
    res.setHeader('Content-Type', ({ '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.jpg': 'image/jpeg', '.woff2': 'font/woff2' })[extname(file)] || 'application/octet-stream');
    res.end(readFileSync(file));
  } catch { res.writeHead(404).end(); }
});
await new Promise(done => server.listen(0, '127.0.0.1', done));
let browser;
try {
  browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  const page = await browser.newPage({ viewport: { width: 1024, height: 800 } });
  await page.goto(`http://127.0.0.1:${server.address().port}/tests/web-party-browser.html?root=../${build}/${process.argv.includes('--all') ? '&all=1' : ''}`);
  await page.locator('#run').click();
  await page.waitForFunction(() => ['pass', 'fail'].includes(document.getElementById('status').dataset.state), null, { timeout: 300000 });
  const status = await page.locator('#status').textContent();
  console.log(status); console.log(await page.locator('#results').textContent());
  assert.equal(await page.locator('#status').getAttribute('data-state'), 'pass', status);
} finally { if (browser) await browser.close(); await new Promise(done => server.close(done)); }
