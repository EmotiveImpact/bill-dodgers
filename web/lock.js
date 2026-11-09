// Members lock for the web version (added to index.html by scripts/build-web.mjs; the game itself is unchanged).
// Worlds in FREE play as normal. Play on a level in any other world opens the lock card instead, and the map card's
// Play button for those levels reads "Members". The locked levels' files are not deployed, so this is the only way in.
(function () {
  'use strict';
  var FREE = __FREE_WORLDS__;
  var NAMES = { 1: 'Your street', 2: 'The big shop', 3: 'Festival weekend', 4: 'Group holiday', 5: 'Moving day', 6: 'The Bill-ding' };
  var COLS = { 1: '#e84a5f', 2: '#3f7fe0', 3: '#ff9f1c', 4: '#19c3b4', 5: '#b05fd6', 6: '#f4c542' };
  var JOIN = 'https://ourcommune.io/pricing';
  var LEVEL = /(?:^|\/)([1-6])-([1-7S])\/(?:index\.html)?(?:[?#].*)?$/;

  function lockedWorld(href) {
    var m = LEVEL.exec(href || '');
    if (!m) return 0;
    var w = +m[1];
    return FREE.indexOf(w) >= 0 ? 0 : w;
  }

  var css = document.createElement('style');
  css.textContent =
    "@font-face{font-family:'BD Silk';src:url(cutscenes/img/silk.woff2) format('woff2');font-display:swap}" +
    "@font-face{font-family:'BD Pixel';src:url(cutscenes/img/pixelify.woff2) format('woff2');font-weight:400 700;font-display:swap}" +
    '#bdLock{position:fixed;inset:0;z-index:9999;display:none;align-items:center;justify-content:center;padding:16px;background:rgba(8,6,18,.72);-webkit-backdrop-filter:blur(3px);backdrop-filter:blur(3px)}' +
    '#bdLock.on{display:flex}' +
    '#bdLock .box{position:relative;width:min(440px,100%);max-height:calc(100vh - 24px);max-height:calc(100dvh - 24px);overflow:auto;-webkit-overflow-scrolling:touch;background:#141026;color:#f5f1ea;border:4px solid var(--wc,#f4c542);border-radius:22px;padding:22px 22px 18px;box-shadow:0 18px 50px rgba(0,0,0,.55);font:400 16px/1.45 "BD Pixel",system-ui,sans-serif;text-align:left;animation:bdIn .28s cubic-bezier(.2,1.3,.4,1)}' +
    '@keyframes bdIn{from{transform:translateY(14px) scale(.96);opacity:0}to{transform:none;opacity:1}}' +
    '#bdLock .top{display:flex;align-items:center;gap:14px;margin-bottom:12px}' +
    '#bdLock .pad{flex:0 0 auto;width:46px;height:52px}' +
    '#bdLock small{display:block;font:700 13px "BD Silk",monospace;letter-spacing:.06em;color:var(--wc,#f4c542)}' +
    '#bdLock h2{margin:2px 0 0;font:700 24px/1.15 "BD Silk",monospace;color:#f5f1ea}' +
    '#bdLock p{margin:0 0 10px;color:rgba(245,241,234,.9)}' +
    '#bdLock ul{margin:0 0 14px;padding:0;list-style:none;display:grid;grid-template-columns:1fr 1fr;gap:6px}' +
    '#bdLock li{font:700 12px/1.3 "BD Silk",monospace;padding:8px 10px;border-radius:12px;background:rgba(245,241,234,.07);border-left:4px solid var(--c)}' +
    '#bdLock li b{display:block;font-weight:700;color:var(--c);font-size:11px}' +
    '#bdLock .btns{display:flex;flex-wrap:wrap;gap:8px;margin-top:4px}' +
    '#bdLock .btns a,#bdLock .btns button{flex:1 1 150px;display:inline-flex;align-items:center;justify-content:center;min-height:46px;padding:10px 16px;border-radius:999px;font:700 14px "BD Silk",monospace;text-decoration:none;cursor:pointer;border:0}' +
    '#bdLock .go{background:#f4c542;color:#1c1606}' +
    '#bdLock .back{background:transparent;color:#f5f1ea;border:2px solid rgba(245,241,234,.3)!important}' +
    '#bdLock .fine{margin:12px 0 0;font-size:13px;color:rgba(245,241,234,.6)}' +
    '#card a.btn.go.bd-members{background:#2a2346;color:#f4c542}' +
    '@media (max-height:520px){#bdLock{padding:10px}#bdLock .box{width:min(560px,100%);padding:14px 18px 12px;font-size:14px;line-height:1.35}#bdLock .top{margin-bottom:8px}#bdLock .pad{width:34px;height:38px}#bdLock h2{font-size:19px}#bdLock p{margin-bottom:8px}' +
    '#bdLock ul{grid-template-columns:repeat(4,1fr);gap:5px;margin-bottom:10px}#bdLock li{padding:6px 8px;font-size:10px}#bdLock li b{font-size:9px}#bdLock .btns a,#bdLock .btns button{min-height:40px;font-size:12px}#bdLock .fine{margin-top:8px;font-size:12px}}';
  document.head.appendChild(css);

  var el = document.createElement('div');
  el.id = 'bdLock';
  el.setAttribute('role', 'dialog');
  el.setAttribute('aria-modal', 'true');
  el.setAttribute('aria-labelledby', 'bdLockTitle');
  document.body.appendChild(el);

  var PAD = '<svg class="pad" viewBox="0 0 46 52" aria-hidden="true"><path d="M12 22v-7a11 11 0 0 1 22 0v7" fill="none" stroke="#f5f1ea" stroke-width="5"/><rect x="4" y="21" width="38" height="29" rx="7" fill="var(--wc,#f4c542)"/><rect x="20" y="30" width="6" height="11" rx="3" fill="#141026"/></svg>';

  function open(w) {
    var locked = [];
    for (var i = 1; i <= 6; i++) if (FREE.indexOf(i) < 0) locked.push(i);
    el.style.setProperty('--wc', COLS[w]);
    el.innerHTML =
      '<div class="box"><div class="top">' + PAD + '<div><small>WORLD ' + w + ': ' + NAMES[w].toUpperCase() + '</small>' +
      '<h2 id="bdLockTitle">Members only from here</h2></div></div>' +
      '<p>You\'ve played the free worlds. Commune members play the whole story, the bosses and the ending, across every island:</p>' +
      '<ul>' + locked.map(function (n) { return '<li style="--c:' + COLS[n] + '"><b>WORLD ' + n + '</b>' + NAMES[n] + '</li>'; }).join('') + '</ul>' +
      '<div class="btns"><a class="go" href="' + JOIN + '" target="_top">Become a member</a><button type="button" class="back" data-bd-close>Back to the map</button></div>' +
      '<p class="fine">Already a member? Every world opens in the Commune app.</p></div>';
    el.classList.add('on');
    var b = el.querySelector('.go');
    if (b) try { b.focus({ preventScroll: true }); } catch (e) {}
  }
  function close() { el.classList.remove('on'); }
  el.addEventListener('click', function (e) { if (e.target === el || e.target.closest('[data-bd-close]')) close(); });
  el.addEventListener('pointerdown', function (e) { e.stopPropagation(); });
  addEventListener('keydown', function (e) {
    if (!el.classList.contains('on')) return;
    if (e.key === 'Escape') { close(); e.stopImmediatePropagation(); }
    else if (e.key === 'Enter' || e.key === ' ') { e.stopImmediatePropagation(); } // the map would otherwise act on the hidden card
  }, true);

  // Play (a tap, or Enter on the map, which clicks the button) on a locked level opens the lock card instead
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    var w = lockedWorld(a.getAttribute('href'));
    if (!w) return;
    e.preventDefault();
    e.stopPropagation();
    open(w);
  }, true);

  // the map card says "Members" on locked levels, so the lock is no surprise
  function mark() {
    var card = document.getElementById('card');
    if (!card) return;
    var a = card.querySelector('a.btn.go');
    if (a && lockedWorld(a.getAttribute('href')) && !a.classList.contains('bd-members')) {
      a.classList.add('bd-members');
      a.textContent = 'Members';
    }
  }
  var card = document.getElementById('card');
  if (card && window.MutationObserver) new MutationObserver(mark).observe(card, { childList: true, subtree: true });

  // a locked level's address (sent here by 404.html as ?members=3#map) opens the map with the lock card up
  var m = /[?&]members=([1-6])/.exec(location.search);
  if (m) {
    try { history.replaceState(null, '', location.pathname); } catch (e) {}
    if (FREE.indexOf(+m[1]) < 0) open(+m[1]);
  }
})();
