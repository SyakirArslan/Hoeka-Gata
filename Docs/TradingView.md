# TradingView (Pine Script)

Ada dua script Pine di `Source/`, dan keduanya untuk strategi yang sama, **Engulfing Breakout**:

| File | Judul `indicator(...)` | Baris | Status |
| --- | --- | --- | --- |
| `Source/HoekaGata_Indicator.pine` | `Engulfing Breakout - Arslan` | 576 | lengkap: pola, state, level, drawing, panel, alert |
| `Source/HoekaGata_Indicator_Engulf.pine` | `Engulfing Breakout` | 291 | draft: input + panel saja, engine masih TODO |

Catatan:

- `HoekaGata_Indicator.pine` **bukan** strategi Wave3 Pro. Isinya sekarang Engulfing Breakout versi
  lengkap, dan strategi Elliott Wave 0-3 tidak lagi ada di repository ini.
- Draft `HoekaGata_Indicator_Engulf.pine` dibuat sebagai kerangka port 1:1 dari indikator MT5, jadi
  setiap baris input diberi komentar nama input MQL5-nya (`// InpMinBodyX`, `// InpBufEntryX`, dst).
- File tidak di-rename supaya script yang sudah tersimpan di TradingView tetap jalan. Lihat
  [Rekomendasi Rename](#rekomendasi-rename).

## Cara Memasang

1. TradingView → **Pine Editor** → **Open** → **New indicator**.
2. Copy seluruh isi file yang diinginkan dari `Source/`, paste, lalu **Save**.
3. **Add to chart**, kemudian cek nama script di pojok kiri atas chart.
   `Engulfing Breakout - Arslan` berarti versi lengkap; `Engulfing Breakout` berarti draft.
4. Atur input (grup 1–6), lalu buat alert dari dialog **Alert** TradingView.

Untuk trading dan validasi signal, selalu pakai versi lengkap. Draft tidak menggambar level, tidak
punya state machine, dan angka panelnya selalu nol.

## Script 1 — Engulfing Breakout (versi lengkap)

**File:** `Source/HoekaGata_Indicator.pine` · **Judul:** `Engulfing Breakout - Arslan`

### Ide

1. Bar `-1` (bar sebelumnya) menjadi acuan: wick (`high[1]`, `low[1]`) dan body (`open[1]`,
   `close[1]`).
2. Bar terakhir harus menenggelamkan bar sebelumnya **dan** body-nya cukup besar dibanding range bar
   sebelumnya.
3. Body bar `-1` menjadi level **BREAK BODY** (trigger), entry pending diletakkan di wick, SL di wick
   berlawanan, TP dari rasio R:R.

Signal hanya dihitung pada bar yang sudah close (`barstate.isconfirmed`). State machine-nya (trigger,
fill, hasil) tetap dievaluasi setiap bar, termasuk bar yang sedang berjalan.

### Deteksi pola

| Komponen | Rumus |
| --- | --- |
| `engBull` (`Strict`) | `open <= low[1] and close >= high[1]` |
| `engBull` (`Loose`) | `close > high[1]` |
| `engBear` (`Strict`) | `open >= high[1] and close <= low[1]` |
| `engBear` (`Loose`) | `close < low[1]` |
| `okBodyX` | `abs(close - open) >= (high[1] - low[1]) * Minimum Body` |
| `okBodyP` | `abs(close - open) / (high[1] - low[1]) * 100 >= Candle Body (%)` |
| `sigBuy` | `barstate.isconfirmed`, candle bullish, bar `-1` bearish, `engBull`, `okBodyX`, `okBodyP` |
| `sigSell` | `barstate.isconfirmed`, candle bearish, bar `-1` bullish, `engBear`, `okBodyX`, `okBodyP` |

Kalau `high[1] == low[1]` (bar sebelumnya tanpa range), `okBodyX` jatuh ke `abs(close - open) > 0` dan
`okBodyP` bernilai `false`.

### Level (BREAK BODY / Entry / SL / TP)

Semua buffer dihitung dari `ta.atr(14)`:

```text
bufEntry     = Breakout Tolerance Entry (ATR) * atr
bufSL        = Breakout Tolerance SL (ATR)    * atr
bufBodyBreak = Body-Break Tolerance (ATR)     * atr
bodyTopPrev  = max(open[1], close[1])
bodyBotPrev  = min(open[1], close[1])
```

| Level | BUY | SELL |
| --- | --- | --- |
| BREAK BODY | `bodyTopPrev + bufBodyBreak` | `bodyBotPrev - bufBodyBreak` |
| Entry (pending) | `high[1] + bufEntry` | `low[1] - bufEntry` |
| SL | `low[1] - bufSL` | `high[1] + bufSL` |
| TP | `entry + rr * risk` | `entry - rr * risk` |

dengan `risk = abs(entry - SL)`.

Guard yang dipakai:

| Guard | Efek |
| --- | --- |
| BUY `break >= entry` | `break = entry - mintick` |
| SELL `break <= entry` | `break = entry + mintick` |
| BUY `SL >= entry` | `SL = entry - max(bufSL, 2 * mintick)` |
| SELL `SL <= entry` | `SL = entry + max(bufSL, 2 * mintick)` |
| `risk <= mintick` atau `abs(TP - entry) <= mintick` | setup tidak dibuat (state tetap 0), garis BREAK BODY tetap digambar |

Contoh BUY (angka fiktif): `high[1] = 2450.50`, `low[1] = 2447.10`, `open[1] = 2448.00`,
`close[1] = 2447.50`, ATR = 2.00, toleransi default.

```text
bodyTopPrev = 2448.00        bodyBotPrev = 2447.50
break       = 2448.00 + 0.00        = 2448.00
entry       = 2450.50 + 0.20        = 2450.70
SL          = 2447.10 - 0.20        = 2446.90
risk        = 3.80
TP          = 2450.70 + 2.0 * 3.80  = 2458.30
```

### State machine

| State | Arti |
| --- | --- |
| `0` | idle, belum ada setup |
| `1` / `-1` | setup BUY / SELL sudah dibuat, menunggu break body |
| `2` / `-2` | break body tersentuh, pending entry aktif |
| `3` / `-3` | entry terisi, posisi berjalan |

Transisi (contoh BUY; SELL adalah cerminannya):

| Dari | Syarat | Efek |
| --- | --- | --- |
| `0` → `1` | `sigBuy` dan setup valid | hitung level, gambar garis + label |
| `1` → `2` | `high >= pBreak` pada bar setelah setup (`bar_index > setupBar`) | pending armed, alert `BREAK BODY TRIGGERED` |
| `2` → `3` | `high >= pEntry` | fill, `Entries + 1`, garis entry jadi solid + warna arah, label `BUY <entry>` |
| `3` → `0` | `low <= pSL` (**dicek lebih dulu**) | `SL Hits + 1`, label `BUY SL` / `SL HIT` |
| `3` → `0` | `high >= pTP` | `TP Hits + 1`, label `BUY TP` / `TP HIT` |
| `1`/`2` → `0` | sinyal berlawanan dan `Cancel on Opposite Signal = true` | `Cancelled + 1`, garis/label setup dihapus |

Detail yang mudah terlewat:

- Fill bisa terjadi pada bar yang sama dengan trigger, karena pengecekan `state == 2` langsung menyusul
  setelah `state := 2`. Yang tidak bisa terjadi pada bar setup itu sendiri hanyalah break body.
- Hasil TP/SL baru dievaluasi pada bar setelah fill (`bar_index > entryBar`), jadi wick bar fill itu
  sendiri tidak dinilai.
- Cancel hanya berlaku sebelum fill. Posisi yang sudah aktif tidak ditutup oleh sinyal berlawanan.
- Saat TP/SL kena, garis dan label "dibekukan" di `bar_index + extendB`; referensi body-break aktif
  dilepas, tetapi salinan historinya tetap ada di array.

### Objek yang digambar

| Objek | Kapan | Keterangan |
| --- | --- | --- |
| Garis BREAK BODY + label `BREAK BODY` | saat setup dibuat | style mengikuti `Body-Break Line Style`, warna `Body-Break` |
| Garis entry (dashed) | saat setup dibuat | warna `Entry Line`, berubah solid + warna arah setelah fill |
| Garis SL | saat setup dibuat | mulai dari bar `-1`, warna `Stop Loss` |
| Garis TP | saat setup dibuat | warna `Take Profit` |
| Label `PENDING BUY/SELL <entry>`, `SL <sl>`, `TP <tp>` | saat setup dibuat | background transparan, teks mengikuti ukuran label |
| Label hasil `BUY SL`, `SL HIT`, `BUY TP`, `TP HIT` | saat TP/SL kena | teks dan warna berubah di label yang sama |

Garis/label setup yang masih aktif diperpanjang setiap bar sampai `bar_index + extendB`. Tidak ada
handler hapus manual: perubahan input memicu recalculate penuh sehingga semua objek dibuat ulang dari
nol.

### Input

| Grup | Input | Default | Padanan MQL5 |
| --- | --- | --- | --- |
| 1. ENGULFING PATTERN | `Pattern Mode` | `Strict` | `InpPatMode` |
| 1. ENGULFING PATTERN | `Minimum Body` | 1.2 | `InpMinBodyX` |
| 1. ENGULFING PATTERN | `Candle Body (%)` | 50 | `InpMinBodyP` |
| 2. ENTRY | `Breakout Tolerance Entry (ATR)` | 0.10 | `InpBufEntryX` |
| 2. ENTRY | `Breakout Tolerance SL (ATR)` | 0.10 | `InpBufSLX` |
| 2. ENTRY | `Body-Break Tolerance (ATR)` | 0.00 | `InpBodyBreakTol` |
| 2. ENTRY | `Cancel on Opposite Signal` | `true` | `InpCancelOpp` |
| 3. RISK & REWARD | `Risk : Reward 1 :` | 2.0 | `InpRrRatio` |
| 4. DISPLAY | `Entry / SL / TP Lines` | `true` | `InpShowLines` |
| 4. DISPLAY | `Label Size` | `Small` | `InpLabelSize` |
| 4. DISPLAY | `Line Style` | `Dashed` | `InpLineStyle` |
| 4. DISPLAY | `Line Length` | 3 | `InpExtendB` |
| 4. DISPLAY | `Displayed Setups` | 3 | `InpKeepN` |
| 4b. RESULTS SUMMARY | `Show Panel` | `true` | `InpShowTable` |
| 4b. RESULTS SUMMARY | `Panel Text Size` | `Small` | `InpPanelSize` |
| 5. BODY-BREAK | `Body-Break Line Style` | `Dotted` | `InpBodyBreakStyle` |
| 6. COLORS | `Entry Line` | `#787B86` | `InpCEntryLine` |
| 6. COLORS | `Stop Loss` | `#EF5350` | `InpCSL` |
| 6. COLORS | `Take Profit` | `#26A69A` | `InpCTP` |
| 6. COLORS | `Body-Break` | `#BDBDBD` | `InpCBodyBreak` |
| 6. COLORS | `BUY Text` | `#26A69A` | `InpCBuyText` |
| 6. COLORS | `SELL Text` | `#EF5350` | `InpCSellText` |

Nama input berbeda dari MQL5 (Pine memakai label yang ramah dibaca), tetapi arti dan default-nya sama.

### Panel statistik

Tabel `2 × 14` di kanan atas (`table.new(position.top_right, ...)`):

| Row | Kolom 0 | Kolom 1 |
| --- | --- | --- |
| 0 | `Engulfing Breakout` (merged, center) | — |
| 1 | `By Syakir Arslan (modified)` (merged, center) | — |
| 2 | `SETUP` (merged, header blok) | — |
| 3 | `R:R` | `1:<rr>` |
| 4 | `Status` | `BUY` / `SELL` / `PENDING BUY` / `PENDING SELL` / `NONE` |
| 5 | `Cancelled` | jumlah setup yang dibatalkan |
| 6 | `RESULTS` (merged, header blok) | — |
| 7 | `Signals` | jumlah pola terdeteksi |
| 8 | `Entries` | jumlah fill |
| 9 | `Buy WR` | `<winrate> (<nBuyRun>)` |
| 10 | `Sell WR` | `<winrate> (<nSellRun>)` |
| 11 | `Max TP Run` | streak TP terpanjang |
| 12 | `Max SL Run` | streak SL terpanjang |
| 13 | `Overall: <winrate>` (merged, center) | — |

Catatan:

- Winrate dihitung dari trade yang sudah selesai (`wins / (wins + losses)`); kolom dalam kurung adalah
  jumlah entry, bukan jumlah trade selesai. `n/a` muncul bila belum ada trade selesai.
- `Signals` bertambah setiap pola terdeteksi, termasuk saat masih ada setup aktif yang belum selesai.
- Panel hanya digambar pada bar terakhir (`barstate.islast`). Bila `Show Panel` dimatikan,
  `table.clear()` dipanggil sehingga panel hilang tanpa menghapus tabelnya.
- Sel yang di-merge di-set sekali lewat flag `probabilityTableMerged`.

### Alert

Enam `alertcondition` untuk dipakai di dialog Alert TradingView:

| Title | Isi pesan |
| --- | --- |
| `Break Body Triggered` | `Break body touched - pending order armed at wick.` |
| `BUY Entry Active` | `BUY Entry is active.` |
| `SELL Entry Active` | `SELL Entry is active.` |
| `Take Profit Hit` | `The active position reached Take Profit.` |
| `Stop Loss Hit` | `The active position reached Stop Loss.` |
| `Setup Cancelled` | `The setup was cancelled before Entry.` |

Selain itu ada lima `alert()` dinamis (`alert.freq_once_per_bar`) yang membawa level harga:

```text
<sym> <tf> | BREAK BODY TRIGGERED <BUY|SELL> | PENDING @ <entry>
<sym> <tf> | ENTRY <BUY|SELL> @ <entry> | SL <sl> | TP <tp>
<sym> <tf> | TP HIT <BUY|SELL> @ <tp>
<sym> <tf> | SL HIT <BUY|SELL> @ <sl>
<sym> <tf> | CANCELLED <BUY|SELL> | SL <sl>
```

`alertcondition` perlu diaktifkan manual di dialog Alert; `alert()` hanya terkirim bila ada alert yang
sedang dibuat untuk script tersebut.

### Perilaku yang perlu diketahui

- Signal pola memerlukan bar yang sudah close, tetapi trigger/fill/hasil bisa terjadi intrabar. Di
  chart realtime, level bisa berubah status beberapa kali dalam satu bar sebelum bar itu selesai.
- SL dicek sebelum TP. Bila TP dan SL tersentuh pada bar yang sama, yang dihitung adalah SL.
- Setup baru hanya dibuat saat `state == 0`. Sinyal yang muncul saat masih ada setup berjalan akan
  diabaikan (atau membatalkan setup bila `Cancel on Opposite Signal` aktif dan arahnya berlawanan).
- `Displayed Setups` (`keepN`) membatasi objek: garis/label entry-SL-TP dipangkas ke `keepN * 3`,
  body-break ke `keepN`.
- Bila guard level gagal (risk terlalu kecil), garis BREAK BODY tetap digambar tetapi label
  PENDING/SL/TP tidak muncul.
- Perubahan input memicu recalculate penuh; semua objek dibuat ulang dari nol, sehingga tidak ada sisa
  garis dari pengaturan sebelumnya.
- Label memakai background transparan (`color.new(color.black, 100)`), jadi hanya teks yang terlihat.

## Script 2 — Draft lama

**File:** `Source/HoekaGata_Indicator_Engulf.pine` · **Judul:** `Engulfing Breakout` · 291 baris

File ini adalah kerangka (skeleton) yang dibuat sebagai port 1:1 dari indikator MT5. Yang **sudah**
ada:

- Seluruh input dan warna, dengan komentar nama input MQL5 di setiap baris.
- Panel `2 × 14` dengan susunan baris yang sama seperti versi lengkap, hanya tanpa merge sel.
- Model data statistik (signal, entry, win/loss per arah, streak, cancel) dan helper format winrate.

Yang **belum** ada (masih TODO di dalam file):

- `f_detect_engulfing()` — deteksi pola (padanan `DetectEngulfing` di MQL5).
- `f_compute_levels()` — level BREAK BODY / Entry / SL / TP (padanan `EngulfComputeLevels`).
- `RecalculateEngulfing()` — loop per bar + transisi 6 state.
- Helper drawing (garis/label Entry, SL, TP, Body-Break).
- Alert (`BREAK BODY TRIGGERED`, `ENTRY`, `TP HIT`, `SL HIT`, `CANCELLED`).

Karena itu draft hanya menggambar panel dengan angka nol. Jangan dipakai untuk trading; gunakan versi
lengkap. Draft dipertahankan sebagai rujukan pemetaan input MQL5 ↔ Pine.

## Perbandingan Pine vs MT5

| Aspek | Pine (`HoekaGata_Indicator.pine`) | MT5 (`HoekaGataIndicator.mq5`) |
| --- | --- | --- |
| Status engine | lengkap | lengkap |
| Mode pola | `Pattern Mode` `Strict` / `Loose` | `InpPatMode` `Strict` / `Loose` |
| ATR | `ta.atr(14)` (RMA) | rata-rata sederhana True Range 14 bar |
| Panel | tabel `2 × 14`, blok `SETUP` / `RESULTS` | 13 baris objek chart + kotak footer terpisah |
| Label statistik | `Entries`, `Buy WR`, `Sell WR`, `Cancelled`, `Max TP Run`, `Max SL Run` | `Runs`, `Buy %`, `Sell %`, `Cancel`, `TP Streak`, `SL Streak` |
| Status | `PENDING BUY` / `PENDING SELL` / `BUY` / `SELL` / `NONE` | sama |
| Objek chart | `line`, `label`, `table` | `OBJ_TREND`, `OBJ_TEXT`, objek panel |
| Alert | 6 `alertcondition` + 5 `alert()` | 5 `Alert()` |
| Integrasi EA | tidak ada (manual) | buffer 0..3 + `GlobalVariable` `HG_SIG_*` |
| Pemangkasan | `keepN * 3` / `keepN` | `InpKeepN` per jenis objek |

Selisih ATR (RMA vs rata-rata sederhana) membuat level bisa berbeda tipis pada bar yang sama. Itu
disengaja dan bukan bug; detailnya ada di
[`Docs/Indicator_MT5.md`](Indicator_MT5.md#perbedaan-dengan-pine).

## Rekomendasi Rename

Nama file saat ini tidak mencerminkan isi, karena `_Indicator` justru versi lengkap dan `_Engulf`
justru draft. Usulan:

```text
Source/HoekaGata_Indicator.pine        -> Source/HoekaGata_EngulfingBreakout.pine
Source/HoekaGata_Indicator_Engulf.pine -> Source/HoekaGata_EngulfingBreakout_Draft.pine
```

Setelah rename, perbarui tautan di `README.md` dan dokumen ini. Script yang sudah tersimpan di
TradingView tidak terpengaruh karena TradingView menyimpan salinan kode, bukan menaut ke file.

Alternatif yang lebih rapi: hapus draft kalau pemetaan input MQL5 sudah tidak diperlukan, sehingga
hanya ada satu file Pine per strategi.

## Checklist TradingView

1. Script yang terpasang berjudul `Engulfing Breakout - Arslan` (versi lengkap).
2. Pola baru memunculkan garis `BREAK BODY` beserta label `PENDING BUY <entry>`, `SL <sl>`, `TP <tp>`.
3. Setelah break body, label status panel berubah menjadi `PENDING BUY` / `PENDING SELL`.
4. Setelah fill, garis entry menjadi solid berwarna arah dan label berubah menjadi `BUY <entry>` /
   `SELL <entry>`; `Entries` bertambah.
5. TP/SL mengubah label menjadi `TP HIT` / `SL HIT`, dan `Max TP Run` / `Max SL Run` ikut bergerak.
6. `Cancel on Opposite Signal` yang aktif membatalkan setup sebelum fill dan menaikkan `Cancelled`.
7. `R:R` di panel sama dengan input `Risk : Reward 1 :`.
8. Zoom/scroll chart: garis level mengikuti `Line Length`, dan jumlah setup yang tampil sesuai
   `Displayed Setups`.
