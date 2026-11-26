import crypto from 'node:crypto';
import { makeCtx, req } from './harness.mjs';
export async function seed(W, env) {
  const db = env.DB._db;
  // trigger table creation
  const c = makeCtx();
  await W.fetch(req('/api/pulse', { method: 'POST', body: { v: 'c'.repeat(24), pv: 1, p: '/' } }), env, c); await c.flush();
  const day = (o) => new Date(Date.now() + 3 * 3600e3 - o * 864e5).toISOString().slice(0, 10);
  const R = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
  const cities = [['IQ', 'Erbil', 36.19, 44.01, 30], ['IQ', 'Baghdad', 33.31, 44.36, 28], ['IQ', 'Basra', 30.51, 47.78, 9], ['IQ', 'Mosul', 36.34, 43.13, 7], ['IQ', 'Sulaymaniyah', 35.56, 45.43, 6], ['IQ', 'Kirkuk', 35.47, 44.39, 5], ['IQ', 'Najaf', 32.0, 44.33, 4], ['IQ', 'Duhok', 36.87, 43.0, 3], ['SE', 'Stockholm', 59.33, 18.06, 2], ['DE', 'Berlin', 52.52, 13.4, 2], ['TR', 'Istanbul', 41.01, 28.97, 2], ['AE', 'Dubai', 25.2, 55.27, 1], ['US', 'Detroit', 42.33, -83.05, 1], ['GB', 'London', 51.5, -0.12, 1]];
  const ins = db.prepare('INSERT INTO stats (day,k,n) VALUES (?,?,?) ON CONFLICT(day,k) DO UPDATE SET n = n + excluded.n');
  const geo = db.prepare('INSERT OR IGNORE INTO geo (k,cc,city,region,lat,lng) VALUES (?,?,?,?,?,?)');
  for (const ct of cities) geo.run(ct[0] + '|' + ct[1], ct[0], ct[1], '', ct[2], ct[3]);
  for (let o = 0; o < 95; o++) {
    const d = day(o), wk = new Date(d).getUTCDay(), base = R(140, 260) * (wk === 5 ? 1.4 : 1) * (o < 7 ? 1.3 : 1);
    const views = Math.round(base), uniq = Math.round(views * .72), nw = Math.round(uniq * .38);
    ins.run(d, 'views', views); ins.run(d, 'uniq', uniq); ins.run(d, 'new', nw); ins.run(d, 'peak', R(6, 21));
    for (let h = 0; h < 24; h++) { const w = [2, 1, 1, 0, 0, 0, 1, 2, 3, 4, 5, 6, 6, 6, 7, 8, 9, 10, 12, 14, 15, 13, 9, 5][h]; ins.run(d, 'h:' + String(h).padStart(2, '0'), Math.round(views * w / 139)); }
    const tw = cities.reduce((a, b) => a + b[4], 0);
    for (const ct of cities) ins.run(d, 'ci:' + ct[0] + '|' + ct[1], Math.round(views * ct[4] / tw));
    const cc = {}; for (const ct of cities) cc[ct[0]] = (cc[ct[0]] || 0) + ct[4];
    for (const k in cc) ins.run(d, 'c:' + k, Math.round(views * cc[k] / tw));
    ins.run(d, 'd:mob', Math.round(views * .94)); ins.run(d, 'd:desk', Math.round(views * .05)); ins.run(d, 'd:tab', Math.round(views * .01));
    ins.run(d, 's:ig', Math.round(views * .91)); ins.run(d, 's:direct', Math.round(views * .06)); ins.run(d, 's:google', Math.round(views * .02)); ins.run(d, 's:internal', Math.round(views * .01));
    ins.run(d, 'b:instagram', Math.round(views * .86)); ins.run(d, 'b:safari', Math.round(views * .07)); ins.run(d, 'b:chrome', Math.round(views * .07));
    ins.run(d, 'o:ios', Math.round(views * .58)); ins.run(d, 'o:android', Math.round(views * .37)); ins.run(d, 'o:windows', Math.round(views * .05));
    ins.run(d, 'l:ar', Math.round(views * .9)); ins.run(d, 'l:en', Math.round(views * .07)); ins.run(d, 'l:ku', Math.round(views * .03));
    ins.run(d, 'p:/', Math.round(views * .95)); ins.run(d, 'p:/en', Math.round(views * .05));
    ins.run(d, 'e:cta', Math.round(views * .08)); ins.run(d, 'e:rem', Math.round(views * .05)); ins.run(d, 'e:train', Math.round(views * .03)); ins.run(d, 'e:join', Math.round(views * .02));
  }
  const now = Date.now();
  const pres = db.prepare('INSERT OR REPLACE INTO presence (vid, at) VALUES (?,?)');
  const live = db.prepare('INSERT OR REPLACE INTO live2 (vid,at,cc,city,dev,os,br,src,page,lang) VALUES (?,?,?,?,?,?,?,?,?,?)');
  const L = [['IQ', 'Erbil', 'mob', 'ios', 'instagram', 'ig'], ['IQ', 'Baghdad', 'mob', 'android', 'instagram', 'ig'], ['IQ', 'Baghdad', 'mob', 'ios', 'instagram', 'ig'], ['IQ', 'Basra', 'mob', 'android', 'chrome', 'direct'], ['SE', 'Stockholm', 'mob', 'ios', 'safari', 'ig'], ['IQ', 'Erbil', 'desk', 'windows', 'chrome', 'google'], ['IQ', 'Sulaymaniyah', 'mob', 'ios', 'instagram', 'ig']];
  L.forEach((x, i) => { const v = crypto.randomBytes(12).toString('hex'); pres.run(v, now - i * 7000); live.run(v, now - R(40, 900) * 1000, ...x, '/', 'ar'); });
  for (let i = 0; i < 23; i++) env.SITE._m.set('wait:' + (70000 + i), JSON.stringify({ id: 70000 + i, name: ['علي حسن', 'زهراء', 'Mohammed', 'حسين كريم', 'سارة', 'مصطفى'][i % 6], username: i % 3 ? 'user_' + i : '', at: now - (23 - i) * 36e5 * 5 }));
}
