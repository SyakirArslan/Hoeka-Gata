# Indikator MT5 — HoekaGata Engulfing Breakout

Dokumen ini menjelaskan indikator MetaTrader 5 `HoekaGataIndicator.mq5` secara lengkap: arsitektur
modul, aturan deteksi pola, matematika setiap level, state machine, objek chart, alert, panel
statistik, kontrak signal untuk EA, dan referensi seluruh input.

- **File utama:** `Main/MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5`
- **Nama tampilan chart:** `Engulfing Breakout <SYMBOL> <TF>` (mis. `Engulfing Breakout XAUUSD H1`)
- **Versi:** 2.00
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
| `STATE_BUY_SETUP` | `1` | pola BUY terdeteksi, menunggu harga menyentuh BREAK BODY | `BUY_ARMED` bila `high >= BREAK BODY`; `NONE` bila dibatalkan |
| `STATE_BUY_ARMED` | `2` | trigger body-break kena, pending di ENTRY | `BUY_ACTIVE` bila `high >= ENTRY`; `NONE` bila dibatalkan |
| `STATE_BUY_ACTIVE` | `3` | entry terisi, menunggu hasil | `NONE` saat TP atau SL kena |
| `STATE_SELL_SETUP` | `-1` | cermin untuk SELL | `SELL_ARMED` bila `low <= BREAK BODY` |
| `STATE_SELL_ARMED` | `-2` | trigger SELL kena | `SELL_ACTIVE` bila `low <= ENTRY` |
| `STATE_SELL_ACTIVE` | `-3` | entry SELL terisi | `NONE` saat TP atau SL kena |

Urutan evaluasi **di dalam satu bar** (persis seperti loop `RecalculateEngulfing()`):

1. **Extend** visual setup aktif ke `i + InpExtendB` (bila `InpShowLines`).
2. **Deteksi pola** pada bar `i`; bila ada pola, `stats.nSig++`.
3. **Cancel on opposite** (bila `InpCancelOpp`): pola berlawanan saat state masih `SETUP`/`ARMED`
   menghapus semua objek setup, `stats.nCancelled++`, state kembali `NONE`. Setup yang sudah
   `ACTIVE` **tidak** dibatalkan.
4. **Trigger break body** (BUY `high >= pBreak`, SELL `low <= pBreak`), hanya untuk bar setelah
   `setupBar`.
5. **Pending fill** (`BUY_ARMED` → entry BUY bila `high >= pEntry`; `SELL_ARMED` → entry SELL bila
   `low <= pEntry`). Saat fill: `stats.nRun++`, `nBuyRun`/`nSellRun++`, garis entry jadi solid dan
   berwarna, label berubah menjadi `BUY <price>` / `SELL <price>`.
6. **Hasil** (hanya untuk bar setelah `entryBar`, **SL dicek lebih dulu**):
   - SL kena → `nLos++`, `buyLoss`/`sellLoss++`, `maxSLStreak` diperbarui, label `BUY SL`/`SELL SL`
     dan `SL HIT`.
   - TP kena → `nWin++`, `buyWins`/`sellWins++`, `maxTPStreak` diperbarui, label `BUY TP`/`SELL TP`
     dan `TP HIT`.
7. **Freeze**: garis dan label dihentikan di `bar hasil + InpExtendB`; referensi objek aktif
   dikosongkan sehingga setup berikutnya membuat objek baru (salinan histori tetap ada).
8. **Create new setup** bila state `NONE` dan ada signal baru.
9. **Buffer & alert**: isi buffer pada bar fill, alert hanya pada bar terakhir.

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
| `ENTRYLABEL_…`, `SLLABEL_…`, `TPLABEL_…` | label teks | idem | `PENDING BUY/SELL <price>` → `BUY/SELL <price>` → `BUY TP`/`BUY SL`; `SL <price>` → `SL HIT <price>`; `TP <price>` → `TP HIT <price>` |
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
- Saat pola berlawanan membatalkan setup, semua objek setup tersebut dihapus (bukan dibekukan).
- Recalculation tidak menghapus objek panel: `EngulfDeleteByPrefixExcept(PREFIX, PREFIX + "PANEL_")`.

## Alert

Alert hanya dipicu pada bar terakhir (`i == rates_total - 1`) dan hanya pada pass painting, sehingga
replay histori tidak membanjiri terminal. Format persis:

| Kejadian | Teks |
| --- | --- |
| Break body kena (state jadi ARMED) | `<SYMBOL> <TF> \| BREAK BODY TRIGGERED BUY \| PENDING @ <entry>` |
| Entry terisi | `<SYMBOL> <TF> \| ENTRY BUY @ <entry> \| SL <sl> \| TP <tp>` |
| TP kena | `<SYMBOL> <TF> \| TP HIT BUY @ <tp>` |
| SL kena | `<SYMBOL> <TF> \| SL HIT BUY @ <sl>` |
| Setup dibatalkan | `<SYMBOL> <TF> \| CANCELLED BUY \| SL <sl>` |

`<TF>` berasal dari `EnumToString((ENUM_TIMEFRAMES)_Period)`, jadi tampil seperti `PERIOD_H1`.
Indikator memakai `Alert()` (popup terminal). Tidak ada `SendNotification()` / push, dan tidak ada
input untuk mematikan alert per jenis.

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
| 4 | `Status` | `BUY` / `SELL` / `PENDING BUY` / `PENDING SELL` / `NONE` |
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

| Aspek | MQL5 | Pine (`HoekaGata_Indicator_Engulf.pine`) |
| --- | --- | --- |
| Status engine | lengkap (pola → state → level → panel → alert) | draft: input, warna, panel, model statistik lengkap; engine masih TODO |
| ATR | rata-rata sederhana True Range | `ta.atr()` (RMA) |
| Panel | 13 baris + kotak footer terpisah; label `Runs`, `Buy %`, `Sell %`, `Cancel`, `TP Streak`, `SL Streak` | tabel 2×14; label `Entries`, `Buy WR`, `Sell WR`, `Cancelled`, `Max TP Run`, `Max SL Run`; baris `Overall` menyatu di tabel |
| Status | `PENDING BUY` / `PENDING SELL` / `BUY` / `SELL` / `NONE` | `BUY` / `SELL` / `NONE` (state pending tampil sebagai BUY/SELL) |
| Ukuran teks | 8 pt / 9 pt (Arial) | `size.tiny` / `size.small` (pendekatan terdekat) |
| Objek chart | `OBJ_TREND` + `OBJ_TEXT` + objek panel | `line` + `label` + `table` |
| `keepN` (Pine) / `InpKeepN` (MQL5) | batas objek per jenis | input tersedia, dipakai saat engine diisi |

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
- Alert hanya muncul pada bar terakhir saat chart menerima tick. Sinyal yang terjadi saat MT5 tertutup
  tidak di-alert ulang.
- Tidak ada push notification maupun pengaturan suara di indikator; semuanya mengikuti preferensi
  terminal.

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
| Level beda dengan TradingView | ATR RMA vs SMA, atau script Pine yang terpasang bukan versi Engulf | Pastikan script yang benar dan pahami perbedaan ATR |

## Checklist Verifikasi

1. `Build-MT5.ps1 -NoDeploy` selesai tanpa error.
2. Indikator terpasang dan short name di chart berbunyi `Engulfing Breakout <SYMBOL> <TF>`.
3. Panel tampil dengan 13 baris + kotak probabilitas; nilai `R:R` sama dengan input `InpRrRatio`.
4. Pola baru memunculkan garis `BREAK BODY`; setelah trigger, muncul `PENDING BUY/SELL`.
5. Setelah fill, label entry berubah menjadi `BUY`/`SELL` dan garis entry menjadi solid.
6. Hasil TP/SL mengubah label menjadi `TP HIT`/`SL HIT` dan angka panel bertambah.
7. Scroll dan zoom chart: panel tetap terlihat.
8. Lepas indikator: semua objek `HoekaGATA_Engulf_*` hilang dan `GlobalVariable` `HG_SIG_*`
   dibersihkan.




