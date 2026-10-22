# TradingView (Pine Script)

Repository ini berisi **dua** script Pine yang berbeda strategi. Keduanya `//@version=5` dan
`overlay=true`.

## Nama file vs isi (baca ini dulu)

| File | Isi sebenarnya | Baris | Status |
| --- | --- | --- | --- |
| `Source/HoekaGata_Indicator.pine` | `indicator("HoekaGata Wave3 Pro", ...)` — Elliott Wave 0-3 | 1112 | lengkap |
| `Source/HoekaGata_Indicator_Engulf.pine` | `indicator("Engulfing Breakout", ...)` — Engulfing Breakout | 291 | **draft** (engine masih TODO) |

Nama file tidak cocok dengan isinya. Sebelum memasang script, buka file dan lihat baris
`indicator(...)`, atau lihat judul di daftar indikator TradingView. Rekomendasi rename ada di bagian
akhir dokumen ini.

## Cara Memasang

1. TradingView → **Pine Editor** → **Open** → **New indicator**.
2. Hapus isi default, paste seluruh isi file Pine yang diinginkan.
3. **Save**, beri nama sesuai judul script (bukan nama file) agar tidak tertukar.
4. **Add to chart**.
5. Untuk alert: `Alert` → Condition = indikator → pilih salah satu alertcondition yang tersedia.

## Script 1 — Engulfing Breakout

**File:** `Source/HoekaGata_Indicator_Engulf.pine` · **Judul:** `Engulfing Breakout`

Script ini adalah padanan TradingView dari indikator MT5 (port 1:1). Yang sudah selesai: seluruh input,
warna, konstanta state, model statistik, dan panel. Yang **belum** ada: deteksi pola, perhitungan level,
state machine, drawing, dan alert — semuanya masih ditandai `TODO` di akhir file.

### Input (identik dengan MQL5)

| Group | Input Pine | Default | Padanan MQL5 |
| --- | --- | --- | --- |
| 1. ENGULFING PATTERN | `minBodyX` | `1.2` | `InpMinBodyX` |
| 1. ENGULFING PATTERN | `minBodyP` | `50.0` | `InpMinBodyP` |
| 2. ENTRY | `bufEntryX` | `0.10` | `InpBufEntryX` |
| 2. ENTRY | `bufSLX` | `0.10` | `InpBufSLX` |
| 2. ENTRY | `bodyBreakTol` | `0.00` | `InpBodyBreakTol` |
| 2. ENTRY | `cancelOpp` | `true` | `InpCancelOpp` |
| 3. RISK & REWARD | `rrRatio` | `2.0` | `InpRrRatio` |
| 4. DISPLAY | `showLines` | `true` | `InpShowLines` |
| 4. DISPLAY | `labelSize` | `Small` | `InpLabelSize` |
| 4. DISPLAY | `lineStyle` | `Dashed` | `InpLineStyle` |
| 4. DISPLAY | `extendB` | `3` | `InpExtendB` |
| 4. DISPLAY | `keepN` | `3` | `InpKeepN` |
| 4b. RESULTS SUMMARY | `showTable` | `true` | `InpShowTable` |
| 4b. RESULTS SUMMARY | `panelSize` | `Small` | `InpPanelSize` |
| 5. BODY-BREAK | `bodyBreakStyle` | `Dotted` | `InpBodyBreakStyle` |
| 6. COLORS | `cEntryLine`, `cSL`, `cTP`, `cBodyBreak`, `cBuyText`, `cSellText` | sama dengan MQL5 | `InpCEntryLine` … `InpCSellText` |

### Konstanta state

```text
STATE_NONE = 0
STATE_BUY_SETUP = 1     // menunggu break body
STATE_BUY_ARMED = 2     // break body kena, pending di wick
STATE_BUY_ACTIVE = 3    // pending terisi
STATE_SELL_SETUP = -1
STATE_SELL_ARMED = -2
STATE_SELL_ACTIVE = -3
```

### Model statistik

Variabel `statsNSig`, `statsNRun`, `statsNWin`, `statsNLos`, `statsNCancelled`, `statsNBuyRun`,
`statsNSellRun`, `statsBuyWins`, `statsBuyLoss`, `statsSellWins`, `statsSellLoss`,
`statsMaxTPStreak`, `statsMaxSLStreak`, `statsState` — 1:1 dengan struct `EngulfStats` di MQL5.

### Panel

Tabel `2 × 14` di `position.top_right`, latar `color.new(color.black, 100)` (transparan), border
`rgb(120,120,120)`:

| Row | Kiri | Kanan |
| --- | --- | --- |
| 0 | `Engulfing Breakout` (center, header) | — |
| 1 | `By Syakir Arslan (modified)` (center) | — |
| 2 | `SETUP` (center, header) | — |
| 3 | `R:R` | `1:<rrRatio>` |
| 4 | `Status` | `BUY` / `SELL` / `NONE` |
| 5 | `Cancelled` | `statsNCancelled` |
| 6 | `RESULTS` (center, header) | — |
| 7 | `Signals` | `statsNSig` |
| 8 | `Entries` | `statsNRun` |
| 9 | `Buy WR` | `<pct> (<statsNBuyRun>)` |
| 10 | `Sell WR` | `<pct> (<statsNSellRun>)` |
| 11 | `Max TP Run` | `statsMaxTPStreak` |
| 12 | `Max SL Run` | `statsMaxSLStreak` |
| 13 | `Overall: <pct>` (center) | — |

Perbedaan label dengan panel MQL5 (`Runs`, `Buy %`, `Sell %`, `Cancel`, `TP Streak`, `SL Streak`) dan
alasan status tidak memakai awalan `PENDING` dijelaskan di
[`Indicator_MT5.md`](Indicator_MT5.md#perbedaan-dengan-pine).

### TODO (belum diimplementasikan)

```text
f_detect_engulfing()    -> sigBuy / sigSell        (1:1 dengan DetectEngulfing)
f_compute_levels()      -> break / entry / sl / tp (1:1 dengan EngulfComputeLevels)
state machine loop      -> transisi 6 state + statistik
drawing helpers         -> garis & label Entry / SL / TP / Body-Break
alerts                  -> BREAK BODY TRIGGERED / ENTRY / TP HIT / SL HIT / CANCELLED
```

Saat ini `f_draw_panel()` dipanggil setiap bar hanya untuk memeriksa layout, sehingga statistik selalu
0 dan engine tidak menghasilkan sinyal.

## Script 2 — HoekaGata Wave3 Pro (Elliott Wave 0-3)

**File:** `Source/HoekaGata_Indicator.pine` · **Judul:** `HoekaGata Wave3 Pro`

Strategi Elliott Wave sederhana: tunggu Wave 0-1-2 valid, lalu entry saat harga menembus Wave 1
(Wave 3). Script ini **tidak** ada padanan MT5-nya di repository saat ini; MT5 hanya mengimplementasikan
Engulfing Breakout.

### Ide dasar

```text
Wave 0 -> 1 : impulse pertama (leg acuan)
Wave 1 -> 2 : koreksi masuk zona 50% - 61.8% dari leg 0-1
Wave 3      : entry saat harga menembus level Wave 1 (atau barrier Fibo opsional)
SL          : Fibo -0.27 dari leg 2 -> 3
TP          : Fibo 0.618 dari leg 2 -> 3
```

Arah signal bersifat kontrarian terhadap leg yang sedang berjalan: pola **downtrend** 0-3 yang selesai
menghasilkan **BUY**, pola **uptrend** 0-3 menghasilkan **SELL** (lihat blok `PROBABILITY STATS` di
source).

### Deteksi swing

- Pivot mentah: `ta.pivothigh(high, 2, 2)` dan `ta.pivotlow(low, 2, 2)` (`rawPivotLen = 2`, fixed).
- Swing baru diterima bila jaraknya dari swing sebelumnya antara `pivotLen` (default 8) dan
  `maxSwingBars` (default 100).
- Swing dengan tipe sama akan **diganti** bila harganya lebih ekstrem (high lebih tinggi / low lebih
  rendah).
- Maksimum 50 swing disimpan (yang tertua dibuang).

### Aturan Wave 2

- Leg acuan: dari `p1` (level 0%) ke `p0` (level 100%).
- Wave 2 valid bila `p2` berada di antara Fibo 0.5 dan Fibo 0.618 dari leg tersebut.
- `wave2FibTolerance` (default 0.05) hanya memperlebar batas 0.618, bukan batas 0.5.
- Wave 2 **invalid** bila harga menembus 0.618 (di luar toleransi) di antara swing 1 dan swing 2
  (atau 1 dan 3 pada pengecekan lanjutan).

### Dua jalur entry

| Jalur | Kapan aktif | Syarat |
| --- | --- | --- |
| **Aggressive** (default, karena `showEarlyWave3Entry = true` dan `useAggressiveWave3` mengikutinya) | Wave 2 belum menjadi pivot; harga sudah masuk zona 0.5–0.618 dan menembus Wave 1 | `touchEntry` pada level Wave 1 (atau `entryTriggerFibLevel` bila `Entry Barrier` aktif), jarak Wave 3 antara `pivotLen` dan `maxSwingBars`, slope paralel valid, jarak antar entry `>= minBarsBetweenEntry` |
| **Konfirmasi 0-3** (hanya bila aggressive dimatikan) | Empat swing bergantian 0-1-2-3 sudah terkonfirmasi | tipe swing bergantian, `p2 < p0` (down) / `p2 > p0` (up), `p3 < p1` (down) / `p3 > p1` (up), Wave 2 valid & tidak breached, slope paralel valid, `p3` menembus Fibo 1 (atau barrier) |

Karena `showEarlyWave3Entry` di-hardcode `true` dan `useAggressiveWave3 = showEarlyWave3Entry`, jalur
konfirmasi 0-3 saat ini **tidak pernah jalan**. Input `Entry Barrier` / `Trigger Fibo` tetap relevan
karena dipakai jalur aggressive.

### Level SL dan TP

```text
SL = f_fib_price(p2, p3, -0.270)   -> 0.27 panjang leg 2-3 di luar p3
TP = f_fib_price(p2, p3,  0.618)   -> 0.618 panjang leg 2-3 di luar p3
```

dengan `f_fib_price(a, b, level) = b + (a - b) * level`, sehingga level di luar `p3` berada pada arah
leg (SL untuk BUY di bawah `p3`, TP di atas `p3`).

### Aturan slope paralel

`f_parallel_valid()` membandingkan slope `(0 -> 2)` dan `(1 -> 3)`:

```text
slope02 = (p2 - p0) / max(|i2 - i0|, 1)
slope13 = (p3 - p1) / max(|i3 - i1|, 1)
valid    = arah sama (slope02 * slope13 > 0) dan selisih relatif <= parallelTolerance
```

Nonaktif bila `Slope Rule` dimatikan. Tujuannya menolak struktur Wave 3 yang "bengkok" terhadap
trendline paralel 0-2 dan 1-3.

### Input

| Group | Input | Default | Arti |
| --- | --- | --- | --- |
| Config / Rules | `Pivot Min` (`pivotLen`) | 8 | jarak minimum antar swing |
| Config / Rules | `Pivot Max` (`maxSwingBars`) | 100 | jarak maksimum antar swing |
| Config / Rules | `Wave 2 Fibo Tol` | 0.05 | toleransi batas 0.618 (fraksi panjang leg) |
| Config / Rules | `Entry Barrier` | `false` | pakai barrier Fibo sebagai trigger, bukan level Wave 1 |
| Config / Rules | `Trigger Fibo` | 1.272 | level barrier (1.0–1.618) |
| Config / Rules | `Slope Rule` | `true` | aktifkan validasi slope paralel |
| Config / Rules | `Slope Tol` | 0.15 | toleransi selisih slope relatif |
| Config / Rules | `Entry Gap (Candle)` | 30 | jarak minimum antar entry (bar) |
| Alerts | `BUY Alert` / `SELL Alert` | `true` / `true` | izin alert per arah |
| Display | `Waves Line` | `true` | gambar garis Wave 0-1-2-3 |
| Display | `Trendline` | `true` | gambar trendline paralel 0-2 dan 1-3 |
| Display | `Fibo Line` | `true` | gambar level Fibo Wave 2, 1.618, -0.27, dan target Wave 4 |
| Display | `1.618 Line` | `true` | tampilkan khusus level 1.618 |
| General | `Mode` | `Latest only` | `Latest only` menghapus drawing lama setiap setup baru; `History` menyimpannya |
| General | `Max Objects` | 300 | batas jumlah label dan garis (50–500) |
| General | `Width` | 1 | lebar garis (1–5) |
| General | `Label` | `Tiny` | ukuran label: `Tiny` / `Small` / `Normal` |
| General | `HoekaGata Panel` | `true` | tampilkan panel statistik |
| Colors | `Down Wave`, `Up Wave`, `BUY Entry`, `SELL Entry`, `Label`, `Wave 2 Fibo`, `Entry 1.618`, `Target Fibo`, `Neutral` | merah, lime, aqua, orange, abu, kuning, fuchsia, biru, putih | warna drawing |

### Objek yang digambar

| Objek | Keterangan |
| --- | --- |
| Garis Wave 0-1, 1-2, 2-3 | warna `Down Wave` / `Up Wave` |
| Trendline paralel (0→2) dan (1→3) | diproyeksikan sampai bar Wave 3, warna netral |
| Level Fibo 0.618 dan 0.5 leg 0-1 | dashed, warna `Wave 2 Fibo` |
| Level 1.618 leg 1-2 | dashed + label `1.618 <harga>` |
| Trigger line (opsional) | dashed + label `TRIGGER <level> <harga>` saat `Entry Barrier` aktif |
| Garis entry + label | solid + label `BUY ENTRY` / `SELL ENTRY` beserta harga |
| Level -0.27 + label | warna `Target Fibo` (dipakai sebagai SL statistik) |
| Level 0.618 dan 0.786 leg 2-3 | target Wave 4, warna `Target Fibo` + label |
| Label angka `0`, `1`, `2` | penanda swing |

Anti-duplikasi memakai array `drawKeys` (setiap garis/label punya key unik), dan jumlah objek dipangkas
ke `Max Objects` per jenis.

### Panel statistik

Tabel `2 × 12` di kanan atas:

| Row | Isi |
| --- | --- |
| 0 | `HoekaGata Wave3 Pro` (center) |
| 1 | `by Syakir Arslan` (center) |
| 2 | `Pivot Range` → `<pivotLen> / <maxSwingBars>` |
| 3 | `Trades` → total trade virtual |
| 4 | `Closed / Open` |
| 5 | `Buy` → `<winrate> (<total buy>)` |
| 6 | `Sell` → `<winrate> (<total sell>)` |
| 7 | `TP Hits` |
| 8 | `SL Hits` |
| 9 | `TP Streak` |
| 10 | `SL Streak` |
| 11 | `Overall: <winrate>` (center) |

Statistik dihitung dari trade virtual: setiap signal menyimpan key unik (`BUY_<i1>_<i3>` /
`SELL_<i1>_<i3>`), lalu hasil dicek bar demi bar setelah entry. **SL dicek lebih dulu** bila TP dan SL
kena pada bar yang sama.

### Alert

```text
alert(<SIDE> | Entry: <harga> | SL: <harga> | TP: <harga> | <ticker> | TF <timeframe>,
      alert.freq_once_per_bar)
```

Tiga `alertcondition` tersedia: `Wave 3 Terbentuk`, `Wave 3 BUY Terbentuk`, `Wave 3 SELL Terbentuk`.
Alert diaktifkan melalui dialog Alert TradingView; input `BUY Alert` / `SELL Alert` hanya menjadi filter.

## Perbandingan Pine vs MT5

| Aspek | `HoekaGata_Indicator_Engulf.pine` | Indikator MT5 |
| --- | --- | --- |
| Strategi | Engulfing Breakout | Engulfing Breakout |
| Kelengkapan | draft (input + panel) | lengkap |
| ATR | `ta.atr(14)` (RMA) | rata-rata sederhana TR 14 bar |
| Panel | tabel 2×14 | objek chart, 13 baris + footer terpisah |
| Label statistik | `Entries`, `Buy WR`, `Sell WR`, `Cancelled`, `Max TP Run`, `Max SL Run` | `Runs`, `Buy %`, `Sell %`, `Cancel`, `TP Streak`, `SL Streak` |
| Alert | belum ada | 5 alert (`Alert()`) |
| Integrasi | manual (mata manusia) | buffer + `GlobalVariable` untuk EA |

| Aspek | `HoekaGata_Indicator.pine` (Wave3 Pro) | MT5 |
| --- | --- | --- |
| Strategi | Elliott Wave 0-3 | tidak ada implementasi MT5 |
| Entry | break Wave 1 / barrier Fibo | — |
| SL / TP | Fibo -0.27 / 0.618 | — |
| Panel | tabel 2×12 | — |

## Rekomendasi Rename

Agar tidak tertukar lagi:

```text
Source/HoekaGata_Indicator.pine        -> Source/HoekaGata_Wave3Pro.pine
Source/HoekaGata_Indicator_Engulf.pine -> Source/HoekaGata_EngulfingBreakout.pine
```

Setelah rename, perbarui tautan di `README.md` dan dokumen ini. Script yang sudah tersimpan di
TradingView tidak terpengaruh karena TradingView menyimpan salinan kode, bukan menaut ke file.

## Checklist TradingView

1. Script yang dipasang judulnya sesuai strategi yang diinginkan (`Engulfing Breakout` atau
   `HoekaGata Wave3 Pro`).
2. Untuk Engulfing: panel muncul dengan 14 baris; angka statistik masih 0 karena engine belum ada.
3. Untuk Wave3 Pro: garis Wave, trendline paralel, level Fibo, dan label entry muncul saat pola
   terdeteksi; panel menampilkan `Pivot Range` sesuai input.
4. Alert TradingView dibuat dari `alertcondition` yang sesuai, bukan dari input script.

