# Indikator MT5 — HoekaGata Engulfing Breakout

Dokumen ini menjelaskan indikator MetaTrader 5 `HoekaGataIndicator.mq5` secara lengkap: arsitektur
modul, aturan deteksi pola, matematika setiap level, state machine, objek chart, alert, panel
statistik, kontrak signal untuk EA, dan referensi seluruh input.

- **File utama:** `Main/MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5`
- **Nama tampilan chart:** `Engulfing Breakout <SYMBOL> <TF>` (mis. `Engulfing Breakout XAUUSD H1`)
- **Versi:** 2.03
- **Aturan entry:** pemicu BREAK BODY, fill, dan cancel semuanya dievaluasi di **bar pola** (A = P) —
  lihat [Aturan A = P](#aturan-a--p-v202)
- **Buffer:** 4 (`DRAW_NONE`), **plot:** 2
- **Prefix objek chart:** `HoekaGATA_Engulf_`
- **Sumber aturan:** `Source/HoekaGata_Indicator_Engulf.pine` (lihat [`TradingView.md`](TradingView.md))

## Arsitektur

File `.mq5` sengaja dibuat tipis. Semua logika berada di `Includes/`, sehingga indikator mudah
dibaca dan diuji per bagian.

| File | Tanggung jawab |
| --- | --- |
| `HoekaGataIndicator.mq5` | Properti program, validasi input di `OnInit`, binding 4 buffer, `OnCalculate`, `OnChartEvent`, publish/clear `GlobalVariable`, `OnDeinit` |
| `Includes/HoekaGataIndicator_Config.mqh` | Enum input, seluruh `input`, deklarasi buffer, `PREFIX`, konstanta state (`STATE_NONE` … `STATE_SELL_ACTIVE`) |
| `Includes/HoekaGataIndicator_Engulf.mqh` | `EngulfAtrAt()` dan `DetectEngulfing()` (pola + filter body) |
| `Includes/HoekaGataIndicator_Core.mqh` | `EngulfComputeLevels()`, `RecalculateEngulfing()` (replay penuh + state machine + buffer + alert), helper nama objek |
| `Includes/HoekaGataIndicator_Drawing.mqh` | Struct `EngulfSetup`, pembuatan/pemindahan garis dan label, style, format harga/probabilitas, hapus objek per prefix |
| `Includes/HoekaGataIndicator_Panel.mqh` | Struct `EngulfStats`, geometri panel, cell/rule/frame/footer, cache snapshot untuk repaint |

Urutan `#include` di file utama: `Config` → `Drawing` → `Panel` → `Engulf` → `Core`. Urutan ini
penting karena `Panel` memakai tipe dan konstanta dari `Config`/`Drawing`, sedangkan `Core` memakai
ketiganya.

## Lifecycle Indikator

### OnInit

1. Validasi input; bila gagal, `Print()` alasan lalu return `INIT_PARAMETERS_INCORRECT`:
   - `InpMinBodyX >= 0`
   - `0 <= InpMinBodyP <= 100`
   - `InpRrRatio > 0`
   - `InpKeepN >= 1`
   - `InpExtendB >= 0`
2. Bind buffer: `0` BUY, `1` SELL, `2` SL, `3` TP, semuanya `INDICATOR_DATA` dan
   `ArraySetAsSeries(false)` (index 0 = bar paling kiri).
3. Set `PLOT_DRAW_TYPE = DRAW_NONE` dan `PLOT_EMPTY_VALUE = EMPTY_VALUE` untuk kedua plot.
4. Set short name dan digits.

### OnCalculate

```text
rates_total < 20                      -> return 0 (butuh bar sebelumnya + warm-up ATR)
set semua array non-series
signature = rates_total + time/OHLC bar terakhir
signature sama seperti call sebelumnya -> hanya publish heartbeat, return rates_total
bersihkan 4 buffer (EMPTY_VALUE)
hapus objek PREFIX kecuali objek panel
pass 1: RecalculateEngulfing(paint = false)     -> hitung jumlah setup
EngulfPaintFromOrdinal = totalSetup - InpKeepN
pass 2: RecalculateEngulfing(paint = true)      -> gambar hanya setup terbaru
publish signal state, simpan signature, ChartRedraw
```

Dua hal yang membuat indikator tetap ringan pada chart besar:

- **Change detection.** `RecalculateEngulfing()` adalah replay penuh semua bar. Di antara dua tick
  hanya bar yang sedang berjalan bisa berubah, sehingga `rates_total` + OHLC bar terakhir adalah
  signature lengkap. Bila signature sama, tidak ada perhitungan ulang.
- **Two-pass replay.** Pass pertama murni aritmetika (menghitung setup), pass kedua hanya membuat
  objek untuk setup terbaru (`InpKeepN`). Tanpa ini, replay akan membuat lalu menghapus ratusan objek
  setiap kali chart di-scroll.

### OnChartEvent

`CHARTEVENT_CHART_CHANGE` dan `CHARTEVENT_MOUSE_WHEEL` memanggil `EngulfPanelRepaintCached()` lalu
`ChartRedraw()`. Alasannya: objek panel ber-anchor `CORNER_RIGHT_UPPER`, dan MT5 tidak memanggil
`OnCalculate` saat chart di-scroll/di-zoom/di-resize, sehingga tanpa repaint panel bisa tampak
"hilang" mengikuti frame tick terakhir.

### OnDeinit

`ClearPublishedSignalState()` menghapus seluruh `GlobalVariable` milik chart ini, lalu
`EngulfDeleteByPrefix(PREFIX)` menghapus semua objek indikator (garis, label, panel).

## Aturan Deteksi Pola

Deteksi dievaluasi pada bar `i` (bar tertutup) dengan referensi bar `i-1`.

```text
o1 = open[i-1]     c1 = close[i-1]
range1 = high[i-1] - low[i-1]
body   = |close[i] - open[i]|
```

**Engulf (mode loose):**

- `engBull = close[i] > high[i-1]` → close menembus wick atas bar sebelumnya.
- `engBear = close[i] < low[i-1]`  → close menembus wick bawah bar sebelumnya.

Mode *strict* (open ikut menembus wick) sudah dihapus; loose adalah satu-satunya mode.

**Filter body:**

| Flag | Rumus | Arti |
| --- | --- | --- |
| `okBodyX` | `body >= range1 * InpMinBodyX` (atau `body > 0` bila `range1 == 0`) | body minimal sekian kali range bar sebelumnya |
| `okBodyP` | `range1 > 0 && body / range1 * 100 >= InpMinBodyP` | body minimal sekian persen dari range sebelumnya |

**Signal:**

```text
sigBuy  = close[i] > open[i] && c1 < o1 && engBull && okBodyX && okBodyP
sigSell = close[i] < open[i] && c1 > o1 && engBear && okBodyX && okBodyP
```

Satu bar tidak mungkin bullish dan bearish sekaligus, jadi hasilnya selalu satu arah atau tidak ada.

### ATR

`EngulfAtrAt(index, high, low, close, 14)` menghitung **rata-rata sederhana True Range** dari bar
tertutup terakhir:

```text
TR[i] = max(high[i], close[i-1]) - min(low[i], close[i-1])
ATR   = average(TR) atas 14 bar berakhir di index
```

Pine memakai `ta.atr()` (RMA). Perbedaan ini disengaja: rata-rata sederhana bersifat deterministik
untuk satu bar berapa pun histori yang sudah ter-download MT5, sehingga level tidak berubah saat
chart di-scroll.

## Matematika Level (BREAK BODY / Entry / SL / TP)

Semua dihitung di `EngulfComputeLevels()`. `ATR` = `EngulfAtrAt()` pada bar signal, `POINT` =
`SymbolInfoDouble(_Symbol, SYMBOL_POINT)`.

```text
bodyTopPrev = max(open[i-1], close[i-1])
bodyBotPrev = min(open[i-1], close[i-1])

BUY
  BREAK BODY = bodyTopPrev + InpBodyBreakTol * ATR
  ENTRY      = high[i-1]  + InpBufEntryX     * ATR     (pending di atas wick)
  SL         = low[i-1]   - InpBufSLX        * ATR     (di bawah wick berlawanan)
  RISK       = |ENTRY - SL|
  TP         = ENTRY + InpRrRatio * RISK

SELL
  BREAK BODY = bodyBotPrev - InpBodyBreakTol * ATR
  ENTRY      = low[i-1]   - InpBufEntryX     * ATR
  SL         = high[i-1]  + InpBufSLX        * ATR
  RISK       = |ENTRY - SL|
  TP         = ENTRY - InpRrRatio * RISK
```

**Guard level** (agar level tidak saling menyalip):

| Kondisi | Koreksi |
| --- | --- |
| BUY dan `BREAK BODY >= ENTRY` | `BREAK BODY = ENTRY - 1 point` |
| SELL dan `BREAK BODY <= ENTRY` | `BREAK BODY = ENTRY + 1 point` |
| BUY dan `SL >= ENTRY` | `SL = ENTRY - max(InpBufSLX*ATR, 2*POINT)` |
| SELL dan `SL <= ENTRY` | `SL = ENTRY + max(InpBufSLX*ATR, 2*POINT)` |

**Guard setup:** setup hanya diterima bila `RISK > 1 point` **dan** `|TP - ENTRY| > 1 point`.
Setup yang gagal guard tetap memunculkan garis BREAK BODY, tetapi tidak dihitung sebagai setup pada
panel dan tidak mendapat garis Entry/SL/TP.

**Contoh BUY** (XAUUSD, `InpMinBodyX=1.2`, `InpMinBodyP=50`, `InpBufEntryX=InpBufSLX=0.10`,
`InpBodyBreakTol=0`, `InpRrRatio=2`, ATR=4.00):

```text
bar i-1 (bearish) : open 2400.00  close 2392.00  high 2401.00  low 2391.00
bar i   (bullish) : open 2392.50  close 2403.00

range1 = 10.00   body = 10.50  -> okBodyX: 10.50 >= 12.00 ? TIDAK  -> tidak ada signal
```

Dengan `InpMinBodyX = 1.0`, body 10.50 >= 10.00 lolos dan `okBodyP = 105% >= 50%` lolos:

```text
BREAK BODY = 2400.00 + 0        = 2400.00
ENTRY      = 2401.00 + 0.40     = 2401.40
SL         = 2391.00 - 0.40     = 2390.60
RISK       = 10.80              TP = 2401.40 + 21.60 = 2423.00
```

Urutan logika ini menjelaskan kenapa `InpMinBodyX` dan `InpMinBodyP` adalah filter paling berpengaruh:
keduanya menentukan apakah bar dianggap pola sama sekali.

## State Machine

Enam state (nilai `state` disimpan pada `EngulfStats.state` dan ditampilkan di panel):

| State | Nilai | Arti | Keluar ke |
| --- | --- | --- | --- |
| `STATE_NONE` | `0` | tidak ada setup | `BUY_SETUP` / `SELL_SETUP` saat pola terdeteksi |
| `STATE_BUY_SETUP` | `1` | pola BUY terdeteksi di bar `i` | `BUY_ARMED` bila `high[i] >= BREAK BODY`; `NONE` bila BREAK BODY tidak tersentuh |
| `STATE_BUY_ARMED` | `2` | trigger body-break kena di bar yang sama | `BUY_ACTIVE` bila `high[i] >= ENTRY`; `NONE` bila `close[i] <= ENTRY` (cancel saat bar pola close) |
| `STATE_BUY_ACTIVE` | `3` | entry terisi, menunggu hasil | `NONE` saat TP atau SL kena |
| `STATE_SELL_SETUP` | `-1` | cermin untuk SELL | `SELL_ARMED` bila `low[i] <= BREAK BODY` |
| `STATE_SELL_ARMED` | `-2` | trigger SELL kena | `SELL_ACTIVE` bila `low[i] <= ENTRY`; `NONE` bila `close[i] >= ENTRY` |
| `STATE_SELL_ACTIVE` | `-3` | entry SELL terisi | `NONE` saat TP atau SL kena |

### Aturan A = P (v2.02)

Sejak v2.02 seluruh siklus setup selesai di **bar pola** (bar yang membentuk engulfing):

```
bar pola i:  CREATE  ->  BREAK BODY (high >= pBreak)  ->  FILL (high >= pEntry)
                                                        \->  CANCEL (close <= pEntry)
```

- `SETUP` dan `ARMED` **tidak pernah bertahan** ke bar berikutnya, jadi dengan default
  (`InpAllowFormingBar = false`) panel tidak pernah menampilkan `PENDING BUY` / `PENDING SELL`: hasilnya
  `BUY`/`SELL` (filled) atau `NONE` (cancel). Bila `InpAllowFormingBar = true`, `PENDING BUY/SELL` tampil
  selama candle pola masih berjalan.
- Sejak v2.03 guard-nya ada di mesin, bukan hanya di alert: pola **hanya dibuat untuk bar yang sudah
  close** (`i < rates_total - 1`), jadi candle berjalan tidak pernah membentuk setup. Panel, counter
  `Signals`/`Runs`/`Cancel`, dan buffer EA karena itu hanya berubah saat sebuah candle tertutup (tidak ada
  repaint intrabar). EA dengan `InpUseClosedBarSignal = false` (shift 0) tetap entry di tick pertama
  setelah bar pola close, memakai ENTRY yang sudah final.
  Guard ini bisa dilepas lewat `InpAllowFormingBar` — lihat [Opsi intrabar](#opsi-intrabar-pending-saat-candle-berjalan).
- Tidak ada field `armBar`; bar arming selalu sama dengan `setup.setupBar`.
- `close(S)` tepat di ENTRY dihitung belum melewati (cancel), sedangkan `high(S) >= ENTRY` selalu
  menang lebih dulu (fill), walau close kembali di bawah ENTRY.
- Satu bar hanya menghasilkan satu event: bila posisi lama baru ditutup TP/SL di bar `i`, pola di bar
  yang sama diabaikan supaya snapshot alert TP/SL tidak tertimpa snapshot fill.
- Dengan `InpBodyBreakTol = 0` (default) setiap pola pasti menyentuh BREAK BODY di bar-nya sendiri
  (`BREAK BODY = body top acuan <= high(acuan) < close(pola) <= high(pola)`). Guard level juga menahan
  `BREAK BODY < ENTRY`, jadi pola tanpa arming (tanpa order dan tanpa alert) praktis tidak terjadi.
- Spesifikasi lengkap: `Main/Docs/entry-requirement-final.html` dan `Main/Docs/entry-visual-arm-p.html`.
  Animasi alur kejadiannya (candle pola live → pending → fill / cancel, beserta log alert):
  `Main/Docs/entry-animation.html`.

#### Opsi intrabar: pending saat candle berjalan

Karena `setup.setupBar == i` tepat saat CREATE, trigger → fill/cancel dievaluasi di **iterasi yang sama**
dengan OHLC final bar S. Praktisnya tidak pernah ada order yang parkir di pasar: fill dicatat di bar S
pada harga `pEntry` bila `high(S)` sudah mencapainya. Ini disengaja — sinyal yang dibaca EA (shift 0
maupun shift 1) selalu berasal dari candle yang sudah confirmed, dan tidak ada counter yang naik lalu
turun.

Bila yang diinginkan adalah **pending dipasang saat candle berjalan** (intrabar), gunakan input
`InpAllowFormingBar = true`. Guard `notFormingBar` (`Core.mqh`) dilepas untuk deteksi pola, trigger,
dan fill, sehingga:

- pola pada bar terakhir (yang masih bergerak) ikut dievaluasi dengan `close` = harga terakhir;
- begitu `close_belum_final > high(S-1)`, level dihitung dan label `PENDING BUY` langsung tampil, panel
  menampilkan `PENDING BUY/SELL`, dan state bisa lanjut `ARMED` → `BUY/SELL` (fill) di dalam candle S;
- **cancel-at-close** dan aturan "setup tanpa break body" tetap hanya dievaluasi pada bar yang sudah close.
  Tanpa itu, `close(S)` yang pada candle berjalan masih berupa harga terakhir akan menghapus pending
  yang baru saja dipasang (pending hanya akan sempat tampil pada tick ketika harga sudah melewati ENTRY);
- **tidak ada jalur void (v2.04)**: setiap setup yang lahir di dalam candle S dikunci di tabel
  `g_engulfLocks` (`Core.mqh`) berisi arah + BREAK BODY/ENTRY/SL/TP. Bila harga berbalik dan pola tidak
  lagi lolos `DetectEngulfing()` saat close, replay berikutnya membangun ulang setup itu dari level
  terkunci — garis, label, panel, counter, dan buffer EA tetap ada;
- **level beku (v2.04)**: selama kunci untuk bar itu ada, level tidak dihitung ulang. `EngulfAtrAt(i)`
  ikut memakai bar S, jadi ATR berubah dari range sementara ke range final saat candle close; tanpa
  aturan ini ENTRY/SL/TP bisa bergeser (dan fill yang sudah terjadi bisa batal) hanya karena
  candle-nya tertutup;
- setup terkunci hanya punya dua akhir: **filled** (state `BUY`/`SELL`, `entryBar` = bar pola, TP/SL
  tetap dipantau) atau **canceled** saat close (alert `CANCELED`, objek setup dihapus). Buktinya: untuk
  BUY, `close > ENTRY` berarti `high(S) >= ENTRY`, jadi pending pasti sudah terisi di bar S;
- **alert ikut intrabar**: alert `BREAK BODY … pending entry …` (perintah pasang pending) dan
  `ENTRY … FILLED` juga terbit untuk bar terakhir yang masih berjalan, jadi pada candle S yang live
  urutannya: harga lewat break body → pola tentatif sah → **alert pending** → harga sentuh ENTRY →
  **alert filled**. Gerbangnya `alertArmFillBar = closedBar || (InpAllowFormingBar && i == rates_total - 1)`;
  dedupe `EngulfAlertOnce()` memakai waktu bar event, jadi tiap event tetap sekali per bar walau bar itu
  dievaluasi puluhan kali dan tetap tidak terulang saat bar yang sama diproses sebagai bar close;
- alert `CANCELED` tetap hanya terbit di close (cancel memang keputusan close), TP/SL memang sudah
  intrabar. Karena setup yang sudah terisi dipertahankan (v2.04), alert intrabar tidak pernah lagi
  berakhir tanpa jejak di chart: jalurnya berakhir `FILLED` menuju TP/SL, atau `CANCELED`;
- EA dengan `InpUseClosedBarSignal = false` (shift 0) akan entry pada sinyal yang belum confirmed;
  dengan `true` (shift 1) EA tetap menunggu bar close.

Default `false` mempertahankan perilaku v2.03 (pending hanya setelah bar S close). Simulasi perilaku
intrabar ada di `Main/Docs/entry-animation.html` dengan dua tombol skenario:
**A — ENTRY tersentuh (fill)** dan **B — close belum lewat ENTRY (cancel)**. Sejak v2.04 kunci setup
selalu ikut aktif bersama opsi ini (tidak ada input terpisah), jadi skenario B berakhir `CANCELED` —
bukan setup yang hilang. Requirement: `Main/Docs/entry-requirement-intrabar-lock.html`.

Urutan evaluasi **di dalam satu bar** (persis seperti loop `RecalculateEngulfing()`):

1. **Extend** visual setup aktif ke `i + InpExtendB` (bila `InpShowLines`).
2. **Deteksi pola** pada bar `i`; bila ada pola, `stats.nSig++`. Sejak v2.03 langkah pembuatan setup
   (2-7) hanya berjalan untuk bar yang sudah close; **extend** (langkah 1) dan **hasil TP/SL**
   (langkah 8) tetap intrabar. Dengan `InpAllowFormingBar = true` bar terakhir ikut dievaluasi, jadi
   langkah 2-6 juga berjalan di dalam candle pola.
3. **Cancel on opposite** (bila `InpCancelOpp`): hanya relevan untuk state sisa `SETUP`/`ARMED`;
   dengan A = P state itu tidak pernah bertahan, jadi praktis tidak terpicu.
4. **Create new setup** bila state `NONE` dan ada signal baru. Level dihitung di sini (BREAK BODY,
   ENTRY, SL, TP) dan garis langsung digambar. Blok ini sengaja dijalankan **sebelum** trigger/fill,
   jadi setup baru langsung diuji di bar yang sama; bila posisi lama masih `ACTIVE`, pola di bar itu
   diabaikan (satu bar hanya satu event). Sejak v2.04, bila bar itu sudah punya kunci intrabar, arah dan
   keempat level diambil dari kunci (`g_engulfLocks`) dan tidak dihitung ulang.
5. **Trigger break body** (BUY `high >= pBreak`, SELL `low <= pBreak`), **hanya** bila
   `i == setup.setupBar`.
6. **Pending fill** (`BUY_ARMED` → entry BUY bila `high >= pEntry`; `SELL_ARMED` → entry SELL bila
   `low <= pEntry`), syarat yang sama `i == setup.setupBar`. Saat fill: `stats.nRun++`,
   `nBuyRun`/`nSellRun++`, garis entry jadi solid dan berwarna, label berubah menjadi `BUY <price>` /
   `SELL <price>`. Fill dicek **sebelum** cancel.
7. **Cancel at setup bar close**: `ARMED` yang tidak terisi dan `close[i] <= pEntry` (BUY) /
   `close[i] >= pEntry` (SELL) → `stats.nCancelled++`, semua objek setup dihapus, state `NONE`.
   Blok ini (dan aturan "setup tanpa break body" sesudahnya) tetap digerbang `notFormingBar`, juga saat
   `InpAllowFormingBar = true`: pada candle berjalan `close[i]` hanyalah harga terakhir, sehingga
   keputusan "gagal close" hanya sah untuk bar yang benar-benar sudah close. Setup yang dibangun ulang
   dari kunci ikut aturan ini: state-nya kembali `ARMED` dengan level yang sama, jadi cancel tetap terbit
   sekali di close.
8. **Hasil** (hanya untuk bar setelah `entryBar`, **SL dicek lebih dulu**):
   - SL kena → `nLos++`, `buyLoss`/`sellLoss++`, `maxSLStreak` diperbarui, label `BUY SL`/`SELL SL`
     dan `SL HIT`.
   - TP kena → `nWin++`, `buyWins`/`sellWins++`, `maxTPStreak` diperbarui, label `BUY TP`/`SELL TP`
     dan `TP HIT`.
9. **Freeze**: garis dan label dihentikan di `bar hasil + InpExtendB`; referensi objek aktif
   dikosongkan sehingga setup berikutnya membuat objek baru (salinan histori tetap ada).
10. **Buffer & alert**: buffer diisi pada bar fill; alert arm/fill memakai
    `alertArmFillBar = closedBar || (InpAllowFormingBar && i == rates_total - 1)` (default `false` =
    hanya bar tertutup `rates_total - 2`), alert cancel tetap hanya dari bar tertutup, TP/SL juga boleh
    intrabar (`rates_total - 1`).

Karena SL diperiksa sebelum TP, bar yang menyentuh SL dan TP sekaligus dihitung **loss** — sama
dengan aturan Pine dan menghindari asumsi urutan intrabar.

## Objek Chart

Semua objek memakai prefix `HoekaGATA_Engulf_` dan dibuat di `RecalculateEngulfing()` pass kedua.

| Nama objek | Tipe | Kapan dibuat | Keterangan |
| --- | --- | --- | --- |
| `BODYLINE_<bar>` | garis tren | setiap pola terdeteksi | level BREAK BODY, style `InpBodyBreakStyle`, warna `InpCBodyBreak` |
| `BODYLABEL_<bar>` | label teks | idem | teks `BREAK BODY`, diletakkan di ujung kanan garis |
| `ENTRYLINE_<bar>_<dir>` | garis tren | setup lolos guard | level ENTRY, style `InpLineStyle`, warna `InpCEntryLine`, jadi solid + warna BUY/SELL saat fill |
| `SLLINE_<bar>_<dir>` | garis tren | idem | level SL, warna `InpCSL` |
| `TPLINE_<bar>_<dir>` | garis tren | idem | level TP, warna `InpCTP` |
| `ENTRYLABEL_…`, `SLLABEL_…`, `TPLABEL_…` | label teks | idem | `PENDING BUY/SELL <price>` → `BUY/SELL <price>` saat fill; `BUY TP`/`BUY SL`; `SL <price>` → `SL HIT <price>`; `TP <price>` → `TP HIT <price>` |
| `PANEL_*` | label + rectangle | setiap replays | panel statistik (lihat bagian Panel) |

Detail teknis:

- Garis memakai `OBJ_TREND` width 1, `RAY_LEFT = RAY_RIGHT = false`, `BACK = false`,
  `SELECTABLE = false`. Koordinat memakai index bar yang dikonversi ke waktu; bar masa depan
  diekstrapolasi dengan `PeriodSeconds(_Period)`.
- Label memakai `OBJ_TEXT` font Arial, ukuran dari `EngulfFontSize()` (Tiny 7, Small 9, Normal 11,
  Large 14), anchor `ANCHOR_RIGHT_LOWER`, sehingga teks selalu berada di atas level harganya dan tidak
  terpotong di sisi kanan.
- Saat state aktif, garis dan label digeser setiap bar ke `i + InpExtendB`. Saat hasil keluar
  (TP/SL), posisi dibekukan di `bar hasil + InpExtendB` dan referensi objek aktif dikosongkan.
- **Batas histori:** garis body disimpan maksimum `InpKeepN` setup, sedangkan pasangan Entry/SL/TP
  maksimum `InpKeepN * 3` garis dan `InpKeepN * 3` label. Setup lama dihapus dari kiri.
- Semua objek satu setup dihapus lewat `EngulfClearSetupVisuals()` saat setup batal: pola berlawanan,
  cancel saat bar pola close, atau BREAK BODY tidak tersentuh. Yang tersisa di chart praktis hanya
  setup yang benar-benar filled (plus salinan histori).
- Recalculation tidak menghapus objek panel: `EngulfDeleteByPrefixExcept(PREFIX, PREFIX + "PANEL_")`.

## Alert

Alert hanya dipicu pada pass painting dan hanya di dekat ujung histori, sehingga replay lama tidak
membanjiri terminal. Sejak v2.02 gerbangnya dua tingkat:

| Kejadian | Bar yang boleh alert |
| --- | --- |
| `BREAK BODY` (ARMED), `ENTRY … FILLED` | bar terakhir yang **sudah close** (`i == rates_total - 2`); dengan `InpAllowFormingBar = true` juga bar berjalan (`rates_total - 1`) |
| `ENTRY … CANCELED` | bar terakhir yang **sudah close** (`i == rates_total - 2`), termasuk saat `InpAllowFormingBar = true` |
| `TP HIT`, `SL HIT` | `rates_total - 2` atau bar berjalan (`rates_total - 1`) |

`CANCELLED <side> (opposite signal)` masih ada di kode (`InpCancelOpp`) tetapi **tidak pernah terpicu**
sejak A = P: state `SETUP`/`ARMED` hanya hidup di dalam iterasi bar pola, sedangkan blok cancel-opposite
dievaluasi sebelum CREATE, jadi state yang terbawa dari bar sebelumnya selalu `NONE`. Input dan teks
alert-nya dibiarkan utuh agar preset lama tidak berubah. Alert yang benar-benar aktif: **5 jenis**.

Semua harga memakai `EngulfPriceText()` (desimal = `_Digits`); `<setup>` adalah **waktu candle pola (S)**
dan `<bar>` adalah **waktu candle tempat kejadiannya** (dengan A = P keduanya sama untuk arm/fill/cancel).

| Kejadian | Teks |
| --- | --- |
| Break body kena (state jadi ARMED) | `<SYMBOL> <TF> \| BREAK BODY BUY @ <break> \| pending entry <entry> \| SL <sl> \| TP <tp> \| RR <rr> \| setup <setup> \| bar <bar>` |
| Entry terisi | `<SYMBOL> <TF> \| ENTRY BUY FILLED @ <entry> \| SL <sl> \| TP <tp> \| RR <rr> \| break body <break> \| setup <setup> \| fill bar <bar>` |
| TP kena | `<SYMBOL> <TF> \| TP HIT BUY @ <tp> \| entry <entry> \| SL <sl> \| RR <rr> \| setup <setup> \| result bar <bar>` |
| SL kena | `<SYMBOL> <TF> \| SL HIT BUY @ <sl> \| entry <entry> \| TP <tp> \| RR <rr> \| setup <setup> \| result bar <bar>` |
| Setup batal karena close bar pola | `<SYMBOL> <TF> \| ENTRY BUY CANCELED @ <entry> \| close bar <close> \| SL <sl> \| TP <tp> \| RR <rr> \| setup <setup> \| bar <bar>` |
| Setup batal karena pola berlawanan | `<SYMBOL> <TF> \| CANCELLED BUY (opposite signal) \| pending entry <entry> \| SL <sl> \| TP <tp> \| setup <setup> \| cancel bar <bar>` |

Sisi `BUY`/`SELL` mengikuti arah setup. `<rr>` dihitung dari level setup sebenarnya
(`|TP-ENTRY| / |ENTRY-SL|`, dua desimal, mis. `1:2.00`), jadi tetap benar walau guard level menggeser
harga. Candle pola sendiri tidak memicu alert: pola hanya menggambar garis, dan alert menyusul saat
bar itu close (ARMED / FILLED / CANCELED).

`<TF>` berasal dari `EnumToString((ENUM_TIMEFRAMES)_Period)`, jadi tampil seperti `PERIOD_H1`.

**Tidak ada duplikasi.** Tiap jenis kejadian menyimpan kunci `<event>|<dir>|<setup time>|<bar time>`
(`EngulfAlertKey*` + `EngulfAlertOnce()`), sehingga replay per-tick tidak mengulang alert yang sama.
Karena kunci memakai waktu bar (bukan index), re-download histori juga tidak memicu ulang.

De-dup itu juga bertahan antar sesi. Selain kunci di memori, waktu bar event terakhir per jenis kejadian
disimpan sebagai terminal global variable `HG_AL_<chartID>_<periodSeconds>_<TAG>` (`TAG` =
`ARMED`/`ENTRY`/`TP`/`SL`/`CANCEL`/`CANCELED`); event yang bar-nya **tidak lebih baru** dari catatan itu
dilewati. Jadi melepas-pasang indikator, mengganti timeframe bolak-balik, atau restart terminal tidak
mengulang alert bar close terakhir. Variable ini sengaja tidak dihapus di `OnDeinit`.

Semua angka diambil dari snapshot saat kejadian (`EngulfAlertFlags.ev*`, termasuk `evClose` untuk
cancel), bukan dari variabel `setup` yang masih hidup: bar yang sama bisa langsung membentuk setup baru,
dan tanpa snapshot alert akan melaporkan level setup baru.

Indikator memakai `Alert()` (popup terminal). Tidak ada `SendNotification()` / push, dan tidak ada
input untuk mematikan alert per jenis. Spesifikasi aturan dan timeline:
`Main/Docs/entry-requirement-final.html`, visual kasusnya `Main/Docs/entry-visual-arm-p.html`.

## Panel Statistik

Panel adalah tabel 2 kolom dengan latar transparan, menempel di sudut kanan atas
(`CORNER_RIGHT_UPPER`), dan di-render dari objek chart biasa (bukan `OBJ_BITMAP_LABEL`/canvas).

### Geometri (terkunci, sesuai `Main/Docs/panel-mockup.html`)

| Konstanta | Nilai | Arti |
| --- | --- | --- |
| `PANEL_PANEL_W` | 180 px | lebar total panel |
| `PANEL_MARGIN_X` / `_Y` | 12 px | jarak dari tepi kanan / atas chart |
| `PANEL_PAD_X` / `_Y` | 20 px / 10 px | padding dalam |
| `PANEL_LINE_H` | 16 px | tinggi satu baris (baris byline +6 px) |
| `PANEL_FONT_BODY` / `_HEAD` | 8 pt / 9 pt | ukuran font body / judul |
| `PANEL_FOOTER_GAP` / `_H` | 6 px / 20 px | jarak dan tinggi kotak probabilitas |

`InpPanelSize` **tidak** lagi memengaruhi panel (layout dikunci); input itu masih dipakai untuk
ukuran label SL/TP di chart.

### Isi baris

| Row | Label | Nilai |
| --- | --- | --- |
| 0 | `Engulfing Breakout` (center, bold 9pt) | — |
| 1 | `by Syakir Arslan` (center, dengan garis pemisah di bawahnya) | — |
| 2 | `SETUP` (header) | — |
| 3 | `R:R` | `1:<InpRrRatio>` (contoh `1:2`) |
| 4 | `Status` | `BUY` / `SELL` / `NONE` (dari `stats.state`; `PENDING` hanya transien di dalam bar pola, jadi tidak pernah tampil) |
| 5 | `Cancel` | `stats.nCancelled` |
| 6 | `RESULTS` (header) | — |
| 7 | `Signals` | `stats.nSig` — jumlah bar yang membentuk pola |
| 8 | `Runs` | `stats.nRun` — jumlah entry yang terisi |
| 9 | `Buy %` | `<winrate BUY> (<nBuyRun>)`, contoh `66.67% (3)` |
| 10 | `Sell %` | `<winrate SELL> (<nSellRun>)` |
| 11 | `TP Streak` | `stats.maxTPStreak` (warna `InpCTP`) |
| 12 | `SL Streak` | `stats.maxSLStreak` (warna `InpCSL`) |
| footer | kotak terpisah | probabilitas keseluruhan `nWin / (nWin + nLos)`, teks `n/a` bila belum ada hasil |

Warna: teks netral `clrWhiteSmoke`, header putih, nilai positif `InpCTP`, negatif `InpCSL`, status
mengikuti warna BUY/SELL (`InpCBuyText` / `InpCSellText`), dan `clrSilver` saat `NONE`. Teks sengaja
putih karena frame transparan — panel didesain untuk theme chart gelap.

### Cara menggambar

- `OBJ_RECTANGLE_LABEL` dengan `BGCOLOR = clrNONE` tidak merender border pada build MT5 saat ini,
  sehingga frame digambar manual sebagai 4 bar 1px (`PANEL_BAR_TOP/BOT/LFT/RGT`).
- Hanya ada satu garis pemisah: di bawah baris byline (`PANEL_RULE1`). Baris lain tanpa garis agar
  tabel tetap lapang.
- Kotak probabilitas adalah box berframe sendiri (`PANEL_BAR_FTOP/FBOT/FLFT/FRGT` + `PANEL_FOOTER_TEXT`),
  bukan baris ke-14.
- **Cache:** `EngulfDrawPanel()` menyimpan snapshot `PanelPaintedStats`. Bila statistik sama persis,
  panel tidak di-refresh (menghemat ~35 label × 11 `ObjectSet*` per recalculation). Repaint paksa
  hanya terjadi lewat `EngulfPanelRepaintCached()` dari `OnChartEvent`.

## Kontrak Signal untuk EA

Indikator adalah satu-satunya sumber arah entry. EA tidak mendeteksi pola. Ada dua jalur data yang
disediakan, dan keduanya memakai nilai yang sama.

### 1. Buffer indikator (`iCustom`)

| Index | Nama variabel | Isi | Nilai "tidak ada signal" |
| --- | --- | --- | --- |
| 0 | `BuyBuffer` | harga entry BUY | `EMPTY_VALUE` |
| 1 | `SellBuffer` | harga entry SELL | `EMPTY_VALUE` |
| 2 | `SignalSLBuffer` | SL untuk signal pada bar itu | `EMPTY_VALUE` |
| 3 | `SignalTPBuffer` | TP untuk signal pada bar itu | `EMPTY_VALUE` |

Buffer diisi pada **bar fill** (bar saat `high >= ENTRY` untuk BUY atau `low <= ENTRY` untuk SELL).
Selain itu, bila di akhir replay state masih `BUY_ACTIVE`/`SELL_ACTIVE`, level aktif dipublikasikan
juga di bar terakhir supaya EA melihat level yang sedang hidup.

Konsekuensi praktis: dengan `InpUseClosedBarSignal = false` EA membaca shift 0 (bar berjalan), dan
dengan `true` EA membaca shift 1 (bar tertutup). Jangan mengubah jumlah buffer: EA membaca indeks 0..3.

### 2. GlobalVariable (dipublish setiap perhitungan)

Kunci memakai `ChartID()`, jadi dua chart pada symbol/timeframe yang sama tidak saling menimpa.

| Kunci | Isi |
| --- | --- |
| `HG_SIG_<chartid>_HB` | heartbeat: `TimeCurrent()` setiap publish |
| `HG_SIG_<chartid>_PMIN`, `_PMAX` | `InpKeepN` (kunci legacy, dipertahankan untuk pembaca lama) |
| `HG_SIG_<chartid>_C_T` | waktu bar terakhir |
| `HG_SIG_<chartid>_C_D` | arah: `1` BUY, `-1` SELL, `0` tidak ada |
| `HG_SIG_<chartid>_C_E`, `_C_SL`, `_C_TP` | entry / SL / TP bar terakhir |
| `HG_SIG_<chartid>_P_T`, `_P_D`, `_P_E`, `_P_SL`, `_P_TP` | idem untuk bar sebelumnya |

EA memprioritaskan jalur ini: bila `HB` ada, EA membaca slot `C`/`P` dan memvalidasi `_T` terhadap
`iTime(_Symbol, _Period, shift)`. Bila waktu tidak cocok, data dianggap basi dan EA jatuh ke buffer
`iCustom`. Semua kunci dihapus pada `OnDeinit`.

## Build dan Deploy

### Otomatis

```powershell
cd Main\Tools
.\Build-MT5.ps1                      # Indicator + EA
.\Build-MT5.ps1 -Target Indicator    # indikator saja
.\Build-MT5.ps1 -Target EA           # EA saja
.\Build-MT5.ps1 -NoDeploy            # compile tanpa copy ke terminal
.\Build-MT5.ps1 -Restart             # deploy lalu restart terminal64.exe
```

Alur script (`Main/Tools/Build-MT5.ps1`, PowerShell 5.1+):

1. Menentukan folder data MT5 yang benar-benar dipakai terminal yang sedang berjalan.
2. Compile `HoekaGataIndicator.mq5` dan/atau `HoekaGataAlgo.mq5` dengan `metaeditor64.exe`
   (`C:\Program Files\MetaTrader 5\` atau `C:\Program Files (x86)\MetaTrader 5\`).
3. Berhenti (`throw`) pada error compiler pertama.
4. Copy source + `.ex5` ke `<data folder>\MQL5\Indicators\HokaGATA\` dan
   `<data folder>\MQL5\Experts\HokaGATA\`.
5. Verifikasi setiap file hasil deploy dengan SHA256.

`-Restart` menutup MT5 tanpa menyimpan perubahan panel yang belum di-commit, jadi pakai hanya bila
memang perlu (mis. folder baru pertama kali di-deploy).

### Manual

1. Buka `HoekaGataIndicator.mq5` di MetaEditor.
2. `F7` (Compile). Perhatikan tab Errors; indikator harus 0 error.
3. Copy folder `Includes/` bersama `.mq5` — include memakai path relatif, jadi struktur folder harus
   tetap utuh.
4. Pasang indikator ke chart; bila input tidak valid, `OnInit` menolak dan alasannya muncul di tab
   Experts.

### Setelah mengubah input default

EA di Strategy Tester membuat instance indikator sendiri melalui `#property tester_indicator`
(`HokaGATA\HoekaGataIndicator.ex5`). Bila input default indikator diubah, **compile ulang** sebelum
menjalankan test EA, kalau tidak tester memakai `.ex5` lama.

## Referensi Input

Semua input ada di `HoekaGataIndicator_Config.mqh` dan dikelompokkan sesuai urutan tampilan di tab
Input MetaTrader.

### 1. ENGULFING PATTERN

| Input | Default | Arti |
| --- | --- | --- |
| `InpMinBodyX` | `1.2` | Body minimal sebagai kelipatan range bar sebelumnya (`okBodyX`). Harus `>= 0`. |
| `InpMinBodyP` | `50.0` | Body minimal sebagai persentase range bar sebelumnya (`okBodyP`). Range `0..100`. |

### 2. ENTRY

| Input | Default | Arti |
| --- | --- | --- |
| `InpBufEntryX` | `0.10` | Jarak pending entry dari wick, dalam ATR |
| `InpBufSLX` | `0.10` | Jarak SL dari wick berlawanan, dalam ATR |
| `InpBodyBreakTol` | `0.00` | Toleransi level BREAK BODY terhadap body bar sebelumnya, dalam ATR |
| `InpCancelOpp` | `true` | Batalkan setup `SETUP`/`ARMED` bila muncul pola berlawanan |
| `InpAllowFormingBar` | `false` | Evaluasi pola/trigger/fill **dan alert arm/fill** juga pada bar terakhir yang masih berjalan (pending intrabar). Alert cancel tetap menunggu bar close. Sejak v2.04 setup intrabar otomatis dikunci: level beku dan tidak ada VOID saat close. `false` = perilaku v2.03 (hanya bar close) |

### 3. RISK & REWARD

| Input | Default | Arti |
| --- | --- | --- |
| `InpRrRatio` | `2.0` | Rasio `1 : x` untuk TP. Harus `> 0`. |

### 4. DISPLAY (Entry / SL / TP)

| Input | Default | Arti |
| --- | --- | --- |
| `InpShowLines` | `true` | Tampilkan garis & label level. Bila `false`, tidak ada objek level dan panel tetap jalan. |
| `InpLabelSize` | `Small` | Ukuran label chart: `Tiny` (7), `Small` (9), `Normal` (11), `Large` (14) |
| `InpLineStyle` | `Dashed` | Style garis Entry/SL/TP: `Solid` atau `Dashed` |
| `InpExtendB` | `3` | Panjang garis ke kanan (bar). Saat aktif, garis selalu digeser ke `bar + InpExtendB`. |
| `InpKeepN` | `3` | Jumlah setup yang dipertahankan di chart (juga menentukan `keepN*3` objek Entry/SL/TP) |

### 4b. RESULTS SUMMARY

| Input | Default | Arti |
| --- | --- | --- |
| `InpShowTable` | `true` | Tampilkan panel statistik kanan atas |
| `InpPanelSize` | `Small` | Tidak memengaruhi panel (layout dikunci); masih dipakai untuk label chart |

### 5. BODY-BREAK (TRIGGER)

| Input | Default | Arti |
| --- | --- | --- |
| `InpBodyBreakStyle` | `Dotted` | Style garis BREAK BODY: `Dotted`, `Dashed`, `Solid` |

### 6. COLORS

| Input | Default (RGB) | Dipakai untuk |
| --- | --- | --- |
| `InpCEntryLine` | `120,123,134` | garis entry sebelum fill |
| `InpCSL` | `239,83,80` | garis/label SL, nilai `SL Streak` |
| `InpCTP` | `38,166,154` | garis/label TP, nilai `TP Streak` |
| `InpCBodyBreak` | `189,189,189` | garis & label BREAK BODY |
| `InpCBuyText` | `38,166,154` | label/status BUY |
| `InpCSellText` | `239,83,80` | label/status SELL |

Catatan: label entry memakai `InpCBuyText`/`InpCSellText` saat fill, jadi warna entry berubah dari
`InpCEntryLine` menjadi warna arah.

## Perbedaan dengan Pine

Dibandingkan dengan versi lengkap `Source/HoekaGata_Indicator.pine`:

| Aspek | MQL5 | Pine (`HoekaGata_Indicator.pine`) |
| --- | --- | --- |
| Status engine | lengkap (pola → state → level → panel → alert) | lengkap (pola → state → level → panel → alert) |
| Aturan entry | pemicu, fill, dan cancel di **bar pola** (A = P, v2.02); default pola hanya dibuat setelah bar close (v2.03), bisa dilepas dengan `InpAllowFormingBar` | pending bertahan sampai ada bar yang menyentuh ENTRY |
| Mode pola | `InpPatMode` `Strict` / `Loose` | `Pattern Mode` `Strict` / `Loose` |
| ATR | rata-rata sederhana True Range 14 bar | `ta.atr(14)` (RMA) |
| Panel | 13 baris + kotak footer terpisah; label `Runs`, `Buy %`, `Sell %`, `Cancel`, `TP Streak`, `SL Streak` | tabel 2×14 dengan blok `SETUP` / `RESULTS`; label `Entries`, `Buy WR`, `Sell WR`, `Cancelled`, `Max TP Run`, `Max SL Run`; baris `Overall` di dalam tabel |
| Status | `BUY` / `SELL` / `NONE` (default `PENDING` tidak pernah tampil karena setup hanya dibuat di bar close; dengan `InpAllowFormingBar = true` `PENDING BUY` / `PENDING SELL` muncul selama candle pola berjalan) | `PENDING BUY` / `PENDING SELL` / `BUY` / `SELL` / `NONE` |
| Ukuran teks | 8 pt / 9 pt (Arial) | `size.tiny` / `size.small` / `size.normal` |
| Objek chart | `OBJ_TREND` + `OBJ_TEXT` + objek panel | `line` + `label` + `table` |
| Pemangkasan riwayat | `InpKeepN` setup, dipangkas per jenis objek | `Displayed Setups` (`keepN`), entry/SL/TP dipangkas `keepN * 3`, body-break `keepN` |
| Alert | 5 `Alert()` aktif (arm, fill, TP, SL, cancel close) + 1 jalur legacy cancel-opposite yang tidak terpicu | 6 `alertcondition` + 5 `alert()` dinamis |
| Integrasi EA | buffer + `GlobalVariable` | tidak ada (manual) |

Draft `Source/HoekaGata_Indicator_Engulf.pine` sengaja tidak dipakai sebagai pembanding: file itu baru
berisi input + panel, engine-nya masih TODO.

Perbedaan ATR membuat level bisa bergeser tipis antara TradingView dan MT5 pada bar yang sama. Itu
sifat yang diketahui dan disengaja; selisih kecil bukan bug.

## Batasan dan Perilaku yang Perlu Diketahui

- "Engulfing" di sini berarti **close menembus wick bar sebelumnya** (loose), bukan pola engulfing
  klasik yang menuntut body menelan body.
- Indikator selalu me-replay seluruh histori pada setiap perubahan. Hasilnya deterministik, tetapi
  chart dengan histori sangat panjang lebih berat saat pertama dipasang.
- Panel memakai ukuran piksel tetap. Pada layar dengan scaling Windows di atas 100%, proporsinya bisa
  terlihat berbeda dari mockup.
- Teks panel berwarna terang; pada theme chart putih panel sulit dibaca karena frame-nya transparan.
- Alert arm/fill/cancel baru dikirim setelah bar pola tertutup (tick pertama bar berikutnya), jadi
  OHLC-nya final; alert TP/SL tetap keluar intrabar. **Dengan `InpAllowFormingBar = true`**, alert
  arm (`BREAK BODY`) dan fill (`ENTRY … FILLED`) ikut terbit selagi candle S berjalan. Sejak v2.04
  setup seperti itu tidak bisa lagi "gugur": bila close gagal mengonfirmasi pola, setup dibangun ulang
  dari kunci — yang filled tetap `BUY`/`SELL` (buffer EA dan TP/SL lanjut), yang armed berakhir
  `CANCELED` di close. Sinyal yang terjadi saat MT5 tertutup tidak di-alert ulang. Tiap kejadian
  di-alert **sekali per bar** (dedupe lewat `EngulfAlertKey*` + `HG_AL_*`), termasuk setelah indikator
  di-reload.
- Tidak ada push notification maupun pengaturan suara di indikator; semuanya mengikuti preferensi
  terminal.
- Karena pola hanya dibuat setelah candle-nya close (v2.03, default), garis `BREAK BODY` / `ENTRY` /
  `SL` / `TP` baru muncul pada tick pertama setelah candle pola tertutup - bukan saat candle itu masih
  berjalan. Garis setup yang masih ACTIVE tetap digeser ke kanan setiap bar. Dengan
  `InpAllowFormingBar = true`, garis dan label `PENDING` tampil di dalam candle pola dan **tidak hilang
  lagi saat close** (v2.04): yang hilang hanya setup yang benar-benar canceled, dan itu diumumkan lewat
  alert `CANCELED`. Kunci disimpan di memori indikator, jadi remove/re-attach di tengah candle S membuat
  bar itu dinilai ulang dari close (batasan D9).

## Troubleshooting

| Gejala | Penyebab umum | Solusi |
| --- | --- | --- |
| Tidak ada garis level | `InpShowLines = false`, belum ada pola, atau setup gagal guard | Aktifkan `InpShowLines`; turunkan `InpMinBodyX` / `InpMinBodyP`; cek tab Experts |
| Garis body ada tapi tanpa Entry/SL/TP | Setup gagal guard (`RISK` atau `\|TP-ENTRY\|` <= 1 point) | Perbesar `InpBufEntryX` / `InpBufSLX`, atau periksa symbol dengan point sangat kecil |
| Panel tidak tampil | `InpShowTable = false` | Aktifkan `Show Panel` |
| Panel hilang saat scroll/zoom | Build lama tanpa handler `OnChartEvent` | Compile ulang dari source terbaru |
| Panel terbaca samar | Theme chart terang | Gunakan theme gelap |
| Statistik tidak bertambah | Belum ada fill/hasil pada histori yang ter-load | Muat histori lebih panjang, atau tunggu bar baru |
| EA tidak membuka posisi | `Algo` off, filter spread/time, atau buffer kosong | Lihat panel EA dan tab Experts EA (alasan terakhir selalu ditulis) |
| Level beda dengan TradingView | ATR RMA vs rata-rata sederhana, atau yang dipasang justru draft `HoekaGata_Indicator_Engulf.pine` | Pasang `Source/HoekaGata_Indicator.pine` (versi lengkap) dan pahami perbedaan ATR |

## Checklist Verifikasi

1. `Build-MT5.ps1 -NoDeploy` selesai tanpa error.
2. Indikator terpasang dan short name di chart berbunyi `Engulfing Breakout <SYMBOL> <TF>`.
3. Panel tampil dengan 13 baris + kotak probabilitas; nilai `R:R` sama dengan input `InpRrRatio`.
4. Pola baru memunculkan garis `BREAK BODY`; di bar yang sama label entry berubah menjadi
   `BUY`/`SELL` (filled) atau semua garis setup hilang (cancel).
5. Setelah fill, garis entry menjadi solid dan panel `Status` menampilkan `BUY`/`SELL`; dengan default
   (`InpAllowFormingBar = false`) `PENDING` tidak pernah muncul karena pola baru dibuat setelah
   candle-nya close (v2.03). Dengan `InpAllowFormingBar = true`, level dan label `PENDING BUY/SELL`
   terlihat saat candle pola masih berjalan dan **tidak hilang** walau pola gagal di close (v2.04):
   yang filled tetap `BUY`/`SELL`, yang armed berakhir `CANCELED`, dan angkanya sama dengan yang
   diumumkan alert. Alert `BREAK BODY … pending entry …` (saat pola tentatif sah) lalu `ENTRY …
   FILLED` (saat harga menyentuh entry) harus terbit **sebelum** bar close, masing-masing tepat sekali
   per bar.
6. Hasil TP/SL mengubah label menjadi `TP HIT`/`SL HIT` dan angka panel bertambah.
7. Scroll dan zoom chart: panel tetap terlihat.
8. Lepas indikator: semua objek `HoekaGATA_Engulf_*` hilang dan `GlobalVariable` `HG_SIG_*`
   dibersihkan. `HG_AL_*` sengaja **dibiarkan** (penanda alert terakhir) supaya pasang ulang tidak
   mengulang alert.
9. Pasang ulang indikator / ganti timeframe bolak-balik: tidak ada alert baru untuk bar close terakhir.




