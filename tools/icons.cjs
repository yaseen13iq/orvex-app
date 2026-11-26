// يولّد أيقونات أورفيكس (الأساسية + البديلة) من هندسة الرمز الرسمية
const sharp = require(process.env.SHARP || 'sharp');
const fs = require('fs'), path = require('path');
const RING = 'M47.958,2 A48,48 0 1 1 -2,-47.958 V-25.923 A26,26 0 1 0 25.923,2 Z';
const VTX = 'M6,-52 H52 V-6 H30 V-30 H6 Z';
const G = 'translate(500.531,523.469) scale(5.734)';
const ICONS = [
  ['AppIcon', 'التوقيع', '#1C1F24', '#FFFFFF', '#B9BFC8'],
  ['IconObsidian', 'أسود', '#0B0C0E', '#FFFFFF', '#FFFFFF'],
  ['IconClassic', 'كلاسيك', '#0B0C0E', '#FFFFFF', '#B9BFC8'],
  ['IconWhite', 'أبيض', '#FFFFFF', '#0B0C0E', '#0B0C0E'],
  ['IconMist', 'ضباب', '#EEF0F3', '#0B0C0E', '#5F6772'],
  ['IconSilver', 'فضي', '#B9BFC8', '#0B0C0E', '#0B0C0E'],
  ['IconSteel', 'فولاذ', '#5F6772', '#FFFFFF', '#EEF0F3'],
  ['IconOutline', 'خطوط', '#0B0C0E', 'none', 'none', '#FFFFFF'],
  ['IconOutlineLight', 'خطوط فاتحة', '#FFFFFF', 'none', 'none', '#0B0C0E'],
  ['IconBlueprint', 'المخطط', '#0B0C0E', '#FFFFFF', '#B9BFC8', null, true],
];
function svg([, , bg, ring, vtx, stroke, grid]) {
  const st = stroke ? `stroke="${stroke}" stroke-width="3.4" stroke-linejoin="miter"` : '';
  let g = '';
  if (grid) { for (let i = 64; i < 1024; i += 64) g += `<path d="M${i} 0V1024M0 ${i}H1024" stroke="#2A2E35" stroke-width="2"/>`; g += `<circle cx="500.5" cy="523.5" r="275" fill="none" stroke="#3A4049" stroke-width="3"/>`; }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="${bg}"/>${g}<g transform="${G}"><path d="${RING}" fill="${ring}" ${st}/><path d="${VTX}" fill="${vtx}" ${st}/></g></svg>`;
}
(async () => {
  const out = process.argv[2];
  const previews = out;
  fs.mkdirSync(previews, { recursive: true });
  const meta = [];
  for (const ic of ICONS) {
    const dir = path.join(out, ic[0] + '.appiconset');
    fs.mkdirSync(dir, { recursive: true });
    await sharp(Buffer.from(svg(ic))).png().toFile(path.join(dir, 'icon-1024.png'));
    fs.writeFileSync(path.join(dir, 'Contents.json'), JSON.stringify({ images: [{ filename: 'icon-1024.png', idiom: 'universal', platform: 'ios', size: '1024x1024' }], info: { author: 'xcode', version: 1 } }, null, 1));
    // معاينة صغيرة تنعرض داخل التطبيق
    const pd = path.join(previews, ic[0] + 'Preview.imageset');
    fs.mkdirSync(pd, { recursive: true });
    await sharp(Buffer.from(svg(ic))).resize(240, 240).png().toFile(path.join(pd, 'p.png'));
    fs.writeFileSync(path.join(pd, 'Contents.json'), JSON.stringify({ images: [{ filename: 'p.png', idiom: 'universal' }], info: { author: 'xcode', version: 1 } }));
    meta.push({ id: ic[0], name: ic[1] });
  }
  fs.writeFileSync(path.join(out, '..', '..', '..', 'tools', 'icons.json'), JSON.stringify(meta, null, 1));
  // الشعار داخل التطبيق (متجه) — رمز وكلمة
  const logo = path.join(out, 'OrvexSymbol.imageset');
  fs.mkdirSync(logo, { recursive: true });
  fs.writeFileSync(path.join(logo, 'symbol.svg'), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><g transform="translate(48,52)"><path fill="#000" d="${RING}"/><path fill="#000" d="${VTX}"/></g></svg>`);
  fs.writeFileSync(path.join(logo, 'Contents.json'), JSON.stringify({ images: [{ filename: 'symbol.svg', idiom: 'universal' }], info: { author: 'xcode', version: 1 }, properties: { 'preserves-vector-representation': true, 'template-rendering-intent': 'template' } }));
  console.log('icons', meta.length);
})();
