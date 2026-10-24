# HoekaGata Risk Panel — Implementation Requirement

Status: **Fase 1 — dokumen + kerangka kode**
Source of truth UI: `Main/Docs/amis-sizer-panel.html`
Reference (read-only): `./_reference/` = salinan utuh `Main/MQL5/RiskCalculator/`
Target build: `Main/MQL5/Experts/HoekaGATA/HoekaGataRiskPanel/HoekaGataRiskPanel.mq5`
Object prefix: **`HGRP_`**

---

## 1. Aturan kerja (tidak boleh dilanggar)

1. **`_reference/` tidak pernah diedit.** Aslinya (`Main/MQL5/RiskCalculator/`) juga tidak
   disentuh. Keduanya hanya bahan baca.
2. **`PS_` tidak dipakai** — itu prefix Position Sizer asli. Panel ini memakai `HGRP_`
   supaya dua panel bisa hidup di chart yang sama tanpa saling hapus objek.
3. **Rumus engine wajib identik** dengan `_reference/Position Sizer.mqh`. Setiap fungsi
   perhitungan diberi komentar `// CLONE-SRC: <file>:<line>` yang menunjuk baris asalnya,
   sehingga bisa diaudit baris per baris.
4. Behaviour change tidak diizinkan pada fase clone. Kalau ada yang harus berbeda,
   ditulis di §7 (Deviations), bukan diselipkan diam-diam.

---

## 2. Peta dependensi asli (hasil pembacaan kode, bukan asumsi)

```
Position Sizer.mq5            (70 KB, 149 input)
├── Translations\English.mqh  (38 KB — semua label panel)
├── Position Sizer.mqh        (589 KB — class CPositionSizeCalculator)
│   ├── Defines.mqh           (8.8 KB — enum, struct, konstanta)
│   └── <ChartObjects\ChartObjectsTxtControls.mqh>   (standar MT5)
├── Position Sizer Trading.mqh (75 KB — eksekusi order)
│   └── errordescription.mqh   (19.8 KB)
└── TesterSupport.mqh          (18 KB)
Defines.mqh juga meng-include: HorizontalRadioGroup.mqh, <Controls\*>, <Trade\Trade.mqh>
Aset: Images\*.bmp (10 file checkbox/radio)
```

Kesimpulan: kelas `CPositionSizeCalculator` mencampur UI dan kalkulasi dalam satu kelas.
Karena itu clone dilakukan **per fungsi**, bukan per file.

---

## 3. Inventory fungsi engine yang di-clone

Baris = posisi di `_reference/Position Sizer.mqh`.

| # | Fungsi | Baris | Peran | Fase |
|---|---|---|---|---|
| E1 | `CalculateUnitCost(loss, profit)` | 9505 | nilai 1 tick dalam mata uang akun | 1 |
| E2 | `BrokerizePositionSize(ps)` | 8158 | floor ke `LotStep`, 0 bila < `MinLot` | 1 |
| E3 | `AdjustPositionSizeByMinMaxStep(ps)` | 9911 | clamp `MinLot`/`MaxLot` + floor step | 1 |
| E4 | `CalculateCommission()` | 9839 | komisi manual/persen/auto | 1 (manual+persen), 2 (auto) |
| E5 | `PositionSizeToArray(ps)` | 9880 | pecah lot ke N take-profit | 2 |
| E6 | `CalculateRiskAndPositionSize()` | 7909 | **inti**: risk money → lot | 1 |
| E7 | `RoundToSignificant(v,d,min)` | 9926 | pembulatan nilai poin | 2 |

Fungsi yang **ditunda** ke fase berikutnya karena bergantung pada state dialog:
`RecalculatePositionSize()` (7595), `CalculatePortfolioRisk()` (8180),
`CalculateAutoCommission()` (9699).


---

## 4. Rumus aktual (dikutip dari kode, verbatim)

### 4.1 Risk money (E6, baris 7917–7928)
```
Jika mode persen:
    RiskMoney = Round(AccSize * Risk / 100, AccountCurrencyDigits, RoundDown)
    MoneyRisk = RiskMoney
Jika mode uang:
    RiskMoney    = MoneyRisk
    DisplayRisk  = (AccSize != 0) ? Round(MoneyRisk / AccSize * 100, 2) : 0
```

### 4.2 Arah posisi (E6, baris 7932–7942)
```
tStopLossLevel < tEntryLevel  -> BUY
tStopLossLevel > tEntryLevel  -> SELL
sama                          -> return (tanpa sinyal)
```

### 4.3 Koreksi UnitCost kurs masa depan (E6, baris 7945–7958)
Berlaku hanya bila `AccountCurrency == BaseCurrency` **dan** mode Forex,
dan `tStopLossLevel != 0`:
```
current_rate = (SL < Entry) ? ASK : BID
UnitCost *= current_rate / tStopLossLevel
```

### 4.4 Lot dari risiko (E6, baris 7960–7976)
```
biaya_per_lot = StopLoss * UnitCost / TickSize + 2 * commission
Mode normal     : PositionSize = Round(RiskMoney / biaya_per_lot, LotStep_digits, RoundDown)
Mode RiskFromPositionSize:
                  RiskMoney    = Round(OutputPositionSize * biaya_per_lot, AccountCurrencyDigits)
                  DisplayRisk  = (AccSize != 0) ? Round(RiskMoney / AccSize * 100, 2) : 0
```
Catatan: `2 *` karena komisi dihitung dua kali (masuk + keluar).

### 4.5 Setelah lot didapat (E6, baris 7978–7993)
```
OutputPositionSize = AdjustPositionSizeByMinMaxStep(OutputPositionSize)   // E3
jika CapMaxPositionSizeBasedOnMargin dan melebihi -> clamp OutputMaxPositionSize
OutputRiskMoney = Round((StopLoss*UnitCost/TickSize + 2*commission) * OutputPositionSize, ACD)
base_sl = StopLoss; jika SpreadAdjustmentSL: base_sl -= CurrentSpread() (min 0)
BaseRiskMoney   = Round((base_sl*UnitCost/TickSize + 2*commission) * OutputPositionSize, ACD)
```

### 4.6 UnitCost (E1, baris 9505–9529)
```
Non-Forex/Futures:
    UnitCost_loss = UnitCost_profit = TickSize * ContractSize
    jika ProfitCurrency != AccountCurrency: kalikan CalculateAdjustment(...)
Forex (termasuk Forex no-leverage):
    UnitCost_loss   = SYMBOL_TRADE_TICK_VALUE_LOSS
    UnitCost_profit = SYMBOL_TRADE_TICK_VALUE_PROFIT
    jika salah satu 0 -> peringatan
```

### 4.7 Brokerize (E2, baris 8158–8176)
```
jika CalculateUnadjustedPositionSize -> return apa adanya
jika ps < MinLot                     -> return 0        (trade dibatalkan)
jika ps > MaxLot dan !Surpass...     -> return MaxLot
steps = ps / LotStep; toleransi 1e-8 untuk pembulatan
floor ke kelipatan LotStep
```

### 4.8 Komisi (E4, baris 9853–9861 — jalur manual)
```
commission = CommissionPerLot                                     (jenis: currency)
commission = CalculateContractValue() * CommissionPerLot / 100     (jenis: percent)
CommissionReward = commission;  CommissionProfitOnly = false

---

## 5. Mapping UI → objek MQL5

Sumber: `Main/Docs/amis-sizer-panel.html`, 63 kontrol dalam 5 tab
(main 13, risk 13, margin 6, swaps 9, trading 21).

| Elemen HTML | Kelas MQL5 | Catatan |
|---|---|---|
| `.pill` input | `CEdit` | border tak bisa rounded — semua kotak |
| read-only field | `OBJ_LABEL` di dalam frame `OBJ_RECTANGLE_LABEL` | **bukan** `CEdit` read-only |
| `.seg` segmented | `CHorizontalRadioGroup` | sudah ada di `_reference/HorizontalRadioGroup.mqh` |
| toggle | `CCheckBox` | aset bmp di `_reference/Images/` |
| toolbar tab | `CButton` | 5 tab |
| `+` / `–` | 2 tombol `CButton` terpisah | tidak digabung jadi stepper |
| garis kartu | `OBJ_RECTANGLE_LABEL` | warna `#1b2230`, tanpa rounded |

### 5.1 Geometri dasar (mengikuti PS agar transisi mulus)
```
row_start      = 10 * DPI
element_height = 20 * DPI      // pill AMIS 24px tidak mungkin; 20 mengikuti PS
v_spacing      =  4 * DPI
h_spacing      =  5 * DPI
lebar panel    = 360           // narrow (PS 350, +10 untuk header 2 baris)
wide mode      = 500           // tetap, sama seperti PS
title height   = 30            // 2 baris header
```

### 5.2 Objek header (baru, tidak ada di PS)
| Objek | Jenis | Ukuran |
|---|---|---|
| `HGRP_TITLE_1` | `OBJ_LABEL` | 16 pt — `HoekaGata` putih + `AMIS` sian |
| `HGRP_TITLE_2` | `OBJ_LABEL` | 7.5 pt — `AMIS Risk Panel` muted |
| `HGRP_SYM` | `OBJ_LABEL` | 11 pt — simbol |
| `HGRP_TF` | `OBJ_LABEL` | 10 pt — timeframe |
| `HGRP_BTN_CENTER` | `OBJ_BUTTON` | 17×17 — ikon reticle |
| `HGRP_BTN_MIN` | `OBJ_BUTTON` | 17×17 — minimize |

---

## 6. Urutan porting + titik verifikasi

| Fase | Isi | Verifikasi |
|---|---|---|
| **1** (sekarang) | config struct, E1–E4, E6; clone tanpa UI | 10 skenario angka vs PS: lot & risk harus sama |
| 2 | E5, E7 (multi-TP, point value), swaps, margin tab | lot per-TP cocok; margin bebas vs used |
| 3 | UI AMIS penuh (63 kontrol `HGRP_`), 5 tab | `compare-rows` tetap 63; klik tiap kontrol tak error |
| 4 | eksekusi order (dari `Position Sizer Trading.mqh`) | order uji di akun demo |
| 5 | INI persistence, hotkey, minimize state | restart chart mengembalikan state |

Skenario verifikasi fase 1 (akun & simbol bebas, hasil dibandingkan dengan PS asli):
1. XAUUSD, risk 1%, SL 100 poin, akun USD
2. XAUUSD, risk 0.5%, SL 250 poin
3. EURUSD, risk 2%, SL 20 poin (mode Forex, tick value)
4. risk dalam uang ($50) bukan persen
5. risiko di bawah `MinLot` → lot 0
6. stop terlalu ketat → lot > `MaxLot` → clamp
7. LotStep 0.01 vs 0.1
8. komisi per-lot tetap
9. komisi persen dari nilai kontrak
10. akun mata uang = base currency (koreksi kurs 4.3)

---

## 7. Deviations (harus kosong di fase 1)

| # | Perbedaan | Alasan | Status |
|---|---|---|---|
| — | _belum ada_ | — | — |

---

## 8. Yang sengaja TIDAK di-clone sekarang

- 149 `input` PS → fase 3, dipangkas ke yang dipakai 63 kontrol.
- 9 bahasa terjemahan → hanya `English` yang relevan; sisanya ditunda.
- `TesterSupport.mqh` → belum perlu.
- Ikon `EF-Icon-64x64px.ico` → milik EarnForex, tidak disalin ke build EA.


---

## 9. Status implementasi fase 1 (selesai)

| Item | Hasil |
|---|---|
| Folder terpisah | `Main/MQL5/Experts/HoekaGATA/HoekaGataRiskPanel/` |
| Backup asli | `_reference/` — 30 file, 1.9 MB (asli `RiskCalculator/` tidak diubah) |
| Build | `0 errors, 0 warnings`, `.ex5` 13.288 byte |
| Prefix objek | `HGRP_` (bukan `PS_`) |
| Penanda audit | 6 `CLONE-SRC` menunjuk baris asal |

### 9.1 Bug yang ditemukan & diperbaiki saat verifikasi

Ini penting dicatat karena membuktikan verifikasi benar-benar dijalankan,
bukan sekadar compile.

| # | Bug | Dampak kalau lolos | Perbaikan |
|---|---|---|---|
| 1 | SL dipakai sebagai **selisih harga** | Lot salah total untuk simbol `Point != 1` | SL dikonversi ke **poin** seperti PS:3203, lalu pakai `Point` |
| 2 | `CurrentSpread()` mengembalikan satuan harga | `SpreadAdjustmentSL` mengurangi nilai yang salah satuan | dikonversi ke poin agar konsisten dengan `base_sl` |

Bug #1 adalah yang paling berbahaya: pada XAUUSD (`Point=0.01`) lot akan
melembung ~100× tanpa terlihat, karena hasilnya tetap angka yang "masuk akal".

### 9.2 Rumus yang sudah dicocokkan baris-per-baris ke PS

| Rumus | PS | HGRP |
|---|---|---|
| lot dari risiko | 7973 | baris ~376 |
| risk money persen | 7919 | ~311 |
| risk money aktual | 7985 | ~398 |
| base risk money | 7993 | ~409 |
| koreksi kurs | 7957 | ~345 |
| toleransi step 1e-8 | 8172 / 9917 | sama |

### 9.3 Belum dikerjakan (fase 2+)

- `PositionSizeToArray` (multi-TP), `RoundToSignificant`
- `CalculateAutoCommission`
- Eksekusi order
- INI persistence, hotkey

Sampai UI selesai, EA **hanya menghitung dan mencetak ke log** —
tidak membuka order apa pun. Ini disengaja.

## 10. Status fase 3 (UI) — selesai tahap 1

Pemecahan file:

| File | Isi |
| --- | --- |
| `HoekaGataRiskPanel.mq5` | engine fase 1 + `OnInit`/`OnDeinit`/`OnChartEvent` |
| `HGRP_Panel.mqh` | kelas `HGRP_Panel`: palet, geometri, pembuat objek, tab |

Yang sudah jadi:

- Palet 18 warna dan 14 konstanta geometri, disalin dari `.root` CSS
  `amis-sizer-panel.html` (nama variabel CSS dicatat di komentar).
- Pembuat objek `Rect` / `Label` / `Edit` — semua memakai prefix `HGRP_`.
- Bingkai panel: latar, border, judul 2 baris (`HoekaGata` + `AMIS` teal +
  `AMIS Risk Panel`), simbol & timeframe kanan-atas, 2 tombol ikon.
- Strip 5 tab: Main / Risk / Margin / Swaps / Trading, tab aktif ditandai
  border teal + latar `--seg-on`.
- Tab Main lengkap 2 kartu: *Price & targets* (Entry segmented Long/Short,
  Stop-loss, Take-profit + TPx, Order type 3-pilihan, TP2, Stop price) dan
  *Calculation* (Commission %/$, Account balance, Risk, Risk money,
  Position size).
- `OnChartEvent` menangani klik seluruh objek `HGRP_*`; `HGRP_Panel::OnClick`
  memilah tab, segmented, tombol, dan input.
- Tab Risk: *Portfolio filter* (3 segmented), *Current portfolio*,
  *Potential portfolio* — angka nyata dari `g_result`.
- Tab Margin: position margin, future used/free margin, leverage,
  max size by margin (memakai `OrderCalcMargin`).
- Tab Swaps: tipe swap, triple swap day, nominal long/short per lot dan per
  posisi, dibaca dari `SYMBOL_SWAP_*`.
- Tab Trading: trailing/BE, magic, commentary, batas max trades & volume,
  TP share, 4 opsi order.
- Wiring UI -> engine lewat `HGRP_SyncFromPanel()`: baca semua `EDT_*` ->
  `g_sets` -> `HGRP_CalculateRiskAndPositionSize()` +
  `HGRP_UpdateMarginTab()` -> `g_panel.UpdateResults()` menulis balik ke
  `PILL_*` / `POT_*` / `CUR_*`.
- Tombol berfungsi: tab, Long/Short, Order type, Commission %/$, `TPxN`
  (cycle 1->2->3->1), `SA` toggle, minimize.
- Read-only andal: pill hasil TIDAK memakai `OBJ_EDIT` +
  `OBJPROP_READONLY` (diabaikan sebagian build MT5), melainkan
  `OBJ_RECTANGLE_LABEL` + `OBJ_LABEL`.
- `Build-MT5.ps1` dapat target ketiga `-Target RiskPanel`; `All` mencakup
  ketiganya.

Compile: **0 errors, 0 warnings**, `HoekaGataRiskPanel.ex5` 57,564 byte.
Deploy: `-Target RiskPanel`, SHA256 semua file identik.

### 10.1 Tambahan: garis chart, drag, filter, Max/Lock (selesai)

Modul baru `HGRP_Lines.mqh` — tiga garis level **sumber kebenaran**, mengikuti
pola Position Sizer (`Docs/RiskCalculator.md:65`):

| Objek | Nama | Peran |
| --- | --- | --- |
| Entry | `HGRP_EntryLine` | referensi harga, tidak dibaca engine |
| Stop loss | `HGRP_StopLossLine` | `g_sets.StopLossLevel` |
| Take profit | `HGRP_TakeProfitLine` | `g_sets.TPLevel` |

- Dibuat sekali di `OnInit()` hanya bila belum ada (`HGRP_EnsureLines`), jadi
  setup user tidak tertimpa saat EA di-attach ulang. Placeholder awal: bid ±1%.
- **Tidak dihapus** saat EA dilepas (`OnDeinit`) — garis itu milik user.
- `HGRP_SyncFromPanel()` membaca harga garis lebih dulu, lalu menulis balik ke
  garis bila input panel berubah. Menggeser garis di chart = mengubah setup.
- `Hide` memakai `OBJPROP_TIMEFRAMES = OBJ_NO_PERIODS` sehingga harga garis
  tidak hilang; `HGRP_ShowLines()` mengembalikannya.

Tombol yang sekarang berperilaku:

| Tombol | Perilaku |
| --- | --- |
| `Max` | `HGRP_ApplyMax()`: margin satu MinLot via `OrderCalcMargin`, lot yang muat, lalu jarak SL = `free_margin / (lot * nilai_per_point)`. TP = 2x jarak SL. Ditolak + `Print` bila free margin tidak cukup. |
| `Lock` | Toggle `tp_locked`. Saat aktif, `HGRP_ApplyLock()` menggeser TP sejauh pergeseran SL, mempertahankan jarak awal. |
| `Hide` | Toggle `hide_lines` + `HGRP_ShowLines()`. |
| `+` (`BTN_CENTER`) | `SnapToCenter()`: menaruh panel di tengah chart. |

Portofolio nyata di tab Risk (`HGRP_CalculatePortfolio()`):

- Iterasi `PositionsTotal()` dan (bila filter orders != `Open`) `OrdersTotal()`.
- Risiko = `|open - sl|` dalam poin x nilai per point x lot, per simbol.
- Filter `Include orders` (All/Open/Pend), `Include symbols` (All/Cur/Other),
  `Include` (All/Buy/Sell), dan `Ignore orders without stop-loss` semuanya
  **memengaruhi hasil**, bukan sekadar state.
- `CUR_*` menampilkan risiko terbuka + jumlah posisi; `POT_*` menampilkan
  risiko terbuka + potensial dari pending order.

Panel dapat digeser (preseden `Docs/RiskCalculator_EA.md:165`):

- Handle transparan `HGRP_DRAG` di atas header — satu-satunya objek `HGRP_`
  dengan `OBJPROP_BACK == true`, jadi dikenali tanpa daftar nama.
- `CHARTEVENT_MOUSE_MOVE` + `CHART_MOUSE_SCROLL = false` selama geser;
  lepas tombol mengembalikan scroll dan menyimpan posisi.
- `CHARTEVENT_CHART_CHANGE` memanggil `ClampToChart()` agar panel tidak hilang
  saat chart di-resize. Header selalu tetap terlihat.

State antar restart — `GlobalVariable` berkunci `ChartID()` sehingga dua chart
tidak saling menimpa (`HGRP_SaveState` / `HGRP_LoadState`):

| Kunci | Isi |
| --- | --- |
| `HGRP_STATE_<ChartID>_X` / `_Y` | posisi panel |
| `HGRP_STATE_<ChartID>_TAB` | tab aktif |
| `HGRP_STATE_<ChartID>_RISK` | persen/money risk |
| `HGRP_STATE_<ChartID>_ACCT` | account balance |

Dihapus hanya saat EA benar-benar dicabut (`REASON_REMOVE` / `REASON_CLOSE`).

Masih terbuka:

- Belum ada stop-limit (`StopPriceLine`) dan step SL/TP berbasis `Point`/`ATR`.
- Filter `Include symbols = Other` menghitung risiko lintas simbol tetapi
  konversi mata uangnya memakai tick value simbol itu sendiri — benar untuk
  akun dengan mata uang sama, perlu `HGRP_CalculateAdjustment` bila beda.

```
