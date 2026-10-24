# Risk Calculator (HoekaGata) — panel risiko berbasis Position Sizer

> **STATUS: DIHAPUS (2026-10-24).** EA ini sudah tidak ada di repo maupun di MT5.
> Folder `Main/MQL5/Experts/HokaGATA RiskCalc/` dihapus dan tidak pernah di-commit,
> jadi **tidak bisa dipulihkan lewat git**. Dokumen ini disimpan sebagai catatan
> arsip: bagaimana EA itu dirancang, bukan cara memakainya.
>
> Sebelum dihapus, EA ini tercatat *abnormal termination* tiga kali pada
> 2026-10-24 (log MT5, XAUUSD H1, 14:21 / 14:45 / 15:48).
>
> Kalau butuh kalkulator risiko, pakai **Position Sizer pihak ketiga** yang masih ada
> di `Main/MQL5/RiskCalculator/` — lihat [`RiskCalculator.md`](RiskCalculator.md).
> Rancangan panelnya masih tersimpan di
> [`mix-risk-panel.html`](../Main/Docs/mix-risk-panel.html).

Berikut isi dokumen arsip. Path yang disebut di bawah sudah **tidak ada**.

`Main/MQL5/Experts/HokaGATA RiskCalc/HoekaGataRiskCalculator.mq5`

**Kulit** dari [`mix-risk-panel.html`](../Main/Docs/mix-risk-panel.html) (350 × 470, grid
`Input | Result`, satu palet gelap). **Otak** — matematika sizing — di-port 1:1 dari
Position Sizer 3.16d di `Main/MQL5/RiskCalculator/`. **Level** dibaca dari **garis chart**
(`EntryLine` / `StopLossLine` / `TakeProfitLine`), sama seperti Position Sizer. EA ini
**standalone**: tidak butuh, tidak membaca, dan tidak menampilkan indikator apa pun.

## File

| File | Isi |
| --- | --- |
| `HoekaGataRiskCalculator.mq5` | Input, `OnInit/OnTick/OnTimer/OnChartEvent/OnDeinit`, wiring, eksekusi |
| `Includes/HoekaGataRiskCalc_Config.mqh` | Semua `PANEL_*` + tabel warna, 1:1 dengan CSS spec |
| `Includes/HoekaGataRiskCalc_Math.mqh` | `RC_Round`, `RC_CalculateUnitCost`, `RC_CalculateAdjustment`, clamp broker |
| `Includes/HoekaGataRiskCalc_Signal.mqh` | Baca/tulis garis chart `EntryLine` / `StopLossLine` / `TakeProfitLine` |
| `Includes/HoekaGataRiskCalc_Sizing.mqh` | `RC_CalculateRiskAndPositionSize` + `RC_FinishSizing` |
| `Includes/HoekaGataRiskCalc_UI.mqh` | Primitif `OBJ_RECTANGLE_LABEL` / `OBJ_LABEL` / `OBJ_BUTTON` / `OBJ_EDIT` |
| `Includes/HoekaGataRiskCalc_Layout.mqh` | Geometri baris + `RCU_Update` untuk repaint |
| `Includes/HoekaGataRiskCalc_Exec.mqh` | Pemetaan tipe order + `CTrade` |

## Asal setiap angka

Semua rumus memakai nama dan baris asli agar bisa diverifikasi ulang:

| Fungsi di sini | Sumber (`RiskCalculator/Position Sizer.mqh`) |
| --- | --- |
| `RC_Round` | `:9403` |
| `RC_CountDecimalPlaces` | `:9444` |
| `RC_AdjustPositionSizeByMinMaxStep` | `:9911` (menaikkan lot ke `MinLot`) |
| `RC_BrokerizePositionSize` | `:8158` (di bawah `MinLot` → 0) |
| `RC_RoundToSignificant` | `:9926` |
| `RC_GetSymbolByCurrencies` | `:9137` |
| `RC_CalculateAdjustment` | `:9067` |
| `RC_CalculateContractValue` | `:9649` |
| `RC_CalculateUnitCost` | `:9505` |
| `RC_CalculateRiskAndPositionSize` | `:7909` + `:7595` + `:7823` |
| `RC_FinishSizing` | `:7960`–`:8058` (sizing, clamp, reward, R/R) |
| `RCE_BuildPlan` | `OrderType` button (Market / Stop / Limit) + aturan arah `:7932` |

## Level = garis chart (bukan indikator)

Ini bagian yang paling sering disalahpahami, jadi ditulis eksplisit.

Position Sizer **tidak membaca indikator apa pun**. Dia menggambar tiga `OBJ_HLINE`
draggable lalu membacanya kembali dengan
`ObjectGetDouble(0, prefix+"StopLossLine", OBJPROP_PRICE, 0, v)` (`:2254`, `:2258`, `:2305`).
Port ini melakukan hal yang sama (`HoekaGataRiskCalc_Signal.mqh`):

| Objek | Nama | Warna |
| --- | --- | --- |
| Entry | `HGRP_EntryLine` | teal (`CLR_ACCENT`) |
| Stop loss | `HGRP_StopLossLine` | merah (`CLR_SELL`) |
| Take profit | `HGRP_TakeProfitLine` | teal (`CLR_BUY`) |

- Garis dibuat sekali di `OnInit()` **hanya jika belum ada**, jadi setup yang sudah kamu
  gambar/geser tidak pernah ditimpa saat EA di-attach ulang.
- Kalau garis belum ada: kalau indikator HoekaGATA **kebetulan** sedang jalan di chart,
  nilainya dipakai sebagai nilai awal (dibaca sekali, tanpa `iCustom`, tanpa handle,
  tanpa polling); kalau tidak ada, dipakai bid ±1% sebagai placeholder untuk digeser.
- Garis **tidak dihapus** saat EA dilepas — itu setup milik user, bukan milik panel.
- Arah ditentukan ulang tiap tick dengan aturan asli (`:7932`):
  `SL < Entry → BUY`, `SL > Entry → SELL`, `SL == Entry → tidak menghitung`.

> Konsekuensinya: menempelkan Risk Calculator di chart **tidak** akan memunculkan
> indikator HoekaGATA. Menaikkan timeframe / menutup terminal tetap menyisakan garis,
> karena garisnya adalah objek chart biasa.

## Yang sengaja TIDAK di-port

- **Fuse portfolio / margin-utilisation** (`CalculatePortfolioRisk`, `CalculateMarginUtilization`).
  Gate yang dipakai sekarang: `MaxRiskPercentage`, `MaxSpread`, `Max/MinEntrySLDistance`,
  dan aturan min-lot. Semua memblokir, tidak memotong lot.
- **Multi-TP** (`PositionSizerToArray`): `DoTrade` Position Sizer sendiri meruntuhkannya di akun
  netting, jadi satu TP saja yang dipakai.
- **Auto-commission** `SymbolInfoCommissions()`: butuh build MT5 yang lebih baru; field komisi
  manual (`per lot` atau `%` dari nilai kontrak) yang berlaku.
- **Override `ContractSize ← MaintenanceMargin`** (`:8632`). Itu gotcha yang dicatat di
  `Docs/RiskCalculator.md`; jangan ditambahkan tanpa memahami efeknya.
- **Trailing stop / break-even**: di luar lingkup panel kalkulator.

## Pemetaan tipe order

Tipe ditentukan tombol `OrderType` (`HGRP` panel: `InpEntryType` saat start, bisa diganti
lewat klik), bukan ditebak dari harga:

| Mode | Kondisi | Order |
| --- | --- | --- |
| Market / Instant | selalu | `ORDER_TYPE_BUY` @ Ask / `ORDER_TYPE_SELL` @ Bid |
| Stop | `entry > Ask` | `BUY_STOP` |
| Stop | `entry < Bid` | `SELL_STOP` |
| Limit | `entry < Ask` | `BUY_LIMIT` |
| Limit | `entry > Bid` | `SELL_LIMIT` |

Kalau mode Stop/Limit ternyata sudah dilewati harga (entry sudah di sisi yang salah),
`RCE_IsInstantSetup()` menganggapnya fill market — guard yang sama dipakai Position Sizer
sebelum submit. Tidak ada lagi konversi diam-diam "buy + crossed = limit".

## Input

Grup `Risk`: `InpRiskPercent`, `InpCommissionPerLot`, `InpCommissionPercent`,
`InpAdditionalFunds`, `InpSpreadAdjustSL/TP`, `InpAcceptOvershoot`.

Grup `Fuses`: `InpMaxRiskPercent`, `InpMaxSpreadPoints`, `InpMaxEntrySLPoints`,
`InpMinEntrySLPoints` (0 = mati).

Grup `Entry lines`: `InpEntryType` (0 Market, 1 Stop, 2 Limit — default 2 seperti
tombol `OrderType` Position Sizer).

Grup `Execution`: `InpMagicNumber`, `InpDeviationPoints`, `InpExpiryMinutes`,
**`InpTradingEnabled` (default `false`)**, `InpPanelX/Y`, `InpStartMinimized`.

> `InpTradingEnabled = false` membuat footer SELL/BUY selalu nonaktif. Panel tetap menghitung
> dan menampilkan ukuran posisi — sengaja aman secara default.

## Build dan deploy

> **Tidak berlaku lagi.** Target `RiskCalc` sudah dihapus dari
> `Main/Tools/Build-MT5.ps1`; `ValidateSet` sekarang hanya `Indicator | EA | All`.
> Menjalankan `-Target RiskCalc` akan ditolak PowerShell. Isi di bawah disimpan
> hanya sebagai catatan historis.

Target saat itu ada di `Main/Tools/Build-MT5.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File 'c:\Data Syakir\HoekaGATA\Main\Tools\Build-MT5.ps1' -Target RiskCalc
```

- Folder deploy: `MQL5\Experts\HokaGATA RiskCalc\` — **terpisah** dari `Experts\HokaGATA\`
  (EA Algo) dan dari `Experts\HokaGATA Risk Calculator\` (Position Sizer yang di-install manual).
- Deploy folder baru tidak terlihat di Navigator MT5 sampai terminal **di-restart**.
- Prefix objek chart: `HGRP_`. Indikator memakai `HoekaGATA_Engulf_*` + `HG_SIG_*`,
  EA Algo memakai `HGP_`, Position Sizer memakai `PS_`. Tidak ada tabrakan.

## Batasan yang sudah diketahui

1. **Tab Risk / Margin / Swaps / Trading belum berfungsi** — tab bar digambar sesuai spec
   (5 tab, 26 px) tetapi hanya tab *Main* yang punya isi. Klik tab belum berpindah.
2. **`BTN_OTYPE`, `BTN_HIDE`, `BTN_SL_STEP*`, `BTN_TP_*`** digambar tapi belum bereaksi
   sebagai tombol. Tipe order mengikuti input `InpEntryType` (bisa diubah lewat
   parameter EA lalu di-attach ulang).
3. **Belum ada stop-limit** (`StopPriceLine` di asli, `:2306`) dan belum ada
   step SL/TP berbasis `Point`/`ATR`. Diukur dengan menggeser garis.

## Panel floating (drag) dan optimasi VPS

### Menggeser panel

MT5 tidak punya `OBJ_RECTANGLE_LABEL` yang bisa di-drag. Yang dipakai adalah trik
standar yang juga dipakai Position Sizer: tombol transparan (`HGRP_DRAG`) ditumpuk
di atas header sebagai *drag handle*.

| Tahap | Event | Aksi |
| --- | --- | --- |
| Mulai | `CHARTEVENT_OBJECT_CLICK` pada `HGRP_DRAG` | simpan offset kursor, `CHART_MOUSE_SCROLL = false` |
| Geser | `CHARTEVENT_MOUSE_MOVE` dengan tombol kiri turun | `RCU_Shift(dx, dy)` — hanya `OBJPROP_XDISTANCE/YDISTANCE` |
| Lepas | `CHARTEVENT_MOUSE_MOVE` tanpa tombol | `CHART_MOUSE_SCROLL = true` |
| Resize chart | `CHARTEVENT_CHART_CHANGE` | `RCU_ClampToChart()` menarik panel kembali ke layar |

Catatan implementasi:

- Handle dikenali lewat `OBJPROP_BACK == true` — satu-satunya objek `HGRP_` yang
  memakai flag itu, jadi tidak perlu daftar nama.
- Lebar handle = `PANEL_W - 54` supaya dua tombol `TOOL_SNAP`/`TOOL_MIN` di kanan
  header tetap bisa diklik.
- `RCU_Shift()` menulis ulang posisi objek, **bukan** `RCU_BuildPanel()`. Tidak ada
  `ObjectCreate` atau perubahan teks/font saat drag, jadi murah.
- Panel boleh menempel ke tepi (overhang 40 px) tetapi header tidak pernah bisa
  hilang dari layar.
- Posisi **tidak** dipersist antar sesi — kembali ke `InpPanelX/InpPanelY` setelah
  EA di-reload. `TOOL_SNAP` mengembalikan ke `(12, 12)`.

### Ringan untuk VPS

Tiga penghematan yang dipasang:

1. **`OnTick()` dikosongkan.** Dulu `OnTick` dan `OnTimer` sama-sama memanggil
   `RefreshAll()`. Simbol ramai menghasilkan ribuan tick per menit, jadi sizing
   dihitung ulang ribuan kali padahal panel hanya butuh ~4 Hz. Sekarang satu jam
   tunggal: `OnTimer` 250 ms.
2. **`RCU_Update()` di-skip bila tidak ada yang berubah.** Semua nilai yang
   digambar dirangkum jadi satu signature string; bila identik dengan signature
   sebelumnya, ~40 panggilan `ObjectSetString`/`ObjectSetInteger` dilewati.
   Setiap panggilan itu adalah round-trip ke thread chart.
3. **Drag tidak membangun ulang objek** (lihat di atas).

`RcUI.sig` di-reset ke `""` di `RCU_BuildPanel()` dan `OnInit()`, jadi repaint
penuh tetap terjadi setiap kali panel dibangun ulang.

## Koreksi paritas terhadap Position Sizer 3.16d

### 0. Level: indikator → garis chart (2026-10-24)

Versi pertama membaca `HG_SIG_*` (dan punya fallback `iCustom`). Akibatnya
menempelkan kalkulator di chart ikut "menyeret" indikator ke dalam gambar dan
membuat panel menampilkan "Indicator not attached" saat indikator tidak ada.

Position Sizer sendiri tidak pernah membaca indikator — dia membaca tiga garis
chart (`:2254`, `:2258`, `:2305`). Port sekarang mengikuti itu persis:
`RCS_ReadLevels()` / `RCS_WriteLine()` di `HoekaGataRiskCalc_Signal.mqh`.
`iCustom`, handle indikator, heartbeat, `InpSignalShift`, dan
`InpMaxSignalAgeSeconds` semuanya dihapus. Arah posisi dihitung ulang dari
`Entry` vs `SL` (`:7932`).

### 1. Sisi konversi mata uang (`:9067`)

`CalculateAdjustment()` versi asli memakai enum `PROFIT_LOSS`, **bukan** arah
posisi. Port sebelumnya menumpangkan `POSITION_TYPE_BUY/SELL` di atas parameter
itu — hasilnya kebetulan benar karena `SELL` jatuh ke cabang `else`, tetapi
rapuh. Sekarang enum aslinya direproduksi:

```cpp
enum RC_PROFIT_LOSS { RC_Profit, RC_Loss };
```

| `calc_mode` | Harga yang dipakai (`:9080-9088`) |
| --- | --- |
| `RC_Profit` | `tick.bid` — menjual CCY1 untuk merealisasi profit |
| `RC_Loss` | `tick.ask` — membeli CCY1 untuk menutup loss |

Pemanggil disamakan dengan asli: `:9515`/`:9518` (unit cost) dan `:9668`
(contract value) memakai sisi `Loss`, sisi `Profit` hanya untuk unit cost reward.

### 2. Deteksi overshoot MinLot (`:9913`)

`AdjustPositionSizeByMinMaxStep()` menaikkan **semua** ukuran di bawah `MinLot`,
termasuk nol (budget risiko terlalu kecil untuk satu lot terkecil). Port
sebelumnya hanya memeriksa `rawSize > 0`, sehingga kasus `rawSize == 0` lolos ke
footer sebagai ukuran yang tampak sah.

Deteksi sekarang dipindah ke **setelah** `outputRiskMoney` dihitung, dengan
kondisi `positionSize > rawSize && outputRiskMoney > riskMoney` — yaitu "MinLot
memaksa risiko melebihi budget", bukan sekadar "lot naik".

### Bukan bug (diverifikasi ulang)

- `AdditionalFunds` **memang** berlaku juga pada mode Equity. Asli `:7687`:
  `if (sets.CustomBalance <= 0) AccSize += AdditionalFunds;` — tidak dibatasi
  mode. Sudah didokumentasikan di `Docs/RiskCalculator.md:223`.
