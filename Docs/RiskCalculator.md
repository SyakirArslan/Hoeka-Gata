# RiskCalculator — analisa logic dan algoritma (Position Sizer)

`Main/MQL5/RiskCalculator/` berisi **Position Sizer** buatan EarnForex, versi `3.16d`
(`Position Sizer.mq5:9`), copyright 2026. Ini **bukan** bagian dari signal engine HoekaGATA:
tidak ada `.mq5`/`.mqh` indikator maupun EA yang meng-include atau memanggil folder ini;
penyebutan di luar folder hanya di `README.md` (tabel komponen, tree folder, catatan singkat,
dan daftar Dokumentasi).
Fungsinya utilitas manual: menghitung lot dari risiko, lalu (opsional) mengeksekusi order sendiri.

- **File utama:** `Main/MQL5/RiskCalculator/Position Sizer.mq5`
- **Library:** `Position Sizer.mqh` (panel + seluruh matematika), `Position Sizer Trading.mqh`
  (eksekusi, trailing, break-even), `Defines.mqh` (enum, struct, resource, list)
- **Prefix objek chart:** input `ObjectPrefix` (default `PS_`)
- **Settings tersimpan:** `MQL5/Files/PS_Settings/<Symbol><ChartID>.txt`
  (`UpdateFileName`, `Position Sizer.mqh:361`; titik pada nama simbol diganti `_dot_`),
  ditulis dengan `FILE_CSV`
- **Magic default:** `2022052714`
- **Build:** **tidak** ikut `Main/Tools/Build-MT5.ps1` (script itu hanya meng-compile
  `Indicators\HokaGATA` dan `Experts\HokaGATA`); `Position Sizer.ex5` di-commit apa adanya

> Ringkasnya: alat ini harus di-compile/attach manual di terminal MT5. Jangan berharap
> `Build-MT5.ps1` mengurusnya.

Isi dokumen:

- [Inventaris file](#inventaris-file) · [Arsitektur](#arsitektur) · [Lifecycle](#lifecycle)
- [Alur algoritma](#alur-algoritma) · [Matematika inti](#matematika-inti)
- [Contoh numerik](#contoh-numerik) · [Validasi dan warning](#validasi-dan-warning)
- [Portfolio risk](#portfolio-risk) · [Margin](#margin) · [Eksekusi order](#eksekusi-order)
- [Fuse dan batas risiko](#fuse-dan-batas-risiko) · [Trailing stop dan break-even](#trailing-stop-dan-break-even)
- [Komisi otomatis](#komisi-otomatis) · [Spread adjustment](#spread-adjustment)
- [Temuan dan gotcha](#temuan-dan-gotcha) · [Bandingkan dengan EA HoekaGATA](#bandingkan-dengan-sizing-ea-hoekagata)
- [Opsi integrasi](#opsi-integrasi) · [Peta fungsi](#peta-fungsi-referensi-cepat)

## Inventaris file

| File | Baris | Isi |
| --- | --- | --- |
| `Position Sizer.mq5` | 1 135 | Input (149 baris input/group), state global, `OnInit` / `OnDeinit` / `OnTick` / `OnTimer` / `OnTrade` / `OnChartEvent`, deteksi dark mode |
| `Position Sizer.mqh` | 9 944 | Class `CPositionSizeCalculator : CAppDialog` (deklarasi `:9`–`:330`, definisi `:333`–`:7049`), lalu **seluruh matematika sebagai free function** `:7149`–`:9950` |
| `Position Sizer Trading.mqh` | 1 361 | `DoTrade`, `ApplySLTPToOrder`, trailing stop, break-even, volume existing, fuse, konversi instant → pending |
| `Defines.mqh` | 304 | Enum (`ENTRY_TYPE`, `ACCOUNT_BUTTON`, `TABS`, `COMMISSION_TYPE`, `MARGIN_UTILIZATION_BASE`, …), `struct Settings`, `CPanelList`, hotkey |
| `TesterSupport.mqh` | 294 | Menyintesis event panel di Strategy Tester visual + tombol Close di luar panel |
| `errordescription.mqh` | 235 | Terjemahan kode error trade |
| `HorizontalRadioGroup.mqh` | 218 | Radio group horizontal, turunan `CWndClient` |
| `Translations/*.mqh` | 9 bahasa | **Hanya `English.mqh`** (534 baris) yang di-include; 8 lainnya dikomentari di `.mq5:13-20` |
| `Images/*.bmp`, `EF-Icon-64x64px.ico` | — | Resource checkbox/radio + ikon EA |

Pembagian yang penting untuk dibaca: **baris 7149–9950 di `Position Sizer.mqh` adalah
kumpulan fungsi bebas** (bukan method class), saling berbagi variabel global. Itu bagian yang
layak di-port/diadaptasi kalau hanya matematikanya yang dibutuhkan.

> **Visual panel:** mockup HTML 1:1 (5 tab, geometri narrow 350 / wide 500 × 570 px, tema
> light/dark, tabel baris ↔ baris kode) ada di
> [`../Main/Docs/position-sizer-panel.html`](../Main/Docs/position-sizer-panel.html).
> Dokumen ini menjelaskan *isi* panel; mockup itu menjelaskan *tampilannya*.

## Arsitektur

Tiga lapis yang saling bergantung:

1. **Model** — satu variabel global `Settings sets` (`Defines.mqh:284`, struct `:195`–`:283`).
   Semua input panel, level, dan state disimpan di sini; tidak ada class model. Field ditulis
   langsung dari handler kontrol (mis. `OnEndEditEdtMagicNumber` → `sets.MagicNumber`).
2. **Chart objects sebagai sumber kebenaran level** — Entry/SL/TP adalah `OBJ_HLINE`
   bernama `ObjectPrefix + "EntryLine"`, `"StopLossLine"`, `"TakeProfitLine"`,
   `"TakeProfitLineN"`, `"StopPriceLine"`. Perhitungan **membaca harga dari objek**
   (`RecalculatePositionSize`, `:7610`, `:7699`; `:8016`), bukan dari `sets`, sehingga drag
   garis langsung mengubah hasil. `sets.*Level` hanya cache yang di-refresh tiap kalkulasi.
3. **View/Controller** — `CPositionSizeCalculator` (turunan `CAppDialog`) membuat kontrol,
   memetakan event lewat `EVENT_MAP`, dan menampilkan hasil ke `CEdit`/`CLabel`
   (`DisplayValues`, `:1857`).

Hasil kalkulasi dikembalikan lewat **variabel global**, bukan return value:

| Global | Arti |
| --- | --- |
| `AccSize` | basis ukuran akun yang dipakai sizing |
| `StopLoss` | jarak SL (spread-adjusted) dalam satuan harga |
| `RiskMoney`, `OutputRiskMoney`, `BaseRiskMoney` | risiko target, risiko setelah pembulatan lot, risiko dari SL dasar |
| `OutputPositionSize`, `ArrayPositionSize[]` | lot final dan pembagiannya per TP |
| `OutputMaxPositionSize` | lot maksimum menurut free margin |
| `PositionMargin`, `UsedMargin`, `FutureMargin`, `StopOut` | hasil tab Margin |
| `PortfolioLossMoney`, `PortfolioRewardMoney` | hasil tab Risk |

Pola ini yang membuat `.mqh` dan `Trading.mqh` berbagi state tanpa parameter — harus diingat
saat membaca kode: `DoTrade()` membaca `OutputPositionSize` yang dihitung tick terakhir.

## Lifecycle

### OnInit (`Position Sizer.mq5:207`)

1. Tentukan mode warna (dark mode manual atau autodetect) dan override warna kontrol global
   satu per satu.
2. `TickSize = -1` sebagai penanda "data belum siap".
3. Panel (`ExtDialog = new CPositionSizeCalculator`) **tidak** dibuat ulang bila deinit
   disebabkan `REASON_CHARTCHANGE` (`:256`); jumlah TP lama diingat untuk resize panel.
4. `SettingsFile != ""` → pakai file settings kustom di `\Files\PS_Settings\`.
5. Isi `sets` dari input + koreksi konsistensi: `MaxPositionSizeTotal >= PerSymbol`,
   `MaxNumberOfTradesTotal >= PerSymbol`, `MaxRiskTotal >= PerSymbol`,
   `MaxMarginPercTotal >= PerSymbol` (hanya bila nilai total ≠ 0); `ExpiryMinutes` < 2 → 0
   karena MT5 menolak expiry di bawah 2 menit.
6. Bila parameter EA berubah (`REASON_PARAMETERS`), nilai panel disimpan di GlobalVariable
   `PS-<ChartID>-Parameters` lalu dibaca ulang supaya `sets` tidak hilang.
7. `ExtDialog.Create(...)` → `Run()` → `IniFileLoad()` (posisi panel) → `Initialization()`.
8. Hotkey di-parse sekali (`SetupHotkey` → `HotkeyDef`), pencocokan tombol di `OnChartEvent`.
9. `SymbolForTrading` = input `TradeSymbol` bila diisi, kalau tidak `_Symbol`.

### OnDeinit (`:624`)

- `REASON_CLOSE / REMOVE / CHARTCLOSE / PROGRAM`: hapus semua objek ber-prefix (kecuali
  `DoNotDeleteLinesLabels`). File settings + `.ini` **hanya** dihapus pada `REASON_REMOVE` /
  `REASON_PROGRAM`, dan settings hanya bila `SettingsFile` kosong.
- `REASON_CHARTCHANGE`: panel tidak dihancurkan, hanya `OldSymbol` disimpan.
- Selain chart change/remove/program: `SaveSettingsOnDisk()` + `IniFileSave()`.

### Handler runtime

| Handler | Isi |
| --- | --- |
| `OnTick` (`:675`) | Strategy Tester visual: `ListenToChartEvents` + `UpdateStrategyTesterTrades`; `ExtDialog.RefreshValues()`; `DoTrailingStop()` bila `TrailingStopPoints > 0` |
| `OnTimer` (`:1110`, 1 detik) | Jeda 50 ms → `CheckAndRestoreLines()`; bila ≥ 1000 ms sejak kalkulasi terakhir → `RefreshValues()` |
| `OnTrade` (`:1101`) | `RefreshValues()` + redraw (tidak ada logika trade sendiri) |
| `OnChartEvent` (`:689`) | Mouse move (deteksi garis sedang di-drag), object click, object drag, chart click, hotkey |

`RefreshValues()` (`Position Sizer.mqh:2446`) adalah pusat alur:

```text
if (sets.StopLossLevel ≈ 0) Initialization()     // 'Waiting for data' di MT5
CalculateSettingsBasedOnLines()                  // :2212  sets ← garis & field
RecalculatePositionSize()                        // :7595  baca garis → warning → sizing → reward/RR
DisplayValues()                                  // :1857  tulis hasil ke field panel
DoBreakEven()                                    // Trading.mqh:948, dievaluasi tiap refresh
LastRecalculationTime = GetTickCount64()
```

`RecalculatePositionSize()` (`:7595`):

```text
GetSymbolAndAccountData()                        // :7823  tick size, min/max/step, calc mode, mata uang
baca EntryLine / StopLossLine / StopPriceLine    // :7610-7618 (gagal baca → return, tunggu restore)
WarningEntry / WarningSL / WarningSP             // :7620-7667 berdasarkan SYMBOL_TRADE_STOPS_LEVEL
StopLoss = RealStopLossDistance(|entry − SL|)    // :7669, +spread bila SA-SL aktif
AccSize  = Balance / Equity / Balance−CPR (+AdditionalFunds)   // :7671-7687
if (StopLoss != 0) CalculateRiskAndPositionSize()              // :7693
baca TP + TP tambahan → warning → label R/R di chart           // :7695-7808
if (StopLoss == 0) return                                      // :7810
CalculateSymbolLeverage() / GetSwapData() sesuai tab aktif      // :7815, :7817
```

## Alur algoritma

Rantai lengkap dari garis di chart sampai angka di panel:

```text
[garis Entry/SL/TP]  ──baca OBJPROP_PRICE──┐
[field panel]        ──handler On*Edit─────┤
                                           ▼
                        CalculateSettingsBasedOnLines()   :2212
                          · ATR → SL/TP bila ShowATROptions
                          · snap semua level ke TickSize
                          · TradeDirection := SL<Entry ? Short : Long   (:2363-2364)
                          · caption panah ▲/▼                            (:2366-2367)
                                           ▼
                        RecalculatePositionSize()          :7595
                                           ▼
                        CalculateRiskAndPositionSize()     :7909
                          1. commission   = CalculateCommission()          :9839
                          2. RiskMoney    = AccSize × Risk% (floor)       :7917-7928
                          3. UnitCost     = CalculateUnitCost()           :9505
                          4. arah         = f(posisi SL vs Entry)         :7932-7942
                          5. future-rate  = ×(current/future) bila CCY akun = base  :7945
                          6. per_lot_risk = SL×UnitCost/TickSize + 2×comm :7960-7976
                          7. PositionSize = floor(RiskMoney / per_lot_risk)
                          8. clamp broker / margin                        :7978-7982
                          9. OutputRiskMoney, BaseRiskMoney               :7985-7993
                         10. reward & R/R per TP                          :8026-8124
                         11. split multi-TP  = PositionSizeToArray()      :8006
                         12. portfolio risk  = CalculatePortfolioRisk()   :8126
                         13. margin          = CalculateMargin()          :8130
                                           ▼
                        DisplayValues()  → field panel + label chart
```

Kunci desain yang perlu dipegang:

- **Level bukan parameter, tapi state chart.** Semua masukan harga dibaca dari objek. Kalau
  objek garis dihapus, `RecalculatePositionSize()` langsung `return` dan panel menampilkan
  nilai lama sampai `CheckAndRestoreLines()` membuat ulang garis.
- **Arah trade diturunkan dari urutan harga**, bukan dari tombol Long/Short
  (`:2363-2364`, lalu `:7932-7942`). Tombol arah pada praktiknya memindahkan garis SL/Entry
  ke sisi lain, bukan menyimpan flag arah.
- **Urutan pemanggilan penting** karena semua fungsi berbagi variabel global:
  `GetSymbolAndAccountData()` → `CalculateCommission()` → `CalculateUnitCost()` → sizing.
- **Valuasi reward memakai nilai "real" (spread-adjusted) sedangkan panel menampilkan nilai
  "base"** (`:338-349`), sehingga angka di garis dan angka R/R bisa berbeda tipis.

## Matematika inti

### 1. Arah posisi ditentukan oleh posisi SL

`CalculateSettingsBasedOnLines()` (`:2363-2364`) menulis `sets.TradeDirection` dari urutan
Entry vs SL, lalu `CalculateRiskAndPositionSize()` (`:7932-7942`) memetakan:

```text
SL < Entry  → BUY   (POSITION_TYPE_BUY / ORDER_TYPE_BUY)
SL > Entry  → SELL
SL == Entry → return (tidak ada kalkulasi)
```

Menggeser garis SL ke sisi lain entry otomatis membalik arah trade.

### 2. Account size (`AccSize`)

`RecalculatePositionSize()` (`:7671-7687`):

| `AccountButton` | Nilai |
| --- | --- |
| `Balance` (default) | `CustomBalance` bila > 0, jika tidak `ACCOUNT_BALANCE` |
| `Equity` | `ACCOUNT_EQUITY` |
| `Balance_minus_Risk` | Balance/CustomBalance − `PortfolioLossMoney` (bila ≠ `DBL_MAX`) |

Lalu `if (CustomBalance <= 0) AccSize += AdditionalFunds;` — `AdditionalFunds` ikut
ditambahkan juga pada mode Equity.

### 3. Risk money

```text
mode persen : RiskMoney = Round(AccSize × Risk / 100, AccountCurrencyDigits, RoundDown)
              sets.MoneyRisk = RiskMoney

mode uang   : RiskMoney = sets.MoneyRisk
              DisplayRisk = RiskMoney / AccSize × 100      (AccSize = 0 → 0)
              sets.Risk  = DisplayRisk                     (persen ditulis balik)

mode lot    : (RiskFromPositionSize = true, di dalam blok sizing)
              RiskMoney = Round(PositionSize × per_lot_risk, AccountCurrencyDigits)
              sets.Risk = RiskMoney / AccSize × 100
```

Pembulatan risiko selalu **ke bawah** supaya target tidak terlampaui.

### 4. Unit cost per tick

`CalculateUnitCost()` (`:9505`):

- **Forex / Futures** (`SYMBOL_CALC_MODE_FOREX`, `_FOREX_NO_LEVERAGE`, `_FUTURES`,
  `_EXCH_FUTURES`, `_EXCH_FUTURES_FORTS`) → langsung `SYMBOL_TRADE_TICK_VALUE_LOSS` dan
  `SYMBOL_TRADE_TICK_VALUE_PROFIT` (nilai 0 memicu `WarnAboutZeroUnitCost()`, `:9637`).
- **Non-Forex** → `TickSize × ContractSize`, lalu dikali `CalculateAdjustment()` bila mata
  uang profit ≠ mata uang akun.

`CalculateAdjustment()` (`:9067`) mencari pasangan konversi: direct quote → `Bid`/`Ask`,
reverse quote → `1/Ask` atau `1/Bid`, kalau tidak ada lewat USD (cross,
`GetSymbolByCurrencies`, `:9137`); gagal total → return `1` + peringatan sekali.

Khusus Forex dengan **mata uang akun = base currency** (mis. akun USD trading USD/CAD),
unit cost disesuaikan ke kurs SL/TP, bukan kurs sekarang:

```text
UnitCost *= current_rate / future_rate        // :7945-7958 dan FutureRateAdjustment (:8136)
```

### 5. Position size

`CalculateRiskAndPositionSize()` (`:7960-7976`):

```text
per_lot_risk = StopLoss × UnitCost / TickSize + 2 × commission
PositionSize = Round(RiskMoney / per_lot_risk, LotStep_digits, RoundDown)
```

- `StopLoss` dalam satuan harga; dibagi `TickSize` menjadi jumlah tick.
- Komisi dihitung **dua kali** (masuk + keluar) — asumsi round-turn retail.
- Hasil disimpan ke `OutputPositionSize`.
- Blok dilewati (lot tetap 0) bila `StopLoss == 0`, `UnitCost == 0`, atau `TickSize == 0`.

### 6. Batas broker — dua fungsi, perilaku berbeda

| Fungsi | Dipakai | `< MinLot` | `> MaxLot` |
| --- | --- | --- | --- |
| `AdjustPositionSizeByMinMaxStep()` (`:9911`) | sizing panel | **dinaikkan** ke `MinLot` | dipotong `MaxLot` (kecuali `SurpassBrokerMaxPositionSize`) |
| `BrokerizePositionSize()` (`:8158`) | pembagian volume per TP | **0** (trade dilewati) | dipotong `MaxLot` |

Keduanya `floor` ke kelipatan `LotStep`. `MinLot`/`MaxLot`/`LotStep` dibaca tiap tick di
`GetSymbolAndAccountData()` (`:7823`); bila `CalculateUnadjustedPositionSize = true`, digit lot
dipaksa 8 dan penyesuaian broker dilewati.

`CapMaxPositionSizeBasedOnMargin` diterapkan **setelah** penyesuaian broker (`:7982`), jadi
lot final = `min(lot sizing, OutputMaxPositionSize)`.

### 7. Risiko uang sebenarnya, base risk, reward, R/R

```text
OutputRiskMoney = Round(per_lot_risk × OutputPositionSize, AccountCurrencyDigits)      :7985
BaseRiskMoney   = Round((SL_dasar × UnitCost / TickSize + 2 × comm) × PS, digits)      :7993
                  SL_dasar = StopLoss − spread bila SA-SL aktif (min 0)
```

- `OutputRiskMoney` = risiko uang setelah lot dibulatkan → angka ini yang jujur ditampilkan.
- `BaseRiskMoney` dipakai menurunkan TP dari multiplier, supaya TP tidak bergeser saat spread
  berubah.
- TP utama **dibaca dari objek** `TakeProfitLine` (`:8016`), bukan dari `sets.TakeProfitLevel`.
- Reward memakai TP yang sudah spread-adjusted (`rTakeProfitLevel`, `:8028`) dan unit cost
  yang disesuaikan kurs masa depan (`:8029`):

```text
MainOutputReward = Round((|rTP − entry| × UnitCost_reward / TickSize − 2 × CommissionReward)
                         × ArrayPositionSize[0], digits, RoundDown)                  :8034
```

- Perhatikan: sisi risiko **menambah** komisi, sisi reward **mengurangi** komisi —
  konsisten (komisi selalu mengurangi hasil akhir).
- R/R input vs output (`:8048-8057`):

```text
InputRR       = Round(|TP_mentah − entry| / StopLoss, 2, RoundDown)     // StopLoss sudah +spread
MainOutputRR  = Round(MainOutputReward / (OutputRiskMoney / PS × ArrayPositionSize[0]), 2, RoundDown)
if (MainOutputRR == InputRR) InputRR = ""     // panel tidak menampilkan dua angka identik
```

- `WarningTP != ""` → keduanya `Too close`; sisi TP salah → `Invalid TP`;
  `PS_Multiplier == 0` atau `ArrayPositionSize[0] == 0` → keduanya kosong.
- `InputReward = Round(RiskMoney × share% × |rTP − entry| / StopLoss, digits, RoundDown)`
  (`:8094`) — estimasi reward dari risiko input, bukan dari lot.

### 8. Multiple take-profit

`sets.TakeProfitsNumber` + `sets.TPShare[i]` (persentase volume). Total share divalidasi
**99–100%** saat eksekusi (`Trading.mqh:52`).

`PositionSizeToArray(ps)` (`:9880`):

```text
untuk tiap TP: size[i] = BrokerizePositionSize(ps × share[i] / 100)    // floor + skip bila < MinLot
selisih = ps − Σ size[i]
selama selisih > 0: tambah LotStep bergiliran ke size[0..n−1] sampai total ≥ ps
```

R/R gabungan (`:8100-8124`): `OutputReward` dijumlahkan, `TotalOutputRisk` dijumlahkan per
share, `OutputRR = Σreward / Σrisk`; `TotalInputRisk = RiskMoney × Σshare`.

- **Netting**: `DoTrade()` menimpa semua TP menjadi satu TP 100% (`TP[0] =
  TakeProfitLevel`, `TPShare[0] = 100`, `Trading.mqh:74-83`) karena netting tidak bisa punya
  beberapa posisi searah per simbol.
- `TPLockedOnSL` memaksa TP dihitung ulang dari SL setiap SL bergerak (`:8008-8014`).
- `TPMultiplier` dipakai tombol **Take Profit** (`ProcessTPChange`): jarak TP =
  `|entry − SL| × TPMultiplier`; bila `UseCommissionToSetTPDistance` dan komisi ≠ 0, jarak
  ditambah `2 × komisi` supaya R/R bersih.
- `PrefillAdditionalTPsBasedOnMain` hanya mengisi TP tambahan yang masih 0, dengan skema
  `INWARD` (`TP[i] = entry + (TP_main − entry) × (N − i) / N`) atau `OUTWARD`
  (`TP[i] = entry + (TP_main − entry) × (i + 1)`).

### 9. Komisi

`CalculateCommission()` (`:9839`):

1. `AutoCommission = true` (default) → `SymbolInfoCommissions()` mengambil aturan broker
   (detail di [Komisi otomatis](#komisi-otomatis)). Nilai negatif = gagal ambil → fallback
   ke field manual. Komisi sub-cent dinaikkan ke `MathPow(0.1, AccountCurrencyDigits)`.
2. Manual `COMMISSION_CURRENCY` → nilai per lot apa adanya.
3. Manual `COMMISSION_PERCENT` → `CalculateContractValue() × CommissionPerLot / 100`
   (`CalculateContractValue`, `:9649`).
4. `CommissionReward` menyimpan komisi sisi profit (termasuk komponen *profit-only*);
   `CommissionProfitOnly` menandai komponen yang hanya dibebankan saat profit — komponen itu
   **tidak** masuk risiko, tetapi masuk reward.

### 10. Spread adjustment (SA-SL / SA-TP)

Panel & garis menampilkan nilai **base**; kalkulasi dan eksekusi memakai nilai **real**
(`:7867-7907`):

| Helper | Efek |
| --- | --- |
| `RealStopLossDistance()` | `base + spread` (SL menjauh) |
| `RealStopLossLevelFromBase()` | level SL digeser menjauh dari entry sebesar spread |
| `RealTakeProfitDistance()` | `base − spread`, fallback ke base bila ≤ 0 (TP mendekat) |
| `RealTakeProfitLevelFromBase()` | level TP digeser mendekati entry, fallback bila ≤ 0 |

`CurrentSpread() = max(Ask − Bid, 0)`. Tujuannya: risiko uang dan R/R dihitung dengan biaya
spread nyata. `DoTrade()` juga menggeser TP ke nilai real sebelum order dikirim
(`Trading.mqh:85-90`).

### 11. Margin sebagai gerbang terakhir

`CalculateMargin()` (`:8603`) menghitung `PositionMargin`, `OutputMaxPositionSize`,
`UsedMargin`, `FutureMargin`, `StopOut` — ringkasannya di [Margin](#margin).

## Contoh numerik

### A. EURUSD, akun USD, komisi 7/lot

```text
Balance 10 000 · Risk 1%          → RiskMoney = 100.00
Entry 1.10000 · SL 1.09500        → jarak 0.00500
TickSize 0.00001 · UnitCost 1.00  → 500 tick × 1.00 = 500.00 per lot
per_lot_risk = 500.00 + 2 × 7.00  = 514.00 per lot
PositionSize = floor(100 / 514)   = 0.1945… → 0.19 lot (LotStep 0.01)
OutputRiskMoney = 514 × 0.19      = 97.66 USD      ← 0.98% balance, bukan 1%
TP 1.11000 (0.01000)              → reward = (1000 − 14) × 0.19 = 187.34 USD
MainOutputRR = 187.34 / 97.66     = 1.91           (InputRR = 0.010/0.005 = 2.00)
```

`InputRR` (2.00) > `MainOutputRR` (1.91) karena RR output sudah dikurangi komisi dan
dibulatkan ke bawah; inilah sebabnya panel menampilkan dua angka R/R.

### B. XAUUSD, akun USD, kontrak 100 oz, komisi 7/lot

```text
Entry 2 341.55 · SL 2 336.55      → jarak 5.00 = 500 point
TickSize 0.01 · tick value 1.00   → 500 tick × 1.00 = 500.00 per lot
per_lot_risk = 500 + 14           = 514.00 per lot
Risk 1% dari 10 000               → PS = floor(100/514)   = 0.19 lot · risiko 97.66
Risk 5% (= default EA HoekaGATA)  → PS = floor(500/514)   = 0.97 lot · risiko 498.58
```

### C. Efek `MinLot` (risiko melampaui target)

```text
Balance 100 · Risk 1%             → RiskMoney = 1.00
SL 5.00 gold                      → raw PS = 1.00 / 514 = 0.0019 lot
floor ke LotStep 0.01             = 0.00  → AdjustPositionSizeByMinMaxStep menaikkan ke MinLot
PS final = 0.01 lot               → OutputRiskMoney = 5.14 USD = 5.14% balance
```

Panel **tidak** menolak; ia menampilkan risiko aktual 5.14%. Yang menahan adalah fuse
`MaxRiskPercentage` / `MaxRiskTotal` (bila diisi) atau lot dikurangi oleh
`LessRestrictiveMaxLimits`. Ini penyebab paling umum "kok risiko saya jauh lebih besar dari
yang saya setting" pada akun kecil.

## Validasi dan warning

| Warning | Kondisi (`:7620-7667`, `:8018-8023`) |
| --- | --- |
| `WarningSL` | SL berada di antara Bid dan Ask (instant), atau sisi SL salah untuk pending/stop-limit, atau jarak SL < `SYMBOL_TRADE_STOPS_LEVEL` |
| `WarningEntry` | jarak entry ke harga pasar < stop level; untuk stop-limit juga jarak entry ke stop price < stop level |
| `WarningSP` | stop price di sisi salah atau terlalu dekat dengan harga pasar / dengan limit price |
| `WarningTP` | TP terlalu dekat dengan entry (< stop level) |
| `AdditionalWarningTP[]` | hal sama untuk TP tambahan |
| `Invalid TP` | sisi TP salah relatif terhadap entry & SL — bukan warning, hanya R/R yang ditandai |

`DoTrade()` menolak eksekusi bila `WarningSL != ""` (kecuali `DoNotApplyStopLoss`,
`Trading.mqh:32-36`). Warning lain hanya tampil di panel/label, tidak memblokir.

## Portfolio risk

`CalculatePortfolioRisk()` (`:8180`) menjumlahkan risiko & reward dari **pending order dan
posisi terbuka**, dipakai tab Risk dan fuse `MaxRiskTotal` / `MaxRiskPerSymbol`.

1. Filter per item: `IncludeOrders` (all/open/pending), `IncludeSymbols`
   (all/current/other), `IncludeDirections` (all/buy/sell), `IgnoreOrdersWithoutSL/TP`
   (`:8196-8207`). Saat dipanggil untuk Trading tab, filter simbol/direksi dilewati.
2. Per item dihitung `PointsLoss` dan `PointsReward` dalam satuan harga (`:8210-8446`):

   | Situasi | Nilai |
   | --- | --- |
   | BUY dengan SL | `open − SL` |
   | BUY tanpa SL | `open` (asumsi harga bisa turun sampai 0) |
   | SELL dengan SL | `SL − open` |
   | SELL tanpa SL | `DBL_MAX` (tak terbatas) |
   | BUY tanpa TP | `DBL_MAX` (reward tak terbatas) |
   | SELL tanpa TP | `open` |
   | `\|open − loss\| < ½ point` (Forex) | `DBL_MAX` — proteksi bagi nol |

3. Unit cost per simbol (CFD: `TickSize × ContractSize` + konversi mata uang; instrumen lain:
   `TICK_VALUE_LOSS/PROFIT`), termasuk penyesuaian future-rate Forex bila mata uang akun =
   base currency (`:8270-8307`, `:8450-8486`).
4. Akumulasi: `volume × points × UnitCost / TickSize`; untuk posisi terbuka dikurangi swap
   (`− POSITION_SWAP` di sisi loss, `:8487`; `+ swap` di sisi reward).
5. **Komisi tidak dimasukkan** ke portfolio risk/reward — hanya tick value dan swap.
6. `DBL_MAX` dipropagasikan → panel menampilkan `∞`; `Balance_minus_Risk` mengabaikan
   `PortfolioLossMoney == DBL_MAX` (tidak mengurangi `AccSize`).
7. Ringkasan tab Risk (`:8540-8600`): `PPMR` (portfolio money risk) =
   `PortfolioLossMoney + OutputRiskMoney`; `PPR` = persentase terhadap `AccSize`; `PPRRR` =
   `(PortfolioRewardMoney + OutputReward) / (PortfolioLossMoney + OutputRiskMoney)`.

Catatan: perhitungan memakai tick value **saat ini** (kecuali penyesuaian future-rate Forex),
jadi untuk akun non-USD dengan pair cross angkanya bisa sedikit berbeda dari broker.

## Margin

`CalculateMargin()` (`:8603`). Tujuan: `PositionMargin` (margin posisi baru),
`OutputMaxPositionSize` (lot maksimum menurut free margin), `UsedMargin`, `FutureMargin`,
`StopOut`.

1. `SymbolInfoMarginRate(OrderType)` → `initial_margin_rate`, `maintenance_margin_rate`
   (maintenance 0 → samakan dengan initial).
2. Leverage: `ACCOUNT_LEVERAGE` untuk Forex/CFD-leverage; `TickSize / TickValue` untuk CFD
   index; `CustomLeverage` menimpa dan menyimpan `PreCustomLeverage` (`:8625-8629`).
3. `ContractSize` — ada quirk penting (`:8632`):
   - `SYMBOL_MARGIN_INITIAL > 0` → `ContractSize = MaintenanceMargin`;
   - CFD/CFD-index/saham/CFD-leverage → `PriceCorrectionCoefficient = Ask` (BUY) atau
     `Bid` (SELL).
4. `PositionMargin = PS × ContractSize × PriceCorrectionCoefficient / Leverage ×
   maintenance_margin_rate` (`:8644`), lalu dikonversi ke mata uang akun lewat
   `CalculateAdjustment(Loss, MarginCurrency, AccountCurrency)` (`:8647-8654`). Gagal
   konversi → koefisien 1 + flag `MarginInUnconvertedMarginCurrency`.
5. Batas margin: `MaxPositionMargin` = free margin; mode stop-out persen →
   `100 × Equity / (stopout + 0.01) − Margin`; mode absolut → `stopout + 0.01`; selalu
   dibatasi free margin (`:8656-8674`).
6. **Netting** (`:8680-8741`): hanya bila ada posisi **berlawanan arah** di simbol sama,
   `PositionMargin` bisa **negatif** karena posisi baru menutup sebagian margin lama:
   - `existing_volume >= PS` → margin = `−(PS × ContractSize × existing_open_price ×
     koreksi / Leverage) × maintenance_rate`;
   - sebaliknya → `−ExistingPositionMargin + margin volume sisa`.
   Bila requirement initial > maintenance, versi initial (`_PositionMargin`) dihitung
   terpisah untuk cek free margin.
7. **Hedging** (`:8743-8840`): `HedgedRatio = SYMBOL_MARGIN_HEDGED / ContractSize`; bila
   `< 1`, volume lawan arah dijumlahkan dari seluruh posisi simbol. Hanya volume yang tidak
   ter-hedge yang dimargin:
   `calculated_volume = PS ≤ volume ? PS × (HedgedRatio − 1) : volume × HedgedRatio + PS − 2 × volume`.
   Lot maksimum dihitung dua tahap (iterasi `LotStep` untuk PS ≤ volume lawan, lalu rumus
   `MPS_gv = MaxPositionMargin / (…/Leverage) − volume × (HedgedRatio − 2)`), diambil
   yang terbesar.
8. `MaxPositionSizeByMargin = MaxPositionMargin × Leverage / (ContractSize ×
   PriceCorrectionCoefficient × margin_rate × koreksi)` → `Round(RoundDown)` →
   `AdjustPositionSizeByMinMaxStep()` → `OutputMaxPositionSize` (`:8859-8871`).
9. `UsedMargin = ACCOUNT_MARGIN + _PositionMargin`; `FutureMargin = free − PositionMargin`;
   `StopOut` bila `Equity / UsedMargin × 100 <= stopout` (persen), `_FutureMargin <=
   stopout` (absolut), atau `_FutureMargin < 0` (`:8874-8895`).

### Margin utilization (`ShowAdditionalMarginSettings`)

`CalculateMarginUtilization()` (`:9023`), basis `MarginUtilizationBase`
(balance / starting balance / free margin):

```text
MarginUtilizedCurrent        = ACCOUNT_MARGIN / base × 100
MarginUtilizedPosition       = (Instant) PositionMargin / base × 100 · (pending) 0
MarginUtilizedFuture         = current + position
MarginUtilizedCurrentSymbol  = margin existing per simbol / base × 100     (:8899)
```

`CalculateMarginByVolume()` (`:9001`) dipakai untuk menghitung margin volume existing
(termasuk `HedgedRatio` pada akun hedging, volume-weighted average price).

## Eksekusi order

`DoTrade()` (`Position Sizer Trading.mqh:14`). Semua pemeriksaan terjadi **sebelum** order
dikirim:

| # | Cek | Aksi bila gagal | Baris |
| --- | --- | --- | --- |
| 1 | `TERMINAL_TRADE_ALLOWED`, `MQL_TRADE_ALLOWED` | alert, batal | 20-30 |
| 2 | `WarningSL != ""` (kecuali `DoNotApplyStopLoss`) | alert, batal | 32 |
| 3 | `OutputPositionSize <= 0` | alert, batal | 38 |
| 4 | Total `TPShare` 99–100% (bila TP > 1) | alert, batal | 49-56 |
| 5 | Netting → kolaps ke 1 TP 100% | — | 74-83 |
| 6 | Spread-adjusted TP (`SA-TP`) | — | 85-90 |
| 7 | Fuse per-trade: lines hidden, `MaxSpread`, `MaxEntrySLDistance`, `MinEntrySLDistance`, `MaxRiskPercentage`, `MaxMarginPerc` | batal (atau konversi ke pending bila `ConvertToPendingIfMaxMinEntrySLFails`) | 94-207 |
| 8 | Fuse total & per simbol: `MaxRiskTotal` (208), `MaxRiskPerSymbol` (248), `MaxMarginPercTotal` (290), `MaxMarginPercPerSymbol` (318) | batal, atau perkecil lot bila `LessRestrictiveMaxLimits` | 208-350 |
| 9 | `MaxNumberOfTradesTotal/PerSymbol` (+ rencana order multi-TP) | batal | 351-397 |
| 10 | `MaxVolumeCheck()` (`MaxPositionSizeTotal/PerSymbol`) | `-1` → batal, selain itu lot diperkecil | 475, 583, 1140 |
| 11 | `SubtractPositions` / `SubtractPendingOrders` | kurangi lot dengan volume existing searah; ≤ 0 → batal | — |
| 12 | `AskForConfirmation` → `MessageBox` ringkasan (SL/TP versi real) | batal | 483, 591 |
| 13 | Validasi `ArrayPositionSize[j]` per TP: `< MinLot` → dilewati, `> MaxLot` → `MaxLot` (kecuali `SurpassBrokerMaxPositionSize`) | volume disesuaikan | — |
| 14 | Kirim order per TP; lot > `MaxLot` dipecah `while (position_size > 0)` | lanjut TP lain | 664 |

Semua cek fuse (baris 94-398) berada di dalam `if (ShowFusesOnTrading)`, jadi input itu
**mematikan validasi**, bukan hanya menyembunyikan tampilan.

### Pemetaan tipe order

| Entry type | Kondisi | Order |
| --- | --- | --- |
| Instant | SL > Entry | `ORDER_TYPE_SELL` |
| Instant | selain itu | `ORDER_TYPE_BUY` |
| Pending, Short | `EntryLevel < Bid` | `SELL_STOP` |
| Pending, Short | selain itu | `SELL_LIMIT` |
| Pending, Long | `EntryLevel > Ask` | `BUY_STOP` |
| Pending, Long | selain itu | `BUY_LIMIT` |
| StopLimit | arah mana pun | `*_STOP_LIMIT` dengan `stoplimit = StopPriceLevel` |

Untuk pending, lot dikurangi volume existing **berdasarkan arah order**
(`CalculateOpenVolume`, `:818`), bukan hanya `TradeDirection`.

### Detail eksekusi

- **Market execution** (`IgnoreMarketExecutionMode = true` default): order dibuka tanpa SL/TP,
  lalu `ApplySLTPToOrder()` (`:743`) mencoba `PositionModify` sampai **10×** (`:755`, `:795`);
  bila broker tidak mengembalikan deal, menunggu posisi muncul (`Sleep(1000)`, `:784`).
- **Retcode**: hanya `PLACED`, `DONE`, `DONE_PARTIAL` dianggap sukses.
- **Expiry**: `ORDER_TIME_SPECIFIED` bila `ExpiryMinutes > 0` (pending saja, minimum 2 menit).
- **Commentary**: `CommentBalance` (balance saat itu) + `Commentary` + `CommentAutoSuffix`
  (timestamp lokal).
- **Sound**: `ok.wav` bila ada order sukses tanpa kegagalan, selain itu `timeout.wav`.
- **Magic & slippage**: `Trade.SetDeviationInPoints()` dan `Trade.SetExpertMagicNumber()`
  dipanggil di akhir `Initialization()` (`Position Sizer.mqh:7586-7587`), bukan tiap tick.
- **Instant → pending** (`ConvertToPendingAndTrade`, `:1265`): entry dihitung ulang
  (`new_entry = SL ± distance_points × point`, disnap ke `TickSize`), lalu lot baru
  `per_lot_risk_new = (per_lot_risk_old − 2c) × d_new/d_old + 2c` → `RiskMoney /
  per_lot_risk_new`; lot hasil konversi **tidak** ditulis balik ke panel.

## Fuse dan batas risiko

Dua tingkat: **per simbol** dan **total akun** (total = per simbol + simbol lain).

| Fuse | Field per simbol / total | Efek |
| --- | --- | --- |
| Jumlah order | `MaxNumberOfTradesPerSymbol` / `...Total` | batal (dihitung termasuk order multi-TP yang akan dibuat) |
| Ukuran posisi | `MaxPositionSizePerSymbol` / `...Total` (+ `OutputMaxPositionSize` bila `CapMaxPositionSizeBasedOnMargin`) | lot dipotong ke batas |
| Risiko uang | `MaxRiskPerSymbol` / `MaxRiskTotal` (% dari `AccSize`) | lot dipotong lewat `(batas/100 × AccSize − PortfolioLossMoney) × (PS / OutputRiskMoney)`, atau batal bila ≤ 0 |
| Margin utilization | `MaxMarginPercPerSymbol` / `...Total` | lot dipotong lewat `OutputPositionSize × (batas − utilized current) / utilized position` |

- `LessRestrictiveMaxLimits = true` mengubah fuse **blokir** menjadi **perkecil lot**
  (default `false`).
- `MaxSpread`, `MaxEntrySLDistance`, `MinEntrySLDistance`, `MaxRiskPercentage`,
  `MaxMarginPerc` selalu memblokir (tidak bisa diperkecil lotnya).
- `SurpassBrokerMaxPositionSize = true` membolehkan lot melebihi `SYMBOL_VOLUME_MAX` dengan
  memecah order.
- `DisableTradingWhenLinesAreHidden = true` memblokir eksekusi saat `ShowLines = false`.
- Semua input fuse adalah **input EA**, bukan field `Settings`.

## Trailing stop dan break-even

### Trailing (`DoTrailingStop`, `Trading.mqh:902`)

- Dipanggil dari `OnTick` hanya bila `TrailingStopPoints > 0`.
- Filter: simbol = `SymbolForTrading`, `SYMBOL_TRADE_MODE != DISABLED`, magic =
  `sets.MagicNumber` bila ≠ 0.
- BUY: SL baru = `Bid − points`, hanya bila lebih tinggi dari SL sekarang.
- SELL: SL baru = `Ask + points`, hanya bila lebih rendah atau SL = 0.
- **Tidak** mengecek `SYMBOL_TRADE_STOPS_LEVEL`/freeze level dan tidak retry — broker bisa
  menolak dan hanya di-log.

### Break-even (`DoBreakEven`, `Trading.mqh:948`)

- Dievaluasi setiap `RefreshValues()` (bukan hanya saat tick trade).
- `BE_threshold = open ± BreakEvenPoints × Point`; `BE_price = open ± extra_be_distance`.
- `extra_be_distance` hanya diisi bila `UseCommissionToSetTPDistance` dan komisi ≠ 0 —
  sebesar `CommissionReward` (`:1004-1008`), supaya break-even benar-benar menutup komisi.
- BUY: geser SL hanya bila `Bid >= threshold` **dan** `Bid >= BE_price` **dan**
  `BE_price > SL`; SELL simetris (`:1024`, `:1041`).
- Bila `BE_line_color != clrNONE`, garis BE digambar (`DrawBELine`, `:1102`) dan dihapus saat
  sudah terpicu atau posisi hilang.

## Komisi otomatis

`CalculateAutoCommission()` (`Position Sizer.mqh:9699`) memakai `SymbolInfoCommissions()`:

1. Gagal ambil (`total < 0`) → peringatan **sekali per simbol** → return `-1` → fallback field
   manual. Tidak ada aturan (`total == 0`) → komisi 0.
2. Volume referensi pemilihan tier = `OutputPositionSize` (fallback `MinLot`, lalu 1); harga
   referensi = `sets.EntryLevel` atau `Ask`; `deal_value = volume × ContractSize × price`.
3. Tier dipilih dari `mode_range`: `SYMBOL_COMMISSION_RANGE_VOLUME` → volume referensi,
   `RANGE_VALUE` → `deal_value`. Rentang turnover/profit tidak bisa diketahui di awal → tier
   pertama.
4. Komisi per deal menurut `mode`: money modes (`DEPOSIT`, `SYMBOL_BASE`, `SYMBOL_PROFIT`,
   `SYMBOL_MARGIN`, `SPECIFIED`) × konversi mata uang; `PIPS` (× `UnitCost/TickSize × Point ×
   volume`); `PERCENT` (× nilai kontrak); `PERCENT_PROFIT` (hanya saat profit, memakai jarak TP
   sekarang). Lalu di-clamp `min_value`/`max_value`.
5. `CommissionProfitOnly` menandai komponen profit-only; komponen itu hanya masuk
   `CommissionReward` (sisi reward), tidak masuk risiko.

Konsekuensi: karena volume referensi = `OutputPositionSize` (hasil sizing), ada **loop tidak
langsung** komisi → lot → tier komisi. Praktis stabil, tetapi bisa berosilasi bila lot jatuh
tepat di batas tier volume.

## Spread adjustment

Tiga tingkat pengaruh:

| Tingkat | Efek |
| --- | --- |
| Garis & field panel | tetap nilai **base** (yang dilihat user) |
| `StopLoss` / risk money | `base + spread` bila `SA-SL` → risiko lebih besar |
| TP & reward | `base − spread` bila `SA-TP` → reward lebih kecil |
| Eksekusi | `DoTrade()` mengirim TP versi real (`Trading.mqh:85-90`), SL versi real lewat `RealStopLossLevelFromBase()` |

Tujuannya: panel menghitung apa yang benar-benar diterima di akun, bukan harga mid.

## Temuan dan gotcha

Hal-hal yang paling mudah salah dibaca atau salah dipakai, semuanya terverifikasi di kode:

1. **`ContractSize` ditimpa nilai margin.** `if (InitialMargin > 0) ContractSize =
   MaintenanceMargin;` (`:8632`) — pada simbol dengan `SYMBOL_MARGIN_INITIAL` terisi, variabel
   `ContractSize` global berubah arti menjadi "margin per lot", dan nilai itu dipakai lagi di
   perhitungan hedging (`HedgedRatio`) dan lot maksimum. Jangan port baris ini tanpa memahami
   konsekuensinya.
2. **`MinLot` bisa melampaui risiko target.** `AdjustPositionSizeByMinMaxStep()` (`:9913`)
   menaikkan lot ke `MinLot`; `OutputRiskMoney` lalu dihitung ulang dari lot final. Panel
   menampilkan risiko aktual (jujur), tetapi tidak memblokir. Contoh C di atas: target 1%
   menjadi 5,14%. Yang menahan hanya fuse.
3. **Komisi diasumsikan round-turn (`2 × commission`)** di `:7964`, `:7973`, `:7985`. Broker
   yang membebankan komisi hanya di sisi entry akan dihitung dua kali lebih besar. Sebaliknya,
   simbol swap/komisi nol membuat rumus ini sama dengan tanpa biaya.
4. **R/R output ≠ R/R nominal.** Reward dikurangi `2 × CommissionReward` lalu `RoundDown`
   (`:8034`), sedangkan `InputRR` memakai TP mentah (`:8050`). Karena itu panel menampilkan dua
   angka R/R, dan angka output yang lebih kecil adalah yang realistis.
5. **Netting mematikan multi-TP.** `DoTrade()` menimpa `TP[0]`/`TPShare[0] = 100` pada akun
   netting (`Trading.mqh:74-83`); panel tetap menampilkan pembagian multi-TP yang tidak akan
   dieksekusi.
6. **`ShowFusesOnTrading = false` mematikan validasi**, bukan hanya tampilan: seluruh blok fuse
   (`Trading.mqh:94-400`) dilewati, termasuk `MaxRiskTotal` dan `MaxMarginPercTotal`.
7. **Trailing stop tanpa cek stop level / freeze level dan tanpa debounce**
   (`Trading.mqh:902-945`): setiap tick yang membuat SL lebih baik langsung memanggil
   `PositionModify`; broker yang menolak hanya menghasilkan baris log.
8. **Portfolio risk tidak memasukkan komisi**, dan memakai konvensi harga ekstrem: BUY tanpa SL
   → loss = harga open, SELL tanpa SL → `DBL_MAX` (∞), BUY tanpa TP → reward `DBL_MAX`.
   Untuk CFD/saham, "harga turun ke 0" adalah asumsi yang sangat konservatif.
9. **`Balance_minus_Risk` mengabaikan `DBL_MAX`** (`:7684`): bila portfolio loss tak terhingga,
   `AccSize` tidak dikurangi apa pun — panel tetap menghitung lot, padahal risiko portofolio
   tak terbatas.
10. **Mode uang menulis balik persen.** `sets.Risk = RiskMoney / AccSize × 100` (`:7927`)
    sehingga field `Risk` berubah setiap kalkulasi saat `UseMoneyInsteadOfPercentage = true`.
11. **Risiko % dihitung terhadap `AccSize`**, default `ACCOUNT_BALANCE` — bukan equity. Setelah
    drawdown, risiko % terhadap equity bisa lebih besar dari yang tampak.
12. **`CalculateUnadjustedPositionSize = true` berbahaya untuk eksekusi**: `LotStep_digits`
    dipaksa 8 (`:7829`) dan semua clamp broker dilewati (`:7980`, `:8160`), sehingga lot bisa
    tidak valid untuk `OrderSend`.
13. **Auto-commission memakai `OutputPositionSize` sebagai volume referensi** (`:9719`) →
    loop komisi ↔ lot ↔ tier. Bisa berosilasi tepat di batas tier.
14. **Break-even BUKAN harga open.** `BE_price = open ± extra_be_distance`; dengan
    `UseCommissionToSetTPDistance`, SL digeser melewati open sebesar komisi. Tanpa itu baru
    benar-benar di open.
15. **Recalculate setiap tick** (`OnTick` → `RefreshValues()`), termasuk murah tapi tidak
    gratis: panel 5 tab + `CalculatePortfolioRisk` (iterasi semua order/posisi) berjalan setiap
    tick saat tab Risk aktif.
16. **Settings disimpan per simbol + chart id** (`PS_Settings/<Symbol><ChartID>.txt`) dan
    dihapus saat `REASON_REMOVE`/`REASON_PROGRAM`. Ganti chart id → setting hilang, bukan
    error.
17. **Hanya `English.mqh` yang aktif**; 8 file terjemahan lain ada tetapi dikomentari
    (`Position Sizer.mq5:13-20`). Lokalisasi memerlukan edit `.mq5`.

## Bandingkan dengan sizing EA HoekaGATA

EA memakai rumus sendiri di `Main/MQL5/Experts/HokaGATA_Algo/Includes/HoekaGataAlgo_Trading.mqh:467`
(`CalculateRiskLot`), bukan folder ini:

```text
marketPrice  = CurrentMarketEntryPrice(direction)        // harga pasar, fallback signalEntry
riskMoney    = ACCOUNT_BALANCE × RiskPercentForDirection / 100
slDistance   = |marketPrice − signalSL|
lossPerLot   = slDistance / TickSize × TickValue          // SYMBOL_TRADE_TICK_VALUE (bukan _LOSS)
rawLot       = riskMoney / lossPerLot
lot          = NormalizeVolume(rawLot)                    // clamp min/max + step
```

| Aspek | Position Sizer | EA HoekaGATA |
| --- | --- | --- |
| Basis ukuran akun | Balance / CustomBalance / Equity / Balance−Risk, + `AdditionalFunds` | `ACCOUNT_BALANCE` saja |
| Acuan jarak SL | `entry − SL` dari garis chart (mendukung pending & stop-limit) | harga pasar sekarang (market order) |
| Tick value | `TICK_VALUE_LOSS` / `TICK_VALUE_PROFIT` (Forex/Futures), `TickSize × ContractSize` + konversi (lain) | `SYMBOL_TRADE_TICK_VALUE` |
| Komisi | dihitung (auto dari broker atau manual, round-turn) | **tidak dihitung** |
| Konversi mata uang | `CalculateAdjustment()` + future-rate adjustment | mengandalkan tick value broker |
| Clamp | min/max/step + cap margin + fuse | min/max/step saja |
| Gate risiko | portfolio risk, margin utilization, stop-out, jumlah trade | tidak ada |
| Anti-duplikat | `SubtractPositions` / `SubtractPendingOrders`, magic, max trade | guard sinyal (`HG_SIG_*` heartbeat/shift) |

Dampak angka (XAUUSD, SL 5.00, komisi 7/lot, balance 10 000, risiko 5%):

```text
EA HoekaGATA : lossPerLot 500 → lot 1.00 → loss harga 500 + komisi 14 = 514 (5.14%)
Position Sizer: per_lot_risk 514 → lot 0.97 → risiko terhitung 498.58 (4.99%)
```

Artinya: tanpa komisi, **EA cenderung sedikit melebihi target risiko** (≈2–3% relatif pada
contoh ini, makin besar bila komisi atau spread relatif besar terhadap SL). Untuk sinyal
Engulfing yang SL-nya kadang tipis (mis. 30–60 point XAUUSD), selisihnya bisa lebih besar.

## Opsi integrasi

| Opsi | Cara | Usaha | Risiko |
| --- | --- | --- | --- |
| A. Manual berdampingan | Attach Position Sizer di chart, salin level dari indikator, eksekusi dari panel | nol | dua eksekutor di satu akun: pastikan EA **tidak** juga trading (matikan `Algo Trading` EA atau pisahkan akun), magic berbeda, dan `ObjectPrefix` tidak bertabrakan (`PS_` vs `HoekaGATA_Engulf_`) |
| B. Port rumus ke EA | Tambahkan komisi round-turn + opsi basis equity ke `CalculateRiskLot()` | kecil | harus menambah input baru dan menyesuaikan dokumen `Docs/EA_MT5.md` |
| C. Bridge lewat GlobalVariable | Baca `HG_SIG_<ChartID>_C_E` / `_SL` / `_TP` (kontrak di `AGENTS.md`) lalu isi level Position Sizer | sedang | Position Sizer tidak punya hook input eksternal — perlu menambah pembacaan di `Initialization()`/`OnTick` dan memindahkan objek garis; mudah bentrok dengan drag manual |
| D. Pakai Position Sizer sebagai *checker* | Indikator tetap memberi sinyal, EA tidak trading; lot dihitung manual di panel untuk verifikasi | kecil | disiplin manual |

Rekomendasi praktis: kalau tujuan hanya "lot yang benar untuk sinyal HoekaGATA", **opsi B**
paling murah dan tidak menambah komponen runtime. Kalau tujuannya memakai fuse/margin/trailing
Position Sizer, **opsi A** dengan EA dalam keadaan tidak trading adalah yang paling aman tanpa
mengubah kode pihak ketiga.

## Peta fungsi (referensi cepat)

Semua baris merujuk `Main/MQL5/RiskCalculator/`.

| Fungsi | File:baris | Peran |
| --- | --- | --- |
| `OnInit` / `OnDeinit` / `OnTick` / `OnTimer` / `OnTrade` / `OnChartEvent` | `mq5:207` / `624` / `675` / `1110` / `1101` / `689` | Lifecycle |
| `RefreshValues` | `mqh:2446` | Pusat alur: settings → recalc → display → BE |
| `CalculateSettingsBasedOnLines` | `mqh:2212` | Sinkron `sets` ↔ garis/field, ATR, snap tick, arah |
| `RecalculatePositionSize` | `mqh:7595` | Baca garis, warning, AccSize, panggil kalkulator inti |
| `CalculateRiskAndPositionSize` | `mqh:7909` | **Inti**: risk money → unit cost → lot → risiko/reward/RR |
| `Initialization` | `mqh:7149` | Buat garis/label default, set magic & slippage di akhir (`:7586`) |
| `GetSymbolAndAccountData` | `mqh:7823` | Cache tick size, min/max/step lot, calc mode, mata uang |
| `CalculateUnitCost` | `mqh:9505` | Nilai 1 tick per lot (loss & profit) |
| `FutureRateAdjustment` | `mqh:8136` | Koreksi unit cost ke kurs SL/TP |
| `CalculateCommission` / `CalculateAutoCommission` | `mqh:9839` / `9699` | Komisi manual / dari `SymbolInfoCommissions()` |
| `CalculateContractValue` | `mqh:9649` | Nilai 1 lot dalam mata uang akun |
| `CalculateAdjustment` / `GetSymbolByCurrencies` | `mqh:9067` / `9137` | Konversi mata uang |
| `BrokerizePositionSize` | `mqh:8158` | Clamp per-TP (di bawah MinLot → 0) |
| `AdjustPositionSizeByMinMaxStep` | `mqh:9911` | Clamp sizing panel (di bawah MinLot → MinLot) |
| `PositionSizeToArray` | `mqh:9880` | Bagi lot ke beberapa TP + distribusi sisa |
| `CalculatePortfolioRisk` | `mqh:8180` | Total risiko/reward order + posisi |
| `CalculateMargin` / `CalculateMarginUtilization` | `mqh:8603` / `9023` | Margin posisi baru, lot maks, stop-out |
| `CalculateSymbolLeverage` | `mqh:9485` | Leverage efektif untuk tab Margin |
| `GetSwapData` | `mqh:9198` | Swap per simbol untuk tab Swaps |
| `Round` / `RoundToSignificant` / `FormatDouble` | `mqh:9403` / `9926` / `9413` | Pembulatan & format tampilan |
| `DoTrade` | `Trading.mqh:14` | Seluruh validasi + eksekusi |
| `ApplySLTPToOrder` | `Trading.mqh:743` | Pasang SL/TP setelah market execution (retry 10×) |
| `MaxVolumeCheck` | `Trading.mqh:1140` | Fuse ukuran posisi total / per simbol |
| `DoTrailingStop` / `DoBreakEven` | `Trading.mqh:902` / `948` | Trailing & BE |
| `ConvertToPendingAndTrade` | `Trading.mqh:1265` | Instant → pending saat fuse jarak gagal |

## Catatan versi dan cara verifikasi

- Sumber yang dianalisa: `Position Sizer.mq5` `#define VERSION "3.16d"` (baris 9), file per
  2026-10-23 23:12 (`.mq5`/`.ex5`).
- Seluruh rumus di dokumen ini dibaca langsung dari kode (bukan dari dokumentasi EarnForex);
  nomor baris diverifikasi dengan pencarian simbol pada file yang sama.
- Dokumen ini menggantikan draf `Docs/RiskCalculator.md` sebelumnya yang terpotong di bagian
  break-even (dipulihkan dari stash `f2a18f2`, 581 baris) dan melengkapi bagian yang belum
  ditulis: contoh numerik, temuan, perbandingan dengan EA, opsi integrasi, peta fungsi.
- Acuan terkait: `AGENTS.md` (kontrak indikator ↔ EA), `Docs/EA_MT5.md`, `Docs/Indicator_MT5.md`,
  `Main/Docs/amis-risk-panel.html` (desain panel risiko AMIS, 300 px, `HGRP_`).











