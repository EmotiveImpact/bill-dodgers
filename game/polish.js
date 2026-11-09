// Bill Dodgers polish kit, shared by every level. Owned by the lead thread; ask there before changing it.
// Include it in the level's <head>, before the level's own script:   <script src="../polish.js"></script>
//
// What it gives you:
//  1. The console look (2x pixel grid, 32 shades, vignette) is switched OFF for the whole game since
//     8 Nov 2026, because it blurred the painted art. Leave it off. ?look=1 shows it for comparison only.
//  2. BD.parallax(g, camX, layers, t)  draws background layers that slide at different speeds.
//       layers: [{ img, f, y, h, mirror, alpha, drift, yf }]
//         img    Image or canvas. f: speed (0 = fixed sky, 0.2 far skyline, 0.5 mid, 1 = ground, 1.3 foreground).
//         y, h   where it sits on the 960x540 canvas (h defaults to the picture's height; width keeps the shape).
//         mirror true flips every other copy so the join never shows. drift: px per second of extra slide (clouds).
//         yf     optional vertical parallax: y moves by camY * yf when you pass camY in opts.
//     BD.parallax(g, camX, layers, t, { camY })
//  3. Cutting a painted picture into layers:
//       BD.splitSky(img, { tol })  -> { sky, land, skyline }  sky = the top band (far layer), land = the picture
//                                     with the sky made see-through (mid layer), skyline = row where land starts.
//       BD.band(img, y0, y1)       -> canvas of a horizontal strip (fractions 0..1), eg a floor or a hedge row.
//       BD.keyOut(img, '#ff00ff')  -> canvas with a flat background colour removed (Mac pictures on magenta).
//  4. Scene changes at a checkpoint:
//       BD.wipe('lift' | 'stairs' | 'door' | 'fade' | 'iris', () => { move the player to the next place }, { label: 'Floor 12', sub, x, y })
//     The view closes softly onto the players (or fades, for 'fade'), holds on a name card, your callback runs while it
//     is covered, then it opens on the new place. Same look in every world since 9 Nov 2026. About 2.2 s with a label.
//     BD.wiping is true while it runs (ignore input then if you like).
(function () {
  'use strict';
  const BD = (window.BD = window.BD || {});
  // OFF since 8 Nov 2026: Edem wants the full-resolution painted pixels back. Do not turn it on in any level.
  const LOOK = (BD.LOOK = Object.assign({ on: false, px: 2, levels: 32, vignette: 0 }, BD.LOOK || {}));
  if (/[?&]look=1/.test(location.search)) LOOK.on = true;

  // ---------- console look ----------
  let cv = null, g = null, small = null, sg = null, lut = null, slow = 0, lastT = -1, veil = null;
  function find() { cv = document.getElementById('game') || document.querySelector('canvas'); if (cv) g = cv.getContext('2d'); return !!g; }
  function makeLut(n) { const l = new Uint8ClampedArray(256), st = 255 / (n - 1); for (let i = 0; i < 256; i++) l[i] = Math.round(Math.round(i / st) * st); return l; }
  function veilFor() { // vignette sits over the canvas as a page layer, so it never builds up on the picture
    if (veil || !cv || !LOOK.vignette) return; veil = document.createElement('div');
    Object.assign(veil.style, { position: 'fixed', pointerEvents: 'none', zIndex: 1, background: `radial-gradient(ellipse at center, rgba(0,0,0,0) 58%, rgba(8,4,20,${LOOK.vignette}) 100%)` });
    document.body.appendChild(veil);
  }
  function syncVeil() { if (!veil) return; const s = cv.style; if (veil._k === s.left + s.top + s.width + s.height) return; veil._k = s.left + s.top + s.width + s.height; const r = cv.getBoundingClientRect(); Object.assign(veil.style, { left: r.left + 'px', top: r.top + 'px', width: r.width + 'px', height: r.height + 'px' }); }
  function post(t) {
    if (!LOOK.on || t === lastT) return; lastT = t;
    if (!g && !find()) return;
    const W = cv.width, H = cv.height, p = LOOK.px, w = Math.max(1, Math.round(W / p)), h = Math.max(1, Math.round(H / p));
    if (!small || small.width !== w || small.height !== h) { small = document.createElement('canvas'); small.width = w; small.height = h; sg = small.getContext('2d', { willReadFrequently: true }); }
    const t0 = performance.now();
    sg.imageSmoothingEnabled = true; sg.globalCompositeOperation = 'copy'; sg.drawImage(cv, 0, 0, w, h);
    if (LOOK.levels && slow < 30) { // 16-bit colour; switches itself off on slow machines
      if (!lut || lut._n !== LOOK.levels) { lut = makeLut(LOOK.levels); lut._n = LOOK.levels; }
      const im = sg.getImageData(0, 0, w, h), d = im.data; for (let i = 0; i < d.length; i += 4) { d[i] = lut[d[i]]; d[i + 1] = lut[d[i + 1]]; d[i + 2] = lut[d[i + 2]]; } sg.putImageData(im, 0, 0);
    }
    g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.globalCompositeOperation = 'copy'; g.imageSmoothingEnabled = false; g.drawImage(small, 0, 0, W, H); g.restore();
    if (performance.now() - t0 > 7) slow++; else if (slow > 0 && slow < 30) slow--;
    veilFor(); syncVeil();
  }

  // every frame the level draws, then the wipe (if any), then the console look
  const raf = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = function (cb) { return raf(function (t) { cb(t); if (wipe) drawWipe(t); post(t); }); };

  // ---------- parallax ----------
  BD.parallax = function (c, camX, layers, t, opts) {
    const VWc = c.canvas.width, camY = (opts && opts.camY) || 0, sec = (t || performance.now()) / 1000;
    for (const L of layers) {
      const im = L.img; if (!im) continue; const iw = im.naturalWidth || im.width, ih = im.naturalHeight || im.height; if (!iw || !ih) continue;
      const h = L.h || ih, w = Math.max(8, Math.round(L.w || iw * h / ih)), y = Math.round((L.y || 0) - camY * (L.yf || 0));
      const pos = camX * (L.f || 0) + (L.drift || 0) * sec, first = Math.floor(pos / w), off = Math.round(pos - first * w);
      const was = c.globalAlpha; if (L.alpha !== undefined) c.globalAlpha = was * L.alpha;
      for (let i = 0, x = -off; x < VWc; i++, x += w) {
        if (L.mirror && ((first + i) & 1)) { c.save(); c.translate(x + w, y); c.scale(-1, 1); c.drawImage(im, 0, 0, w, h); c.restore(); }
        else c.drawImage(im, x, y, w, h);
      }
      c.globalAlpha = was;
    }
  };

  // ---------- cutting pictures into layers ----------
  function toCanvas(img) { const c = document.createElement('canvas'); c.width = img.naturalWidth || img.width; c.height = img.naturalHeight || img.height; c.getContext('2d').drawImage(img, 0, 0); return c; }
  BD.band = function (img, y0, y1) { const ih = img.naturalHeight || img.height, iw = img.naturalWidth || img.width, a = Math.round(ih * y0), b = Math.round(ih * y1), c = document.createElement('canvas'); c.width = iw; c.height = Math.max(1, b - a); c.getContext('2d').drawImage(img, 0, a, iw, b - a, 0, 0, iw, b - a); return c; };
  BD.keyOut = function (img, hex, tol) {
    const c = toCanvas(img), x = c.getContext('2d'), im = x.getImageData(0, 0, c.width, c.height), d = im.data, n = parseInt((hex || '#ff00ff').slice(1), 16), R = n >> 16, G = (n >> 8) & 255, B = n & 255, T2 = Math.pow(tol || 90, 2);
    for (let i = 0; i < d.length; i += 4) { const dr = d[i] - R, dg = d[i + 1] - G, db = d[i + 2] - B; if (dr * dr + dg * dg + db * db < T2) d[i + 3] = 0; }
    x.putImageData(im, 0, 0); return c;
  };
  BD.splitSky = function (img, opts) { // flood-fills the sky from the top edge, row by row, against each row's typical sky colour
    const tol = (opts && opts.tol) || 40, c = toCanvas(img), x = c.getContext('2d'), W = c.width, H = c.height, im = x.getImageData(0, 0, W, H), d = im.data;
    const rowCol = new Float32Array(H * 3);
    for (let y = 0; y < H; y++) { const rs = [], gs = [], bs = []; for (let i = 0; i < W; i += 7) { const k = (y * W + i) * 4; rs.push(d[k]); gs.push(d[k + 1]); bs.push(d[k + 2]); } rs.sort((a, b) => a - b); gs.sort((a, b) => a - b); bs.sort((a, b) => a - b); const m = rs.length >> 1; rowCol[y * 3] = rs[m]; rowCol[y * 3 + 1] = gs[m]; rowCol[y * 3 + 2] = bs[m]; }
    const sky = new Uint8Array(W * H), q = new Int32Array(W * H); let qh = 0, qt = 0; const T2 = tol * tol;
    const isSky = (p) => { const y = (p / W) | 0, k = p * 4, dr = d[k] - rowCol[y * 3], dg = d[k + 1] - rowCol[y * 3 + 1], db = d[k + 2] - rowCol[y * 3 + 2]; return dr * dr + dg * dg + db * db < T2; };
    for (let i = 0; i < W; i++) if (isSky(i)) { sky[i] = 1; q[qt++] = i; }
    while (qh < qt) { const p = q[qh++], px = p % W, ns = [px > 0 ? p - 1 : -1, px < W - 1 ? p + 1 : -1, p + W < W * H ? p + W : -1, p - W]; for (const n of ns) if (n >= 0 && !sky[n] && isSky(n)) { sky[n] = 1; q[qt++] = n; } }
    let top = H; const colTop = new Int32Array(W);
    for (let i = 0; i < W; i++) { let y = 0; while (y < H && sky[y * W + i]) y++; colTop[i] = y; if (y < top) top = y; }
    for (let p = 0; p < W * H; p++) if (sky[p]) d[p * 4 + 3] = 0;
    for (let p = 0; p < W * H; p++) if (!sky[p]) { const px = p % W; if ((px > 0 && sky[p - 1]) || (px < W - 1 && sky[p + 1]) || (p >= W && sky[p - W])) d[p * 4 + 3] = 170; } // soft edge
    x.putImageData(im, 0, 0);
    const skyC = document.createElement('canvas'); skyC.width = W; skyC.height = Math.max(1, top + Math.round(H * 0.05)); skyC.getContext('2d').drawImage(img, 0, 0, W, skyC.height, 0, 0, W, skyC.height);
    return { sky: skyC, land: c, skyline: top / H };
  };

  // ---------- scene changes ----------
  // One look for every world since 9 Nov 2026 (Edem: the old lift, door and stair wipes looked cheap and were over too fast).
  // The view closes softly onto the players, holds on a name card for the next place, then opens there, centred on them.
  // 'fade' (time passing, a long way round) fades evenly instead. 'lift', 'stairs', 'door' and 'iris' all close onto the
  // players, so every level keeps working unchanged. opts: { label, sub, x, y } (x, y: canvas point to close onto).
  // The level's callback runs near the end of the hold, so nobody walks about unseen in the new place.
  let wipe = null; BD.wiping = false;
  BD.wipe = function (kind, mid, opts) { if (wipe) return; wipe = { kind: kind || 'fade', mid, o: opts || {}, t0: null, done: false, f0: null, f1: null }; BD.wiping = true; };
  const INK = 'rgb(16,11,26)', T_CLOSE = 520, T_OPEN = 600, T_CARD = 220;
  const ease = (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);
  function holdFor(o) { return o.label ? 1050 : 380; }
  function focusPoint(o) { // where the players stand on the canvas (worlds 2 to 6 draw the world 1.3x, anchored at the bottom)
    const W = cv.width, H = cv.height;
    if (o.x !== undefined) return { x: o.x, y: o.y !== undefined ? o.y : H * 0.6 };
    let x = W / 2;
    try { const b = window.__bd, ps = (b && b.players) || []; const up = ps.filter((p) => !p.down && !p.out); const q = up.length ? up : ps;
      if (q.length) { const ax = q.reduce((a, p) => a + p.x, 0) / q.length, sx = (ax - (b.cam || 0)) * (BD.ZOOM || 1.3) * (W / 960); if (isFinite(sx)) x = sx; } } catch (e) {}
    return { x: Math.max(W * 0.22, Math.min(W * 0.78, x)), y: H * 0.6 };
  }
  function cover(s, f) { // s: 0 open .. 1 closed
    const W = cv.width, H = cv.height;
    if (s <= 0) return;
    if (s >= 1) { g.fillStyle = INK; g.fillRect(0, 0, W, H); return; }
    if (wipe.kind === 'fade') { g.globalAlpha = s; g.fillStyle = INK; g.fillRect(0, 0, W, H); g.globalAlpha = 1; return; }
    const far = Math.max(Math.hypot(f.x, f.y), Math.hypot(W - f.x, f.y), Math.hypot(f.x, H - f.y), Math.hypot(W - f.x, H - f.y));
    const R = (far / 0.7) * (1 - s), r0 = R * 0.7;
    const gr = g.createRadialGradient(f.x, f.y, Math.max(0, r0), f.x, f.y, Math.max(1, R));
    gr.addColorStop(0, 'rgba(16,11,26,0)'); gr.addColorStop(0.55, 'rgba(16,11,26,0.55)'); gr.addColorStop(1, INK);
    g.fillStyle = gr; g.fillRect(0, 0, W, H);
    g.globalAlpha = s * s * 0.35; g.fillStyle = INK; g.fillRect(0, 0, W, H); g.globalAlpha = 1; // the whole picture dims a little too
  }
  function card(o, a, lift) { // the name of the next place, sized to the screen
    if (!o.label || a <= 0) return;
    const W = cv.width, H = cv.height, u = W / 960, font = '"Silkscreen", "Courier New", monospace';
    let size = 46 * u; g.font = `700 ${size}px ${font}`; let tw = g.measureText(o.label).width;
    if (tw > W * 0.84) { size *= (W * 0.84) / tw; g.font = `700 ${size}px ${font}`; tw = g.measureText(o.label).width; }
    const cy = H * 0.47 + lift * u;
    g.globalAlpha = a; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillStyle = 'rgba(0,0,0,0.45)'; g.fillText(o.label, W / 2, cy + 4 * u);
    g.fillStyle = '#ffd23f'; g.fillText(o.label, W / 2, cy);
    const lw = Math.min(W * 0.6, tw * 0.7 + 40 * u) * Math.min(1, a * 1.4); // a thin rule that grows out from the middle
    g.fillStyle = 'rgba(255,210,63,0.7)'; g.fillRect(Math.round(W / 2 - lw / 2), Math.round(cy + size * 0.72), Math.round(lw), Math.max(2, Math.round(3 * u)));
    if (o.sub) { g.font = `400 ${Math.round(19 * u)}px ${font}`; g.fillStyle = 'rgba(255,255,255,0.86)'; g.fillText(o.sub, W / 2, cy + size * 0.72 + 30 * u, W * 0.86); }
    g.globalAlpha = 1;
  }
  function drawWipe(t) {
    if (!g && !find()) return; const o = wipe.o;
    if (wipe.t0 === null) wipe.t0 = t; const e = t - wipe.t0, HOLD = holdFor(o), MID = T_CLOSE + HOLD - 140;
    if (!wipe.f0) wipe.f0 = focusPoint(o);
    if (e >= MID && !wipe.done) { wipe.done = true; try { wipe.mid && wipe.mid(); } catch (err) { console.error(err); } }
    let s;
    if (e < T_CLOSE) s = ease(e / T_CLOSE);
    else if (e < T_CLOSE + HOLD) s = 1;
    else if (e < T_CLOSE + HOLD + T_OPEN) { if (!wipe.f1) wipe.f1 = focusPoint(o); s = 1 - ease((e - T_CLOSE - HOLD) / T_OPEN); }
    else { wipe = null; BD.wiping = false; return; }
    g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.globalCompositeOperation = 'source-over'; g.filter = 'none';
    cover(s, e < T_CLOSE + HOLD ? wipe.f0 : wipe.f1);
    if (o.label) { // the card fades up as the view finishes closing and drifts away before it opens
      const c0 = T_CLOSE - 100, c1 = T_CLOSE + HOLD - T_CARD - 30;
      if (e > c0 && e < c1 + T_CARD) { const a = e < c0 + T_CARD ? (e - c0) / T_CARD : e > c1 ? 1 - (e - c1) / T_CARD : 1, k = ease(Math.max(0, Math.min(1, a)));
        card(o, k, e < c1 ? (1 - k) * 12 : -(1 - k) * 12); }
    }
    g.restore();
  }
})();
