// Shared map/stage party selection. Campaign progress stays in bd-save.
(function (root) {
  'use strict';
  const CAST = ['jp', 'maya', 'ama', 'leo', 'theo', 'mei'];
  const MODES = ['cpu', 'p2', 'solo'];
  const object = (v) => v && typeof v === 'object' && !Array.isArray(v) ? v : {};
  function get(storage, key) {
    try { return JSON.parse(root[storage].getItem(key)); } catch (e) { return null; }
  }
  function put(storage, key, value) {
    try { root[storage].setItem(key, JSON.stringify(value)); return true; } catch (e) { return false; }
  }
  function normalize(value) {
    const v = object(value), p1 = CAST.includes(v.p1) ? v.p1 : 'jp';
    const mode = MODES.includes(v.mode) ? v.mode : 'cpu';
    const p2 = mode === 'solo' ? null : CAST.includes(v.p2) && v.p2 !== p1 ? v.p2 : CAST.find((k) => k !== p1);
    return { version: 1, p1, p2, mode };
  }
  function read() {
    const stores = get('sessionStorage', 'bd-party-fallback') ? ['sessionStorage', 'localStorage'] : ['localStorage', 'sessionStorage'];
    const value = stores.map((storage) => get(storage, 'bd-party')).find((v) => v && CAST.includes(v.p1));
    // Old saves have only a map walker and mode. Offer those as defaults, but
    // do not silently choose a second player until the player confirms a party.
    if (!value || !CAST.includes(value.p1)) return null;
    return normalize(value);
  }
  function defaults() {
    const campaign = object(get('localStorage', 'bd-save'));
    return read() || normalize({ p1: campaign.friend, mode: get('localStorage', 'bd-mode') });
  }
  function save(value) {
    const party = normalize(value);
    const persistent = put('localStorage', 'bd-party', party);
    put('sessionStorage', 'bd-party-fallback', !persistent);
    put('sessionStorage', 'bd-party', party); // also works when only persistent storage is unavailable
    put('localStorage', 'bd-mode', party.mode); // legacy stages/settings remain compatible
    const campaign = object(get('localStorage', 'bd-save'));
    campaign.friend = party.p1;
    put('localStorage', 'bd-save', campaign); // merge, never replace cleared levels, coins, story or skills
    return party;
  }
  root.BDParty = { normalize, read, defaults, save };
})(typeof window === 'undefined' ? globalThis : window);
