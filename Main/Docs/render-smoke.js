/* Smoke test render tanpa browser: jalankan skrip panel di atas DOM tiruan.
   Membuktikan rowsFor()/renderPanel() tidak error dan setiap tab menghasilkan
   jumlah baris yang diharapkan. Bukan pengganti cek visual di browser.
   Jalankan: node render-smoke.js */
const fs = require('fs');
const path = require('path');

function load(file) {
  const html = fs.readFileSync(path.join(__dirname, file), 'utf8');
  const s = html.indexOf('<scr' + 'ipt>'), e = html.lastIndexOf('</scr' + 'ipt>');
  return html.slice(s + 8, e);
}

/* --- DOM tiruan minimal --- */
const nodes = {};
function el(id) {
  if (!nodes[id]) nodes[id] = {
    id: id, innerHTML: '', textContent: '',
    classList: { toggle() {}, add() {}, remove() {} },
    querySelectorAll: () => [], querySelector: () => null
  };
  return nodes[id];
}
const document = {
  getElementById: el,
  querySelectorAll: () => [],
  querySelector: () => null,
  addEventListener: () => {},
  body: { classList: { toggle() {} } }
};
const window = { addEventListener: () => {} };
const location = { search: '' };
const URLSearchParams = class { get() { return null; } };

/* --- eksekusi: file baru (punya renderPanel) dan file lama (hanya rowsFor) --- */
const apiNew = new Function('document', 'window', 'location', 'URLSearchParams',
  load('amis-sizer-panel.html') + '\nreturn { rowsFor: rowsFor };'
)(document, window, location, URLSearchParams);

const apiOld = new Function('document', 'window', 'location', 'URLSearchParams',
  load('position-sizer-panel.html') + '\nreturn { rowsFor: rowsFor };'
)(document, window, location, URLSearchParams);

/* --- verifikasi: jumlah baris per tab harus sama dengan mockup lama --- */
const TABS = ['main', 'risk', 'margin', 'swaps', 'trading'];
/* file baru mengelompokkan baris per kartu ({rows:[...]}), file lama datar;
   keduanya dinormalkan menjadi satu daftar baris per tab. */
const flat = (api, tab) => {
  const out = [];
  api.rowsFor(tab).forEach(g => {
    if (g && Array.isArray(g.rows)) out.push.apply(out, g.rows);
    else if (g && g.cells) out.push(g);
  });
  return out;
};

let bad = 0;
TABS.forEach(tab => {
  const a = flat(apiOld, tab).length, b = flat(apiNew, tab).length;
  const ok = a === b;
  if (!ok) bad++;
  console.log('  tab ' + tab.padEnd(8) + ' lama=' + String(a).padStart(3) +
              '  baru=' + String(b).padStart(3) + '  ' + (ok ? 'OK' : 'MISMATCH'));
});
console.log('  renderPanel() jalan tanpa error =',
            nodes['mount'] && nodes['mount'].innerHTML.length > 500);
console.log('  tabel pemetaan terisi =',
            nodes['mapTable'] && /baris kontrol/.test(nodes['mapTable'].innerHTML));
console.log('  tabel geometri terisi =',
            nodes['geoTable'] && nodes['geoTable'].innerHTML.length > 1000);
console.log(bad === 0 ? 'RESULT: OK' : 'RESULT: FAIL');
process.exit(bad === 0 ? 0 : 1);
