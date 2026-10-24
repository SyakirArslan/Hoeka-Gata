# EA MT5 — HoekaGataAlgo

EA ini mengeksekusi signal dari indikator `HoekaGataIndicator` (Engulfing Breakout). EA **tidak**
mendeteksi pola sendiri: arah, entry, SL, dan TP sepenuhnya berasal dari indikator. Tugas EA adalah
menyaring signal dengan aturan risk, lalu mengirim order pasar.

- **File utama:** `Main/MQL5/Experts/HokaGATA_Algo/HoekaGataAlgo.mq5`
- **Include:** `Includes/HoekaGataAlgo_Config.mqh`, `_Trading.mqh`, `_Panel.mqh`
- **Indikator acuan:** `#property tester_indicator "HokaGATA\HoekaGataIndicator.ex5"`
- **Prefix objek panel:** `HGCP_`
- **Magic default:** `20260525`
- **Butuh:** indikator terpasang pada chart yang sama (kecuali di Strategy Tester)

## Modul

| File | Tanggung jawab |
| --- | --- |
| `HoekaGataAlgo.mq5` | Input, konstanta warna/geometri panel, state global, `OnInit` / `OnTick` / `OnTimer` / `OnTradeTransaction` / `OnChartEvent` |
| `Includes/HoekaGataAlgo_Trading.mqh` | `ProcessSignal`, `ExecuteSignal`, filter, pembacaan signal, perhitungan lot, logging, handle indikator |
| `Includes/HoekaGataAlgo_Panel.mqh` | Panel kontrol 2 halaman, drag, edit value, tombol toggle, sinkronisasi input |
| `Includes/HoekaGataAlgo_Config.mqh` | Parsing waktu/angka, clamp, baca/tulis konfigurasi panel ke `GlobalVariable` |

## Lifecycle

### OnInit

1. Salin semua input ke variabel global (`g_*`), dengan clamp: `MinBarsBetweenEntry`,
   `DeviationPoints`, `MaxConsecutiveLosses` minimal 0, `PanelUpdateSeconds` minimal 1.
2. Parse `InpStartTime` / `InpEndTime` (`HH:MM`). Bila format salah, dipakai fallback `07:00` dan
   `03:00`.
3. `LoadPanelConfig()` menimpa nilai input dengan konfigurasi terakhir dari panel (bila ada).
4. Set magic number dan deviation pada object `CTrade`.
5. `CHART_EVENT_MOUSE_MOVE` hanya diaktifkan bila panel tampil **dan** `InpVpsMode = false`.
6. `EnsureIndicatorSignalSource()`: cari sumber signal. Bila gagal, EA tetap `INIT_SUCCEEDED`,
   menampilkan alasan di panel, lalu mencoba lagi setiap tick.
7. Buat panel (bila `InpShowPanel`), start timer 1 detik, set reason `Ready`.

### OnDeinit

`EventKillTimer()`, `StopPanelDrag()`, `ReleaseIndicatorHandle()`, `DeleteControlPanel()`,
`ChartRedraw(0)`. Indikator **tidak** dilepas dari chart: indikator dikelola user, dan harus tetap
terpasang saat EA di-reload karena perubahan input, recompile, atau restart.

### OnTick / OnTimer

| Mode | OnTick | OnTimer (1 detik) |
| --- | --- | --- |
| `InpVpsMode = true` (default) | tidak memproses signal, tidak update panel | `ProcessSignal()` + update panel (dibatasi `InpPanelUpdateSeconds`) |
| `InpVpsMode = false` | `ProcessSignal()` + update panel | `ProcessSignal()` + update panel |

Mode VPS memindahkan seluruh pekerjaan ke timer supaya beban chart tidak bergantung pada jumlah tick.

### OnTradeTransaction

Setiap deal keluar (`DEAL_ENTRY_OUT` / `DEAL_ENTRY_OUT_BY`) pada symbol dan magic yang sama dihitung:
profit bersih (`DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION`) negatif menambah `g_consecutiveLosses`,
positif mereset ke 0. Bila `InpMaxConsecutiveLosses > 0` dan batas tercapai, EA mematikan dirinya
(`g_algoEnabled = false`) dan menulis `Loss limit x/y` ke reason + log.

## Input

| Input | Default | Arti |
| --- | --- | --- |
| `InpAlgoEnabled` | `false` | Status awal algo (bisa di-toggle dari panel) |
| `InpAllowBuy` | `true` | Izinkan eksekusi signal BUY |
| `InpAllowSell` | `true` | Izinkan eksekusi signal SELL |
| `InpRiskBuyPercent` | `5` | Risiko per trade BUY (% balance) |
| `InpRiskSellPercent` | `5` | Risiko per trade SELL (% balance) |
| `InpUseTradingTime` | `false` | Aktifkan filter jam trading |
| `InpStartTime` | `07:00` | Awal window (server time) |
| `InpEndTime` | `03:00` | Akhir window (server time); bila start > end, window melewati tengah malam |
| `InpUseSpreadFilter` | `true` | Aktifkan filter spread |
| `InpMaxSpreadPoints` | `25` | Spread maksimum (point) |
| `InpMagicNumber` | `20260525` | Magic number order EA |
| `InpUseClosedBarSignal` | `false` | `false` = baca shift 0 (bar berjalan), `true` = shift 1 (bar tertutup) |
| `InpMinBarsBetweenEntry` | `30` | Jarak minimum antar entry dalam bar |
| `InpDeviationPoints` | `20` | Slippage maksimum (point) untuk `CTrade` |
| `InpRecalculateSLTPFromActualEntry` | `true` | Sesuaikan SL/TP dari harga fill sebenarnya, rasio R:R tetap |
| `InpMaxConsecutiveLosses` | `0` | Batas loss berurutan; `0` = tanpa batas |
| `InpVpsMode` | `true` | Pindahkan proses ke `OnTimer` (hemat CPU, cocok untuk VPS) |
| `InpShowPanel` | `true` | Tampilkan panel kontrol |
| `InpPanelUpdateSeconds` | `1` | Interval minimum refresh panel (detik) |

## Alur Eksekusi Signal

```text
ProcessSignal()
  ├─ EnsureIndicatorSignalSource()  gagal -> reason = alasan indikator, keluar
  ├─ !g_algoEnabled                 -> reason = "Manual mode", keluar
  ├─ shift = InpUseClosedBarSignal ? 1 : 0
  ├─ signalTime = iTime(shift); sama dengan g_lastSignalTime -> keluar
  ├─ ReadSignalAtShift(shift)       gagal -> "Waiting signal"
  ├─ direction == 0                 -> "Ready"
  └─ ExecuteSignal(...)
```

`ReadSignalAtShift()` hanya menerima `shift` 0 atau 1. Jadi `InpUseClosedBarSignal = true` berarti EA
bereaksi pada bar yang sudah tutup; `false` berarti bereaksi pada bar berjalan (fill intra-bar).

### Filter di `ExecuteSignal` (berurutan, berhenti pada kegagalan pertama)

| Urutan | Kondisi gagal | Reason di panel | Log |
| --- | --- | --- | --- |
| 1 | BUY tapi `InpAllowBuy = false` | `Buy disabled` | `blocked: buy disabled` |
| 2 | SELL tapi `InpAllowSell = false` | `Sell disabled` | `blocked: sell disabled` |
| 3 | jarak entry < `InpMinBarsBetweenEntry` | `Entry distance n/m` | `blocked: entry distance` |
| 4 | di luar window waktu | `Outside time` | `blocked: outside trading time` |
| 5 | spread > `InpMaxSpreadPoints` | `Spread high n/m` | `blocked: spread high` |
| 6 | SL/TP hasil rekalkulasi tidak valid | `Invalid recalculated SLTP` | `blocked: invalid recalculated SL/TP` |
| 7 | lot hasil hitung <= 0 | `Invalid risk` | `blocked: invalid risk or SL/TP` |

Setelah lolos semua filter, EA mengirim order pasar (`trade.Buy` / `trade.Sell`) dengan SL dan TP
`NormalizeDouble(..., _Digits)`, komentar `HG-Buy` / `HG-Sell`.

- `g_lastSignalTime` **hanya** di-set setelah order berhasil terkirim. Bila pengiriman gagal, signal
  yang sama akan dicoba lagi pada tick berikutnya (mis. saat spread menyempit).
- Reason terakhir (`Order sent` / `Order failed <retcode>`) selalu ditampilkan di panel dan ditulis ke
  log lengkap dengan symbol, bar time, entry, SL, TP, lot, spread.

### Format log

Setiap keputusan (diblokir maupun dieksekusi) menulis satu baris:

```text
HoekaGataAlgo EA: <decision> | signal=BUY | bar=2026.05.25 10:00 | entry=2401.40 |
sl=2390.60 | tp=2423.00 | lot=0.42 | spread=18 | reason=<reason>
```

## Perhitungan Lot

```text
riskMoney  = ACCOUNT_BALANCE * riskPercent / 100          (BUY pakai InpRiskBuyPercent)
slDistance = |hargaPasar - SL|                            (harga pasar = ASK untuk BUY, BID untuk SELL)
lossPerLot = slDistance / SYMBOL_TRADE_TICK_SIZE * SYMBOL_TRADE_TICK_VALUE
rawLot     = riskMoney / lossPerLot
lot        = NormalizeVolume(rawLot)
```

`NormalizeVolume()` membatasi ke `SYMBOL_VOLUME_MIN` / `MAX` dan membulatkan **ke bawah** ke kelipatan
`SYMBOL_VOLUME_STEP`. Validasi tambahan: untuk BUY harus `SL < harga pasar < TP`, untuk SELL harus
`SL > harga pasar > TP`; bila tidak, lot = 0 dan trade dibatalkan dengan reason `Invalid risk`.

## Rekalkulasi SL/TP dari Harga Fill

Bila `InpRecalculateSLTPFromActualEntry = true` dan harga pasar berbeda dari harga entry signal:

```text
rr          = |TP_signal - ENTRY_signal| / |ENTRY_signal - SL_signal|
riskDistance = |ENTRY_signal - SL_signal|
BUY  : SL = fill - riskDistance        TP = fill + rr * riskDistance
SELL : SL = fill + riskDistance        TP = fill - rr * riskDistance
```

Tujuannya: jarak risiko dan rasio R:R tetap sama seperti yang diusulkan indikator, meski terjadi
slippage. Bila hasilnya tidak masuk akal (`SL` di sisi yang salah, `TP` tidak searah), order
dibatalkan dengan reason `Invalid recalculated SLTP`.

## Sumber Signal

`EnsureIndicatorSignalSource()` memilih jalur secara berurutan:

1. **Strategy Tester** → `CreateTesterIndicatorHandle()` memakai `#property tester_indicator`.
2. **`GlobalVariable` publish** → bila `HG_SIG_<chartid>_HB` ada, EA membaca slot `C`/`P` dan
   memvalidasi `_T` terhadap `iTime()`; data basi diabaikan.
3. **Handle chart** → `FindChartIndicatorHandle()` mencari indikator di chart yang short name-nya cocok
   (`IsHoekaGataIndicatorShortName`), lalu `ReadSignalFromIndicatorHandle()` memakai `CopyBuffer`
   indeks 0..3.
4. Bila ketiganya gagal: reason `IndicatorMissingReason()` dan peringatan di log
   (`WarnMissingChartIndicator` / `WarnMissingTesterIndicator`), tanpa mematikan EA.

Handle dilepas pada `OnDeinit` (`ReleaseIndicatorHandle`). EA tidak menghapus indikator dari chart
(`DeleteChartSignalIndicators` hanya dipakai untuk pembersihan internal).

## Panel Kontrol

Panel EA (`InpShowPanel = true`) memakai prefix objek `HGCP_`, lebar 220 px (190 px saat minimized),
header 28 px, tinggi baris 25 px, dan `ZORDER` 1000 agar selalu di atas objek chart lain.

### Struktur

- **Title bar**: judul, tombol minimize (`BTN_MIN`) dan close (`BTN_CLOSE`).
- **Dua tab**: `Trading` (`BTN_PAGE_TRADING`) dan `Setup` (`BTN_PAGE_SETUP`).
- **Reason box**: alasan terakhir EA mengambil/menolak keputusan (mis. `Ready`, `Outside time`,
  `Order sent`).
- **Credit box** di bawah panel.

### Halaman Trading

| Section | Kontrol | Aksi |
| --- | --- | --- |
| Main | `BTN_ALGO` | toggle algo on/off |
| Main | `EDIT_MAX_LOSSES` | batas loss berurutan (0–1000) |
| Main | `VAL_LOSS_STREAK` | readout `losses/limit`, warna warning bila limit tercapai |
| Risk | `EDIT_RISK_BUY_PERCENT` + `VAL_RISK_BUY_USD` | risiko BUY % (0.01–100) dan nilai uangnya |
| Risk | `EDIT_RISK_SELL_PERCENT` + `VAL_RISK_SELL_USD` | risiko SELL % dan nilai uangnya |
| Trade | `BTN_BUY`, `BTN_SELL` | izinkan / larang arah trading |

### Halaman Setup

| Section | Kontrol | Aksi |
| --- | --- | --- |
| Execution | `BTN_CLOSED_BAR` | sinyal dari bar tertutup (shift 1) |
| Execution | `BTN_RECALC_SLTP` | rekalkulasi SL/TP dari harga fill |
| Execution | `EDIT_DEVIATION_POINTS` | slippage (0–10000), langsung diterapkan ke `CTrade` |
| Execution | `EDIT_MIN_BARS_ENTRY` | jarak minimum antar entry (0–10000) |
| Spread | `BTN_SPREAD_FILTER`, `EDIT_MAX_SPREAD` | filter spread on/off, batas 1–10000 point |
| Time | `BTN_TRADING_TIME`, `EDIT_START_TIME`, `EDIT_END_TIME` | window trading; format harus `HH:MM` |

Validasi input panel: teks yang tidak valid **diabaikan** dan field dikembalikan ke nilai lama
(`SyncEditValues()`). Semua perubahan langsung disimpan.

### Drag dan posisi

- Posisi panel disimpan di `g_panelX` / `g_panelY` (tidak boleh negatif).
- Drag mengikuti mouse hanya bila `CHART_EVENT_MOUSE_MOVE` aktif, yaitu saat `InpVpsMode = false`.
  Selain itu posisi tetap dapat diubah lewat event `CHARTEVENT_OBJECT_DRAG` pada objek panel.
- Menutup panel (`BTN_CLOSE`) menghapus objek panel; tampilkan lagi dengan me-reload EA.

## Penyimpanan Konfigurasi Panel

Semua nilai panel disimpan sebagai `GlobalVariable` terminal, sehingga bertahan setelah MT5 restart:

```text
HokaGATA.AutoTrader.<login>.<symbol>.<periode>.<Key>
```

Key yang disimpan: `AllowBuy`, `AllowSell`, `UseTradingTime`, `UseSpreadFilter`, `UseClosedBarSignal`,
`RecalculateSLTPFromActualEntry`, `RiskBuyPercent`, `RiskSellPercent`, `StartMinutes`, `EndMinutes`,
`MaxSpreadPoints`, `DeviationPoints`, `MinBarsBetweenEntry`, `MaxConsecutiveLosses`, `MagicNumber`,
`PanelX`, `PanelY`, `PanelPage`, `PanelMinimized`.

Implikasi penting:

1. Konfigurasi panel **menimpa** input EA saat `OnInit`, jadi mengubah input di tab Input tidak selalu
   berefek bila konfigurasi lama masih tersimpan.
2. Konfigurasi terpisah per login + symbol + timeframe.
3. Status `Algo` **tidak** disimpan: EA selalu mulai dari `InpAlgoEnabled`. Ini pengaman agar algo
   tidak otomatis aktif setelah restart.
4. Untuk kembali ke nilai input, hapus `GlobalVariable` `HokaGATA.AutoTrader.*` (mis. lewat
   Tools → Global Variables di MT5) lalu reload EA.

## Instalasi dan Pemakaian

1. Deploy dengan `.\Build-MT5.ps1` (indikator + EA) atau copy manual ke
   `MQL5\Indicators\HokaGATA\` dan `MQL5\Experts\HokaGATA\`.
2. Pasang `HoekaGataIndicator` pada chart.
3. Pasang `HoekaGataAlgo` pada symbol/timeframe yang sama.
4. Sesuaikan risk %, spread, waktu, arah, magic number.
5. Aktifkan `Algo` di panel hanya setelah semua nilai benar.
6. Pantau reason box dan tab Experts untuk melihat keputusan EA.

### Strategy Tester

- EA membuat instance indikator sendiri lewat `#property tester_indicator`, jadi indikator tidak perlu
  dipasang pada chart tester.
- Input indikator yang dipakai adalah **default hasil compile**, bukan input chart. Compile ulang
  indikator setiap kali default berubah.
- Simulasi mengandalkan model tick; hasil dengan "Every tick" paling mendekati kondisi real.

## Troubleshooting

| Gejala | Kemungkinan penyebab | Solusi |
| --- | --- | --- |
| Reason `Indicator not found` / warning indikator | Indikator belum terpasang, atau nama/path diubah | Pasang `HoekaGataIndicator` di chart yang sama; jangan rename file/folder |
| Reason `Manual mode` | `Algo` masih off | Klik `Algo` di panel atau set `InpAlgoEnabled = true` |
| Reason `Waiting signal` | Bar ini tidak punya signal di buffer | Normal; tunggu bar berikutnya atau cek indikator |
| Reason `Outside time` | Di luar window `Start`/`End` | Sesuaikan jam, atau matikan filter waktu |
| Reason `Spread high n/m` | Spread melebihi batas | Naikkan `Max` atau matikan filter spread |
| Reason `Invalid risk` | Risk % terlalu kecil untuk min lot, SL terlalu jauh, atau SL/TP di sisi salah | Naikkan risk %, periksa level indikator dan setting symbol |
| Reason `Order failed <retcode>` | Margin kurang, market tertutup, atau penolakan broker | Cek retcode di log dan tab Experts |
| Panel tidak muncul | `InpShowPanel = false` atau panel sudah ditutup | Reload EA |
| Nilai input tidak terpakai | Konfigurasi panel lama masih tersimpan | Hapus `GlobalVariable` `HokaGATA.AutoTrader.*` |
| EA berhenti sendiri | `InpMaxConsecutiveLosses` tercapai | Evaluasi, lalu aktifkan `Algo` kembali |

## Batasan

- EA hanya mengirim **market order**; tidak ada trailing stop, partial close, atau breakeven.
- EA tidak memeriksa posisi yang sudah terbuka. Pengaman yang tersedia hanya `InpMinBarsBetweenEntry`
  dan fakta bahwa satu signal bar hanya dieksekusi sekali (setelah order sukses).
- Tidak ada pengecekan margin bebas atau `SYMBOL_TRADE_STOPS_LEVEL` sebelum order; penolakan broker
  akan muncul sebagai `Order failed <retcode>`.
- Konfigurasi tersimpan per login + symbol + timeframe, bukan global.
- EA bergantung pada indikator: bila indikator dilepas atau di-rename, EA berhenti mengeksekusi dan
  hanya menampilkan alasan.

