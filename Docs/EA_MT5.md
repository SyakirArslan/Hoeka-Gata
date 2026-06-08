# HoekaGataAlgo EA MT5

`HoekaGataAlgo.mq5` adalah Expert Advisor untuk membaca signal dari `HoekaGataIndicator` dan membuka posisi otomatis sesuai filter yang aktif.

## Lokasi File

```text
Main/MQL5/Experts/HokaGATA/HoekaGataAlgo.mq5
Main/MQL5/Experts/HokaGATA/Includes/HoekaGataAlgo_Config.mqh
Main/MQL5/Experts/HokaGATA/Includes/HoekaGataAlgo_Trading.mqh
Main/MQL5/Experts/HokaGATA/Includes/HoekaGataAlgo_Panel.mqh
```

## Dependency

EA membutuhkan indikator MT5 di path berikut:

```text
MQL5/Indicators/HokaGATA/HoekaGataIndicator.ex5
```

Di source EA, indikator dipanggil lewat:

```mql5
iCustom(_Symbol, _Period, "HokaGATA\\HoekaGataIndicator")
```

Karena itu folder dan nama file indikator harus sesuai.

## Input Utama

| Input | Fungsi |
| --- | --- |
| `InpAlgoEnabled` | Status awal algo saat EA dipasang. Default `false`. |
| `InpAllowBuy` | Mengizinkan posisi BUY. |
| `InpAllowSell` | Mengizinkan posisi SELL. |
| `InpUseExtendTP` | Memakai Extend TP dari indikator, bukan TP normal. |
| `InpRiskBuyPercent` | Risk persen untuk posisi BUY. |
| `InpRiskSellPercent` | Risk persen untuk posisi SELL. |
| `InpUseTradingTime` | Mengaktifkan filter jam trading. |
| `InpStartTime` | Jam mulai trading format `HH:MM`. |
| `InpEndTime` | Jam selesai trading format `HH:MM`. Bisa melewati tengah malam. |
| `InpUseSpreadFilter` | Mengaktifkan filter spread. |
| `InpMaxSpreadPoints` | Batas maksimum spread dalam points. |
| `InpMagicNumber` | Magic number untuk membedakan posisi EA. |
| `InpUseClosedBarSignal` | Membaca signal dari candle yang sudah close. |
| `InpMinBarsBetweenEntry` | Jarak minimal antar entry dalam jumlah bar. |
| `InpDeviationPoints` | Slippage/deviation order dalam points. |
| `InpRecalculateSLTPFromActualEntry` | Hitung ulang SL/TP dari harga entry aktual. |
| `InpMaxConsecutiveLosses` | Batas loss beruntun. `0` berarti tidak dibatasi. |
| `InpVpsMode` | Mode VPS, memproses signal di timer. |
| `InpShowPanel` | Menampilkan panel kontrol EA. |
| `InpPanelUpdateSeconds` | Interval update panel. |

## Rule Trading

- EA membuka maksimal satu posisi aktif per symbol dan magic number.
- Signal BUY/SELL diambil dari indikator.
- SL, TP, dan Extend TP diambil dari buffer indikator.
- Lot dihitung berdasarkan risk persen dan jarak entry ke SL.
- Spread filter memakai `SYMBOL_SPREAD`.
- Filter waktu memakai server time broker.
- Panel menyimpan konfigurasi memakai MT5 Global Variables per akun, symbol, dan timeframe.

## Cara Pakai

1. Compile dan pasang `HoekaGataIndicator` lebih dulu.
2. Pasang `HoekaGataAlgo` pada chart symbol/timeframe yang sama.
3. Pastikan AutoTrading MT5 aktif.
4. Atur risk, arah trading, spread, time filter, dan magic number.
5. Aktifkan Algo dari panel jika semua parameter sudah benar.

## Catatan Panel

Panel EA menyediakan kontrol untuk:

- Algo ON/OFF.
- BUY dan SELL ON/OFF.
- Extend TP.
- Risk BUY dan SELL.
- Trading time.
- Spread filter.
- Closed bar signal.
- Recalculate SL/TP.
- Deviation.
- Min bars between entry.
- Max consecutive losses.
- Magic number.

Jika `InpVpsMode = true`, panel drag dan interaksi mouse chart dibuat lebih ringan untuk penggunaan VPS.
