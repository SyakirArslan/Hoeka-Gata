/* Bandingkan daftar baris kontrol: mockup lama vs desain AMIS.
   Jalankan: node compare-rows.js
   Tidak dipakai runtime — hanya alat verifikasi desain. */
const fs = require('fs');
const path = require('path');

function scriptOf(file) {
  const t = fs.readFileSync(file, 'utf8');
  const s = t.indexOf('<scr' + 'ipt>');
  const e = t.lastIndexOf('</scr' + 'ipt>');
  return t.slice(s + 8, e);
}

// Kunci baris di file lama: P('key', ...) dan push({ key:'key' })
function keysOld(file) {
  const js = scriptOf(file);
  const out = [];
  let m;
  const reP = /P\(\s*'([A-Za-z0-9]+)'/g;
  while ((m = reP.exec(js))) out.push(m[1]);
  const reK = /key:\s*'([A-Za-z0-9]+)'/g;
  while ((m = reK.exec(js))) out.push(m[1]);
  return out;
}

// Kunci baris di file baru: P('grp','key', ...) dan ATOM('grp','key', ...)
function keysNew(file) {
  const js = scriptOf(file);
  const out = [];
  let m;
  const reP = /P\(\s*'[A-Za-z0-9_]+'\s*,\s*'([A-Za-z0-9]+)'/g;
  while ((m = reP.exec(js))) out.push(m[1]);
  const reA = /ATOM\(\s*'[A-Za-z0-9_]+'\s*,\s*'([A-Za-z0-9]+)'/g;
  while ((m = reA.exec(js))) out.push(m[1]);
  // baris yang didorong langsung: push({ key:'x'
  const reK = /rows\.push\(\{\s*key:\s*'([A-Za-z0-9]+)'/g;
  while ((m = reK.exec(js))) out.push(m[1]);
  // helper lokal (cur/g_pot/chk*) juga memakai key:'x' lewat P atau push
  const reK2 = /key:\s*'([A-Za-z0-9]+)'/g;
  while ((m = reK2.exec(js))) out.push(m[1]);
  return out;
}

const dir = __dirname;
const oldK = keysOld(path.join(dir, 'position-sizer-panel.html'));
const newK = keysNew(path.join(dir, 'amis-sizer-panel.html'));

const uniq = a => Array.from(new Set(a));
const o = uniq(oldK), n = uniq(newK);

const missing = o.filter(k => n.indexOf(k) < 0);
const extra = n.filter(k => o.indexOf(k) < 0);

console.log('kontrol di mockup lama :', o.length);
console.log('kontrol di desain AMIS :', n.length);
console.log('hilang                 :', missing.length, missing.length ? missing.join(', ') : '');
console.log('baru (tidak di PS)     :', extra.length, extra.length ? extra.join(', ') : '');
console.log(missing.length === 0 && extra.length === 0 ? 'RESULT: IDENTIK' : 'RESULT: BEDA');
