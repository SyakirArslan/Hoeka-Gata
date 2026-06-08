# HoekaGataIndicator MT5

`HoekaGataIndicator.mq5` adalah indikator MT5 hasil konversi dari Pine Script `HoekaGata Wave3 Pro`. Indikator menggambar struktur wave, zona fibonacci, trendline, panel probability, dan menyediakan buffer signal untuk EA.

## Lokasi File

```text
Main/MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5
Main/MQL5/Indicators/HokaGATA/Includes/HoekaGataIndicator_Config.mqh
Main/MQL5/Indicators/HokaGATA/Includes/HoekaGataIndicator_License.mqh
Main/MQL5/Indicators/HokaGATA/Includes/HoekaGataIndicator_Swing.mqh
Main/MQL5/Indicators/HokaGATA/Includes/HoekaGataIndicator_WaveRules.mqh
Main/MQL5/Indicators/HokaGATA/Includes/HoekaGataIndicator_Stats.mqh
Main/MQL5/Indicators/HokaGATA/Includes/HoekaGataIndicator_Drawing.mqh
Main/MQL5/Indicators/HokaGATA/Includes/HoekaGataIndicator_Panel.mqh
Main/MQL5/Indicators/HokaGATA/Includes/HoekaGataIndicator_Core.mqh
```

## Buffer Indicator

| Buffer | Isi |
| --- | --- |
| `0` | BUY signal entry. |
| `1` | SELL signal entry. |
| `2` | Signal SL. |
| `3` | Signal TP. |
| `4` | Signal Extend TP. |

Plot BUY dan SELL memakai `DRAW_NONE` karena signal dipakai untuk EA dan publikasi data, sementara visual chart digambar dengan object MT5.

## Input Utama

| Input | Fungsi |
| --- | --- |
| `InpPivotMin` | Jarak swing minimal. |
| `InpPivotMax` | Jarak swing maksimal. |
| `InpDisplayMode` | `DisplayLatestOnly` atau `DisplayHistory`. |
| `InpEnableDrawing` | Mengaktifkan object drawing di chart. |
| `InpShowWave3` | Mengaktifkan signal Wave 3. |
| `InpShowWaveLines` | Menampilkan garis wave. |
| `InpShowFibLines` | Menampilkan level fibonacci. |
| `InpShowTrendLines` | Menampilkan trendline 0-2 dan 1-3. |
| `InpShowEntryPriceLine` | Menampilkan garis/label entry. |
| `InpShowWaveLabels` | Menampilkan label wave 0, 1, 2, 3. |
| `InpEnableWave3Alerts` | Mengaktifkan alert Wave 3. |
| `InpEnableBuyAlerts` | Mengaktifkan alert BUY. |
| `InpEnableSellAlerts` | Mengaktifkan alert SELL. |
| `InpEnablePushNotify` | Mengirim push notification MT5 jika terminal sudah dikonfigurasi. |
| `InpUseParallelSlopeRule` | Validasi slope 0-2 dan 1-3. |
| `InpParallelTolerance` | Toleransi slope parallel. |
| `InpWave2FibTolerance` | Toleransi zona Wave 2. |
| `InpMinBarsBetweenEntry` | Jarak minimal antar signal entry. |
| `InpSuppressSignalsWhileTradeOpen` | Menahan signal baru saat trade virtual masih open. |
| `InpSignalConfirmDelaySeconds` | Delay konfirmasi signal sebelum dipublish. |
| `InpMaxBarsToProcess` | Batas jumlah bar yang diproses. |
| `InpShowProbabilityPanel` | Menampilkan panel probability. |
| `InpPublicZoneLabels` | Memakai label publik seperti `Confirm Zone`, `SL`, `TP`. |

## Rule Signal

- Pivot mentah memakai `RAW_PIVOT_LEN = 2`.
- Swing disusun bergantian high/low dengan filter `InpPivotMin` dan `InpPivotMax`.
- Wave 2 valid jika berada di zona fib `0.500` sampai `0.618` dengan toleransi.
- BUY muncul dari sequence downtrend yang break Wave 1.
- SELL muncul dari sequence uptrend yang break Wave 1.
- Entry memakai level fib `1.618`.
- SL memakai level Wave 3 `-0.270`.
- TP memakai retracement Wave 4 `0.618`.
- Extend TP memakai retracement Wave 4 `0.786`.
- Jika TP dan SL kena pada candle yang sama, SL dihitung lebih dulu untuk statistik probability.

## Output ke EA

Indikator menulis data signal ke:

- Buffer indicator untuk `CopyBuffer`.
- MT5 Global Variables dengan prefix `HG_SIG_`.

EA memakai kedua sumber ini untuk menjaga signal tetap terbaca, terutama pada mode VPS dan saat chart refresh.

## Cara Pakai

1. Copy folder indikator ke `MQL5/Indicators/HokaGATA/`.
2. Compile `HoekaGataIndicator.mq5`.
3. Pasang indikator ke chart.
4. Sesuaikan pivot, display mode, drawing, alert, dan warna.
5. Jika akan dipakai oleh EA, jangan ubah nama folder/file indikator.
