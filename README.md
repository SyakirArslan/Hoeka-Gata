# HoekaGata Trading System

Repository ini berisi trading system **HoekaGata Engulfing Breakout** untuk MetaTrader 5 dan
TradingView: indikator MT5 sebagai signal engine, EA MT5 sebagai eksekutor, dan Pine Script sebagai
sumber aturan sekaligus alat validasi visual.

`Source/` berisi dua script Pine untuk strategi yang sama: versi **lengkap**
(`HoekaGata_Indicator.pine`, engine pola/state/level/panel/alert aktif) dan **draft lama**
(`HoekaGata_Indicator_Engulf.pine`, baru berisi input + panel).

## Komponen

| Komponen | Path | Dokumentasi |
| --- | --- | --- |
| Indikator MT5 (Engulfing Breakout) | `Main/MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5` | [`Docs/Indicator_MT5.md`](Docs/Indicator_MT5.md) |
| EA MT5 (eksekutor signal) | `Main/MQL5/Experts/HokaGATA_Algo/HoekaGataAlgo.mq5` | [`Docs/EA_MT5.md`](Docs/EA_MT5.md) |
| Pine Script Engulfing Breakout (lengkap) | `Source/HoekaGata_Indicator.pine` | [`Docs/TradingView.md`](Docs/TradingView.md) |
| Pine Script Engulfing Breakout (draft lama) | `Source/HoekaGata_Indicator_Engulf.pine` | [`Docs/TradingView.md`](Docs/TradingView.md) |
| Mockup panel hasil (HTML) | `Main/Docs/panel-mockup.html` | Acuan layout panel indikator |
| Spesifikasi requirement entry (HTML) | `Main/Docs/entry-requirement-final.html` | Aturan final: pemicu, fill, dan cancel di bar pola (R1.1–R1.7, D1–D5) |
| Requirement intrabar / anti-VOID (HTML) | `Main/Docs/entry-requirement-intrabar-lock.html` | R2: setup intrabar dikunci, level beku, tidak ada lagi jalur VOID (D6–D10 = A, v2.04) |
| Visual aturan A = P (HTML) | `Main/Docs/entry-visual-arm-p.html` | Dua outcome di bar pola: filled vs canceled, plus konsekuensinya |
| Animasi alur pending → fill/cancel (HTML) | `Main/Docs/entry-animation.html` | Replay modus intrabar: pending dan alert arm/fill terbit saat candle S berjalan (skenario fill dan cancel), plus panel dan log alert |
| Build & deploy otomatis | `Main/Tools/Build-MT5.ps1` | [`Docs/Indicator_MT5.md`](Docs/Indicator_MT5.md#build-dan-deploy) |
| AI skill (build & MT5) | `.claude/skills/hoekagata-build/SKILL.md`, `.claude/skills/hoekagata-mt5/SKILL.md` | Alur compile/deploy otomatis untuk agent |
| Position Sizer (pihak ketiga) | `Main/MQL5/RiskCalculator/` | Utility risk calculator, bukan bagian signal engine — analisa: [`Docs/RiskCalculator.md`](Docs/RiskCalculator.md), mockup panel: [`Main/Docs/position-sizer-panel.html`](Main/Docs/position-sizer-panel.html) |
| ~~Risk Calculator (EA kita)~~ | ~~`Main/MQL5/Experts/HokaGATA RiskCalc/`~~ | **DIHAPUS 2026-10-24.** EA `HoekaGataRiskCalculator` dihapus dan tidak pernah di-commit, jadi tidak bisa dipulihkan lewat git. Sisa desainnya: [`Docs/RiskCalculator_EA.md`](Docs/RiskCalculator_EA.md) (arsip) + [`Main/Docs/mix-risk-panel.html`](Main/Docs/mix-risk-panel.html) |

## PENTING: dua file Pine, beda kelengkapan

Kedua file berisi strategi yang sama (**Engulfing Breakout**), hanya berbeda kelengkapan:

| Nama file | Isi sebenarnya |
| --- | --- |
| `Source/HoekaGata_Indicator.pine` | **Engulfing Breakout lengkap** — `indicator("Engulfing Breakout - Arslan", ...)`, 576 baris, engine pola/state/level/panel/alert aktif |
| `Source/HoekaGata_Indicator_Engulf.pine` | **Engulfing Breakout draft** — `indicator("Engulfing Breakout", ...)`, 291 baris, hanya input + panel; engine masih TODO |

File tidak di-rename supaya script yang sudah terpasang di TradingView tidak putus. Saat memasang ke
TradingView, **buka file lalu cek baris `indicator(...)`**:

- `indicator("Engulfing Breakout - Arslan", ...)` → versi lengkap, pakai ini untuk validasi signal.
- `indicator("Engulfing Breakout", ...)` → draft lama, jangan dipakai untuk trading.

Perbedaan input: versi lengkap menambahkan `Pattern Mode` (`Strict` / `Loose`) yang tidak ada di draft,
dan `Panel Text Size` di draft masih punya opsi `Large` (versi lengkap hanya `Tiny` / `Small` /
`Normal`).

Rekomendasi jangka panjang: rename menjadi `HoekaGata_EngulfingBreakout.pine` (lengkap) dan
`HoekaGata_EngulfingBreakout_Draft.pine` (draft), lalu perbarui tautan di dokumen ini dan
[`Docs/TradingView.md`](Docs/TradingView.md).

## Alur Sistem

```text
Pine — Engulfing Breakout  (aturan acuan)
        |
        v
MT5 — HoekaGataIndicator   (signal engine: pola, level, panel, alert)
        |  buffer 0..3 + GlobalVariable "HG_SIG_*"
        v
MT5 — HoekaGataAlgo EA     (filter risk/spread/time + eksekusi order)
```

1. Indikator MT5 mendeteksi pola engulfing, menghitung level **BREAK BODY / Entry / SL / TP**,
   menggambar objek chart, mengisi panel statistik, dan mem-publish signal.
2. EA MT5 membaca signal dari indikator (`iCustom` buffer atau `GlobalVariable` yang dipublish
   indikator), lalu mengeksekusi order bila semua filter lolos.
3. EA tidak menghitung ulang pola; seluruh keputusan arah entry berasal dari indikator.

## Struktur Folder

```text
Main/
  Docs/
    panel-mockup.html                Mockup HTML panel statistik indikator (acuan layout)
    entry-requirement-final.html     Spesifikasi final requirement entry (R1.1-R1.7, D1-D5)
    entry-requirement-intrabar-lock.html  R2: kunci setup intrabar (anti-VOID, level beku, v2.04)
    entry-visual-arm-p.html          Visual aturan A = P: filled vs canceled di bar pola
    entry-animation.html             Animasi modus intrabar: pending & alert arm/fill saat candle S berjalan
  Tools/
    Build-MT5.ps1                    Compile + deploy indikator & EA ke terminal MT5
  MQL5/
    Indicators/HokaGATA/
      HoekaGataIndicator.mq5         Entry point indikator (tipis: OnInit/OnCalculate/OnDeinit)
      HoekaGataIndicator.ex5         Hasil compile
      Includes/
        HoekaGataIndicator_Config.mqh    Input, enum, buffer, konstanta state
        HoekaGataIndicator_Engulf.mqh    Deteksi pola + ATR
        HoekaGataIndicator_Core.mqh      Engine replay + state machine + buffer + alert
        HoekaGataIndicator_Drawing.mqh   Helper objek garis/label
        HoekaGataIndicator_Panel.mqh     Panel statistik (objek chart, tanpa canvas)
    Experts/HokaGATA_Algo/
      HoekaGataAlgo.mq5              Entry point EA + input + konstanta panel
      HoekaGataAlgo.ex5              Hasil compile
      Includes/
        HoekaGataAlgo_Config.mqh         Baca/tulis konfigurasi panel (GlobalVariable)
        HoekaGataAlgo_Trading.mqh        Signal, filter, risk lot, eksekusi, log
        HoekaGataAlgo_Panel.mqh          Panel kontrol EA (2 halaman)
    RiskCalculator/                  Position Sizer pihak ketiga (utility opsional)
Source/
  HoekaGata_Indicator.pine           Isi: Engulfing Breakout (versi lengkap)
  HoekaGata_Indicator_Engulf.pine    Isi: Engulfing Breakout (draft lama)
Docs/
  Indicator_MT5.md                   Dokumentasi lengkap indikator MT5
  EA_MT5.md                          Dokumentasi lengkap EA MT5
  TradingView.md                     Dokumentasi kedua script Pine
```

## Instalasi ke MT5

### Cara cepat (otomatis)

```powershell
cd Main\Tools
.\Build-MT5.ps1                       # compile + deploy indikator & EA
.\Build-MT5.ps1 -Target Indicator     # hanya indikator
.\Build-MT5.ps1 -Target EA -NoDeploy  # compile saja, tanpa copy ke terminal
.\Build-MT5.ps1 -Restart              # deploy lalu restart terminal64.exe
```

Script akan mencari folder data terminal yang sedang dipakai, compile dengan `metaeditor64.exe`,
berhenti pada error pertama, menyalin source + `.ex5` ke `MQL5\...`, lalu memverifikasi setiap file
dengan SHA256.

### Cara manual

1. Copy `Main/MQL5/Indicators/HokaGATA/` ke `MQL5/Indicators/HokaGATA/`.
2. Copy `Main/MQL5/Experts/HokaGATA_Algo/` ke `MQL5/Experts/HokaGATA_Algo/`.
3. Compile `HoekaGataIndicator.mq5` lalu `HoekaGataAlgo.mq5` di MetaEditor.
4. Restart MT5 atau refresh Navigator jika program belum muncul.

> **Jangan rename** file atau folder indikator. EA mencari indikator dengan nama
> `HokaGATA\HoekaGataIndicator`, dan properti `#property tester_indicator` mengunci path yang sama.

## Cara Pakai

### Indikator MT5

1. Pasang `HoekaGataIndicator` pada chart (mis. XAUUSD H1/H4).
2. Atur group input `1. ENGULFING PATTERN` sampai `6. COLORS` (lihat
   [`Docs/Indicator_MT5.md`](Docs/Indicator_MT5.md#referensi-input)).
3. Panel statistik muncul di sudut kanan atas: status setup, R:R, jumlah signal/entry, win rate per
   arah, streak TP/SL, dan probabilitas keseluruhan.
4. Alert muncul pada 6 kejadian: break body, entry filled, entry canceled (close bar pola), TP hit,
   SL hit, dan cancel karena pola berlawanan.

### EA MT5

1. Pasang indikator pada chart lebih dulu, lalu pasang EA pada symbol/timeframe yang sama.
2. Atur risk %, filter spread, time window, arah trading, dan magic number.
3. Aktifkan `Algo` dari panel EA hanya setelah konfigurasi benar.

### TradingView

1. Buka TradingView, lalu Pine Editor.
2. Paste isi file Pine yang diinginkan dan cek nama pada baris `indicator(...)`.
3. Save, lalu tambahkan ke chart.

## Kontrak Signal (ringkas)

Indikator mengekspos dua jalur data untuk EA:

| Jalur | Isi |
| --- | --- |
| Buffer indikator | `0` = harga entry BUY, `1` = harga entry SELL, `2` = SL, `3` = TP (`EMPTY_VALUE` bila tidak ada signal) |
| GlobalVariable | `HG_SIG_<chartID>_C_T/_D/_E/_SL/_TP` (bar aktif), `HG_SIG_<chartID>_P_*` (bar sebelumnya), `HG_SIG_<chartID>_HB` (heartbeat) |

EA memprioritaskan GlobalVariable yang dipublish indikator; bila tidak ada, EA membaca buffer lewat
handle `iCustom`. Detail lengkap: [`Docs/Indicator_MT5.md`](Docs/Indicator_MT5.md#kontrak-signal-untuk-ea).

## Catatan Penting

- Indikator memakai 4 buffer dan 2 plot `DRAW_NONE`; jumlah buffer tidak boleh diubah karena EA
  membaca indeks 0..3.
- Sejak **v2.02** aturan entry adalah **A = P**: pemicu BREAK BODY, fill, dan cancel semuanya
  dievaluasi di bar pola. Tidak ada pending yang menunggu ke bar berikutnya, jadi dengan default panel
  tidak pernah menampilkan `PENDING`; setup berakhir `BUY`/`SELL` (filled) atau `NONE` (canceled).
- Sejak **v2.03** pola hanya dibuat untuk bar yang **sudah close** (`i < rates_total - 1`), sehingga
  panel, counter, dan buffer EA tidak berubah di tengah candle; EA tetap entry di tick pertama setelah
  bar pola close. De-dup alert juga disimpan di `GlobalVariable` `HG_AL_*`, jadi re-attach / ganti
  timeframe tidak mengulang alert bar terakhir.
- **Pending saat candle pola berjalan** tersedia lewat input `InpAllowFormingBar` (default `false`).
  Bila diaktifkan, guard `i < rates_total - 1` dilepas untuk deteksi pola/trigger/fill, jadi level dan
  label `PENDING BUY/SELL` muncul di dalam candle S dan panel menampilkan `PENDING`. Alert ikut
  intrabar: `BREAK BODY … pending entry …` terbit begitu pola tentatif sah (siap dipakai memasang
  pending) dan `ENTRY … FILLED` terbit begitu harga menyentuh entry, masing-masing sekali per bar
  (dedupe `EngulfAlertOnce`). Cancel-at-close dan aturan "setup tanpa break body" tetap menunggu bar
  close (pada candle berjalan `close` masih harga terakhir), dan alert `CANCELED` juga baru terbit di
  close. Sejak **v2.04** setup seperti itu dikunci (`g_engulfLocks` di `Core.mqh`): level yang
  diumumkan dibekukan, yang filled tetap `BUY`/`SELL` sampai TP/SL (buffer EA tetap terisi), yang armed
  berakhir `CANCELED` di close — **tidak ada lagi jalur VOID**. EA dengan `InpUseClosedBarSignal =
  false` tetap entry pada sinyal yang belum confirmed (itu memang tujuan modus intrabar). Requirement:
  `Main/Docs/entry-requirement-intrabar-lock.html`.
- Panel statistik memakai `OBJ_LABEL` / `OBJ_RECTANGLE_LABEL` dengan latar transparan; teks putih
  dirancang untuk theme chart gelap.
- Panel di-repaint dari snapshot cache pada `CHARTEVENT_CHART_CHANGE` / `CHARTEVENT_MOUSE_WHEEL`,
  jadi tidak hilang saat chart di-scroll atau di-zoom.
- Di Strategy Tester, EA membuat instance indikator sendiri (`#property tester_indicator`) dan
  memakai input indikator hasil compile. Compile ulang indikator setiap kali input default berubah.
- File `.ex5` ikut di-commit untuk kemudahan install, tetapi source `.mq5` / `.mqh` tetap acuan utama.
- Script Pine `HoekaGata_Indicator_Engulf.pine` masih **draft**: input, warna, dan panel sudah 1:1
  dengan MQL5, tetapi deteksi pola, state machine, drawing, dan alert belum diisi.
- `Main/MQL5/RiskCalculator/` adalah Position Sizer pihak ketiga; tidak dipakai oleh indikator
  maupun EA.
- EA `HoekaGataRiskCalculator` (`Experts\HokaGATA RiskCalc`) sudah **dihapus**. Source di repo sudah
  tidak ada, jadi bila namanya masih muncul di Navigator MT5, sisa file di folder data terminal belum
  dibersihkan. Hapus manual:
  1. Tutup MT5, lalu hapus `MQL5\Experts\HokaGATA RiskCalc\` di folder data terminal
     (**File → Open Data Folder**).
  2. Hapus baris `HoekaGataRiskCalculator ...=` di `config\terminal.ini` (bagian
     `[IndicatorPropertyPage]`) selama MT5 masih tertutup.
  3. Buka MT5 lagi dan refresh Navigator (klik kanan → **Refresh**).
  Nama `HokaGATA Risk Calculator` (dengan spasi) adalah **Position Sizer pihak ketiga**, bukan EA ini;
  jangan dihapus kalau masih dipakai.

## Dokumentasi

- [`Docs/Indicator_MT5.md`](Docs/Indicator_MT5.md) — arsitektur indikator, aturan pola, matematika
  level, state machine, objek chart, alert, panel, buffer, dan referensi input.
- [`Docs/EA_MT5.md`](Docs/EA_MT5.md) — input EA, urutan filter, perhitungan lot, pembacaan signal,
  panel kontrol, dan troubleshooting.
- [`Docs/TradingView.md`](Docs/TradingView.md) — kedua script Pine: aturan, input, panel, alert, dan
  perbandingan dengan implementasi MT5.
- [`Docs/RiskCalculator.md`](Docs/RiskCalculator.md) — analisa logic & algoritma Position Sizer
  pihak ketiga: alur kalkulasi lot, rumus risiko/komisi/margin, temuan, dan perbandingan dengan
  sizing EA HoekaGATA.
- [`Main/Docs/position-sizer-panel.html`](Main/Docs/position-sizer-panel.html) — mockup visual panel
  Position Sizer (5 tab, geometri 350/500 × 570 px, tema light/dark) plus tabel baris ↔ baris kode,
  dipakai sebagai bahan penyesuaian sebelum panel risiko HoekaGATA dibuat.

## Kredit

HoekaGata Engulfing Breakout — **by Syakir Arslan**.

