// Reconstitute only this export's binary downloads as streams. No service worker.
(() => {
  'use strict';
  const manifest = __CHUNK_MANIFEST__;
  const base = new URL('.', document.currentScript.src || document.baseURI);
  const nativeFetch = window.fetch.bind(window);
  const byURL = new Map(Object.entries(manifest).map(([name, entry]) => [new URL(name, base).href, entry]));
  async function decodedPartStream(response, part) {
    if (part.encoding !== 'gzip') return response.body;
    const source = response.body.getReader();
    let prefix = new Uint8Array(0);
    while (prefix.byteLength < 16) {
      const item = await source.read();
      if (item.done) break;
      if (!prefix.byteLength) prefix = item.value;
      else { const joined = new Uint8Array(prefix.byteLength + item.value.byteLength); joined.set(prefix); joined.set(item.value, prefix.byteLength); prefix = joined; }
    }
    const prefixHex = Array.from(prefix.subarray(0, Math.min(16, part.size)), value => value.toString(16).padStart(2, '0')).join('');
    // Fetch removes HTTP Content-Encoding. If the server used the stored gzip
    // as that encoding, these bytes are already decoded. The recorded raw
    // prefix distinguishes that case from another HTTP layer around the gzip.
    const httpGzip = /(?:^|,)\s*gzip\s*(?:,|$)/i.test(response.headers.get('Content-Encoding') || '');
    const alreadyDecoded = httpGzip && prefixHex === part.prefix;
    if (!alreadyDecoded && (prefix[0] !== 31 || prefix[1] !== 139)) {
      try { Promise.resolve(source.cancel()).catch(() => {}); } catch (_) { /* Preserve the integrity error. */ }
      throw new Error('A compressed game download was invalid. Reload to retry.');
    }
    const replay = new ReadableStream({
      start(controller) { if (prefix.byteLength) controller.enqueue(prefix); },
      async pull(controller) { const item = await source.read(); if (item.done) controller.close(); else controller.enqueue(item.value); },
      cancel(reason) { return source.cancel(reason); }
    });
    if (alreadyDecoded) return replay;
    return replay.pipeThrough(new DecompressionStream('gzip'));
  }
  window.fetch = function (input, options) {
    const requestURL = new URL(typeof input === 'string' || input instanceof URL ? input : input.url, document.baseURI);
    requestURL.hash = '';
    // Godot may add a query parameter to avoid a stale download.
    requestURL.search = '';
    const entry = byURL.get(requestURL.href);
    const method = String(options?.method || input?.method || 'GET').toUpperCase();
    if (!entry || !['GET', 'HEAD'].includes(method)) return nativeFetch(input, options);
    const headers = new Headers({ 'Content-Type': entry.type, 'Content-Length': String(entry.size) });
    const signal = options?.signal || (typeof input === 'object' ? input.signal : undefined);
    if (signal?.aborted) return Promise.reject(signal.reason || new DOMException('The download was cancelled.', 'AbortError'));
    if (method === 'HEAD') return Promise.resolve(new Response(null, { status: 200, headers }));
    const abort = new AbortController();
    let reader = null;
    let partIndex = 0;
    let partBytes = 0;
    let stopped = false;
    const onAbort = () => abort.abort(signal.reason);
    signal?.addEventListener('abort', onAbort, { once: true });
    const cleanup = () => signal?.removeEventListener('abort', onAbort);
    const stream = new ReadableStream({
      async pull(controller) {
        try {
          while (!stopped) {
            if (!reader) {
              if (partIndex === entry.parts.length) {
                cleanup();
                stopped = true;
                controller.close();
                return;
              }
              const part = entry.parts[partIndex];
              const response = await nativeFetch(new URL(part.file, base), { credentials: 'same-origin', signal: abort.signal });
              if (!response.ok) throw new Error(`Game download failed (${response.status}) for part ${partIndex + 1}. Reload to retry.`);
              const encoding = response.headers.get('Content-Encoding');
              const sizeHeader = response.headers.get('Content-Length');
              if (/text\/html/i.test(response.headers.get('Content-Type') || '')) throw new Error('Game download needs a valid sign-in. Sign in and reload to retry.');
              if ((!encoding || encoding === 'identity') && sizeHeader && Number(sizeHeader) !== (part.compressedSize ?? part.size)) throw new Error('Game download returned an unexpected file size. Sign in and reload to retry.');
              if (!response.body) throw new Error('Streaming downloads are unavailable in this browser. Please use a current Safari version.');
              reader = (await decodedPartStream(response, part)).getReader();
              partBytes = 0;
            }
            const item = await reader.read();
            if (!item.done) {
              partBytes += item.value.byteLength;
              if (partBytes > entry.parts[partIndex].size) throw new Error('A game download was larger than expected. Reload to retry.');
              controller.enqueue(item.value);
              return;
            }
            reader.releaseLock();
            reader = null;
            if (partBytes !== entry.parts[partIndex].size) throw new Error('A game download was interrupted. Reload to retry.');
            partIndex += 1;
          }
        } catch (error) {
          if (stopped) return;
          stopped = true;
          cleanup();
          abort.abort();
          window.dispatchEvent(new CustomEvent('bill-dodgers-download-error', { detail: { message: error?.message || 'The game download was interrupted. Reload to retry.' } }));
          controller.error(error);
          try { Promise.resolve(reader?.cancel(error)).catch(() => {}); } catch (_) { /* Recovery UI is already visible. */ }
        }
      },
      async cancel(reason) {
        stopped = true;
        cleanup();
        abort.abort(reason);
        try { await reader?.cancel(reason); } catch (_) { /* Download is already stopping. */ }
      }
    });
    return Promise.resolve(new Response(stream, { status: 200, headers }));
  };
})();
