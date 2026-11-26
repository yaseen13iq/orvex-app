import { DatabaseSync } from 'node:sqlite';

export function makeKV() {
  const m = new Map();
  let writes = 0, ops = 0;
  return {
    _m: m,
    get stats() { return { writes, ops }; },
    async get(k, o) { ops++; const v = m.get(k); if (v == null) return null; const t = typeof o === 'string' ? o : o && o.type; return t === 'json' ? JSON.parse(v) : v; },
    async put(k, v) { ops++; writes++; m.set(k, typeof v === 'string' ? v : JSON.stringify(v)); },
    async delete(k) { ops++; writes++; m.delete(k); },
    async list({ prefix = '', limit = 1000, cursor } = {}) {
      ops++;
      const keys = [...m.keys()].filter((k) => k.startsWith(prefix)).sort();
      const start = cursor ? Number(cursor) : 0;
      const page = keys.slice(start, start + limit);
      const done = start + limit >= keys.length;
      return { keys: page.map((name) => ({ name })), list_complete: done, cursor: done ? undefined : String(start + limit) };
    },
  };
}

export function makeD1() {
  const db = new DatabaseSync(':memory:');
  const isRead = (sql) => /^\s*(SELECT|WITH)/i.test(sql) || /\bRETURNING\b/i.test(sql);
  function stmt(sql, args = []) {
    return {
      sql, args,
      bind(...a) { return stmt(sql, a); },
      async first(col) { const r = db.prepare(sql).get(...args.map(norm)); if (!r) return null; return col ? r[col] : { ...r }; },
      async all() { return { results: db.prepare(sql).all(...args.map(norm)).map((r) => ({ ...r })), success: true, meta: {} }; },
      async run() { const r = db.prepare(sql).run(...args.map(norm)); return { success: true, meta: { changes: Number(r.changes), last_row_id: Number(r.lastInsertRowid) } }; },
      _exec() { if (isRead(sql)) return { results: db.prepare(sql).all(...args.map(norm)).map((r) => ({ ...r })), success: true, meta: {} }; const r = db.prepare(sql).run(...args.map(norm)); return { results: [], success: true, meta: { changes: Number(r.changes) } }; },
    };
  }
  const norm = (v) => (v === undefined ? null : typeof v === 'boolean' ? (v ? 1 : 0) : v);
  return {
    _db: db,
    prepare(sql) { return stmt(sql); },
    async batch(list) { db.exec('BEGIN'); try { const out = list.map((s) => s._exec()); db.exec('COMMIT'); return out; } catch (e) { db.exec('ROLLBACK'); throw e; } },
    async exec(sql) { db.exec(sql); return { count: 1 }; },
  };
}

export function makeEnv(extra = {}) {
  return {
    SITE: makeKV(),
    DB: makeD1(),
    FILES: makeR2(),
    BOT_TOKEN: '111:CTL',
    NOTIFY_BOT_TOKEN: '222:NTF',
    WEBHOOK_SECRET: 'whsecret-123',
    SETUP_CODE: 'setup-code-xyz',
    SITE_URL: 'https://iraqfit.com',
    ...extra,
  };
}

export const tg = { calls: [], fail: new Set(), rate: 0 };
globalThis.fetch = async (url, init = {}) => {
  url = String(url);
  if (url.startsWith('https://api.telegram.org/')) {
    const body = init.body ? JSON.parse(init.body) : {};
    const method = url.split('/').pop();
    tg.calls.push({ method, body, token: url.split('/bot')[1].split('/')[0] });
    if (method === 'sendMessage' && tg.fail.has(String(body.chat_id))) return new Response(JSON.stringify({ ok: false, error_code: 403, description: 'Forbidden: bot was blocked by the user' }));
    if (method === 'getWebhookInfo') return new Response(JSON.stringify({ ok: true, result: { url: 'https://x', pending_update_count: 0 } }));
    return new Response(JSON.stringify({ ok: true, result: { message_id: 1 } }));
  }
  throw new Error('unexpected fetch ' + url);
};

export function makeCtx() {
  const p = [];
  return { waitUntil(x) { p.push(Promise.resolve(x).catch((e) => console.log('waitUntil err', e))); }, passThroughOnException() {}, async flush() { await Promise.all(p.splice(0)); } };
}

export function req(path, { method, body, raw, headers = {}, cf, cookie, ip = '1.2.3.4' } = {}) {
  method = method || (body !== undefined ? 'POST' : raw !== undefined ? 'PUT' : 'GET');
  const h = new Headers({ 'cf-connecting-ip': ip, 'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Instagram 300.0', ...headers });
  if (cookie) h.set('cookie', cookie);
  if (body !== undefined) h.set('content-type', 'application/json');
  if (raw !== undefined) { h.set('content-type', 'application/octet-stream'); h.set('content-length', String(raw.length)); }
  const r = new Request('https://iraqfit.com' + path, { method, headers: h, body: body !== undefined ? JSON.stringify(body) : raw !== undefined ? raw : undefined, duplex: 'half' });
  Object.defineProperty(r, 'cf', { value: cf || { country: 'IQ', city: 'Erbil', region: 'Erbil', latitude: '36.19', longitude: '44.01' } });
  return r;
}

export function makeClient(worker, env) {
  let cookie = '';
  const ctx = makeCtx();
  async function call(path, opt = {}) {
    const headers = { ...(opt.headers || {}) };
    if (opt.method === 'POST' || opt.method === 'PUT' || opt.body !== undefined || opt.raw !== undefined) headers['x-if-admin'] = opt.noCsrf ? undefined : '1';
    if (headers['x-if-admin'] === undefined) delete headers['x-if-admin'];
    const r = await worker.fetch(req(path, { ...opt, headers, cookie: opt.cookie !== undefined ? opt.cookie : cookie }), env, ctx);
    await ctx.flush();
    const sc = r.headers.get('set-cookie');
    if (sc && !opt.keepCookie) { const m = sc.match(/ifadm=([^;]*)/); if (m) cookie = m[1] === 'x' ? '' : 'ifadm=' + m[1]; }
    const ct = r.headers.get('content-type') || '';
    const data = ct.includes('json') ? await r.json() : await r.text();
    return { status: r.status, data, headers: r.headers };
  }
  return { call, get cookie() { return cookie; }, set cookie(v) { cookie = v; }, ctx };
}

async function toBuf(b) {
  if (b == null) return Buffer.alloc(0);
  if (typeof b === 'string') return Buffer.from(b);
  if (b instanceof ArrayBuffer) return Buffer.from(b);
  if (ArrayBuffer.isView(b)) return Buffer.from(b.buffer, b.byteOffset, b.byteLength);
  if (b.getReader) { const r = b.getReader(); const ch = []; for (;;) { const { done, value } = await r.read(); if (done) break; ch.push(Buffer.from(value)); } return Buffer.concat(ch); }
  return Buffer.from(String(b));
}
export function makeR2() {
  const m = new Map(), mp = new Map();
  const obj = (key, buf, meta, range) => {
    let s = buf;
    let rg = null;
    if (range) { let off = range.offset ?? (range.suffix != null ? buf.length - range.suffix : 0); let len = range.length ?? (buf.length - off); s = buf.subarray(off, off + len); rg = { offset: off, length: len }; }
    return { key, size: buf.length, httpEtag: '"e' + buf.length + '"', range: rg, httpMetadata: meta, body: new Response(s).body, async text() { return s.toString(); } };
  };
  return {
    _m: m,
    async put(key, body, opt = {}) { const b = await toBuf(body); m.set(key, { b, meta: opt.httpMetadata }); return { key, size: b.length }; },
    async get(key, opt = {}) { const x = m.get(key); return x ? obj(key, x.b, x.meta, opt.range) : null; },
    async head(key) { const x = m.get(key); return x ? { key, size: x.b.length } : null; },
    async delete(key) { m.delete(key); },
    async createMultipartUpload(key, opt = {}) { const id = 'mp' + Math.random().toString(36).slice(2); mp.set(id, { key, parts: new Map(), meta: opt.httpMetadata }); return { key, uploadId: id }; },
    resumeMultipartUpload(key, id) {
      return {
        async uploadPart(n, body) { const u = mp.get(id); if (!u) throw new Error('no upload'); u.parts.set(n, await toBuf(body)); return { partNumber: n, etag: 'et' + n }; },
        async complete(parts) { const u = mp.get(id); const b = Buffer.concat(parts.map((p) => u.parts.get(p.partNumber))); m.set(key, { b, meta: u.meta }); mp.delete(id); return { key, size: b.length }; },
        async abort() { mp.delete(id); },
      };
    },
  };
}
