// سيرفر محلي لاختبارات التطبيق على المحاكي: نفس كود الموقع + بيانات تجريبية
import http from 'node:http';
import { makeEnv, makeCtx, makeClient } from './harness.mjs';
import { seed } from './seed.mjs';
const W = (await import('./worker.mjs')).default;
const port = Number(process.argv[2] || 8787);
const env = makeEnv();
await seed(W, env);

const joe = makeClient(W, env);
await joe.call('/admin/api/setup', { body: { code: 'setup-code-xyz', username: 'joe', password: 'StrongPass1', name: 'Joe' } });
await joe.call('/admin/api/users', { body: { name: 'سارة', username: 'sara', password: 'SaraPass123', perms: { stats: true, live: true, 'gate.state': true, content: true, 'history.view': true }, max_devices: 2 } });
await joe.call('/admin/api/notes', { body: { title: 'أهلًا بأورفيكس', body: 'هذا إشعار تجريبي من لوحة التحكم.', level: 'info', target: 'all' } });
await joe.call('/admin/api/notes', { body: { title: 'تنبيه: راجع الأسعار', body: 'سعر الباقة الشهرية تغيّر.', level: 'warn', target: 'all' } });
await joe.call('/admin/api/config/patch', { body: { ops: [{ p: ['geo'], v: { enabled: false, countries: ['RU'], ips: ['9.9.9.0/24'], action: 'block', message: { ar: 'الموقع غير متاح في منطقتك.', en: 'Not available.' }, exemptAdmin: true } }], what: 'إعداد الحظر' } });
// ملف تجريبي
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');
for (const [name, type, data] of [['logo.png', 'image/png', png], ['menu-ramadan.pdf', 'application/pdf', Buffer.alloc(4096, 1)], ['intro.mp4', 'video/mp4', Buffer.alloc(9000, 2)]]) {
  const ini = await joe.call('/admin/api/files/init', { body: { name, size: data.length, type } });
  if (ini.data && ini.data.id) await joe.call(`/admin/api/files/${ini.data.id}/body`, { method: 'PUT', raw: data });
}
{
  const ipa = Buffer.alloc(20000, 7);
  const ini = await joe.call('/admin/api/files/init', { body: { name: 'ORVEX-2.1.0-3.ipa', size: ipa.length, type: 'application/octet-stream' } });
  await joe.call(`/admin/api/files/${ini.data.id}/body`, { method: 'PUT', raw: ipa });
  const u = await joe.call('/admin/api/app/update', { body: { fileId: ini.data.id, version: '2.1.0', build: 9, notes: 'تحسينات في سرعة التطبيق\nإضافة تقارير أسبوعية للزوار\nإصلاح أخطاء بسيطة' } });
  console.log('update', u.status);
}
console.log('seeded');
// يبقي المتصفحين التجريبيين «أونلاين»
setInterval(() => { try { env.DB._db.prepare('UPDATE presence SET at = ?').run(Date.now() - 5000); } catch (e) {} }, 15000);

http.createServer(async (q, s) => {
  const chunks = []; for await (const c of q) chunks.push(c);
  const body = chunks.length ? Buffer.concat(chunks) : undefined;
  const headers = new Headers(); for (const [k, v] of Object.entries(q.headers)) headers.set(k, Array.isArray(v) ? v.join(', ') : v);
  headers.set('cf-connecting-ip', '5.5.5.5');
  const r = new Request('http://127.0.0.1:' + port + q.url, { method: q.method, headers, body: ['GET', 'HEAD'].includes(q.method) ? undefined : body });
  Object.defineProperty(r, 'cf', { value: { country: 'IQ', city: 'Erbil', latitude: '36.19', longitude: '44.01' } });
  const ctx = makeCtx();
  try {
    const res = await W.fetch(r, env, ctx);
    const h = {}; res.headers.forEach((v, k) => { if (k !== 'set-cookie') h[k] = v; });
    s.writeHead(res.status, h); s.end(Buffer.from(await res.arrayBuffer()));
    if (!q.url.startsWith('/admin/api/ping')) console.log(q.method, q.url, res.status);
  } catch (e) { console.log('ERR', q.url, e); s.writeHead(500); s.end(String(e)); }
  ctx.flush();
}).listen(port, '127.0.0.1', () => console.log('listening', port));
