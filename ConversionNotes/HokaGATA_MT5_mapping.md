# HoekaGata Pine to MT5 Mapping

Dokumen ini menjelaskan mapping logic dari TradingView Pine Script ke indikator dan EA MT5.

## Source dan Output

| Bagian | Path |
| --- | --- |
| Pine Script source | `Source/HoekaGata_Wave3Pro.pine` |
| Indikator MT5 | `Main/MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5` |
| EA MT5 | `Main/MQL5/Experts/HokaGATA/HoekaGataAlgo.mq5` |

## Mapping Modul Indikator

| Modul MT5 | Tanggung jawab |
| --- | --- |
| `HoekaGataIndicator_Config.mqh` | Input, konstanta fib, buffer, dan state ringan. |
| `HoekaGataIndicator_License.mqh` | Validasi/license gate dan notifikasi jika tidak valid. |
| `HoekaGataIndicator_Swing.mqh` | Deteksi raw pivot dan penyusunan swing high/low. |
| `HoekaGataIndicator_WaveRules.mqh` | Validasi fib Wave 2, entry, SL, TP, Extend TP, dan slope parallel. |
| `HoekaGataIndicator_Stats.mqh` | Tracking trade virtual untuk probability panel. |
| `HoekaGataIndicator_Drawing.mqh` | Object chart MT5 untuk wave, fib, trendline, label, dan cleanup. |
| `HoekaGataIndicator_Panel.mqh` | Panel probability di chart. |
| `HoekaGataIndicator_Core.mqh` | Loop kalkulasi utama dan trigger BUY/SELL. |

## Rule yang Dikonversi

- Raw pivot detection memakai `RAW_PIVOT_LEN = 2`, mengikuti delay konfirmasi pivot TradingView.
- Swing sequence mengikuti pola alternating high/low dengan filter `Pivot Min` dan `Pivot Max`.
- Wave 2 valid pada zona fib `0.500` sampai `0.618` dengan tolerance.
- Aggressive Wave 3 signal aktif saat struktur 0-1-2 break Wave 1.
- Optional entry fib barrier dapat mewajibkan harga break level trigger, misalnya `1.272`, sebelum signal valid.
- BUY berasal dari downtrend sequence.
- SELL berasal dari uptrend sequence.
- Fibo `1.618` adalah level visual entry extension dan bisa dimatikan dari display input.
- SL memakai fib Wave 3 `-0.270`.
- TP memakai retracement Wave 4.
- Extend TP memakai retracement Wave 4 `0.786`.
- Parallel slope rule membandingkan slope 0-2 dan 1-3.
- Probability panel menghitung trade virtual berdasarkan TP/SL setelah entry.
- Jika TP dan SL kena pada candle yang sama, SL dihitung lebih dulu.

## Penyesuaian MT5

- TradingView `table` menjadi object label MT5 di kanan atas chart.
- TradingView `label` dan `line` menjadi object chart MT5 dengan prefix `HoekaGataIndicator_MT5_`.
- Mode `Latest only` membersihkan object lama sebelum drawing setup terbaru.
- Public labels dapat memakai nama umum seperti `Confirm Zone`, `Entry`, `SL`, `TP`, dan `Extend TP`.
- Wave 3 signal engine selalu aktif; display input hanya mengatur object chart, bukan mematikan signal engine.
- Alert signal mengikuti toggle BUY dan SELL; tidak ada master Wave 3 alert toggle terpisah.
- MT5 push notification hanya aktif jika terminal sudah dikonfigurasi dan `InpEnablePushNotify = true`.
- Signal dipublish ke indicator buffers dan MT5 Global Variables agar EA dapat membaca signal lebih stabil.

## Mapping Buffer ke EA

| Buffer indikator | Dibaca EA sebagai |
| --- | --- |
| `0` | BUY entry |
| `1` | SELL entry |
| `2` | SL |
| `3` | TP |
| `4` | Extend TP |

EA membaca indikator melalui:

```mql5
iCustom(_Symbol, _Period, "HokaGATA\\HoekaGataIndicator")
```

Karena itu output compile indikator harus berada di:

```text
MQL5/Indicators/HokaGATA/HoekaGataIndicator.ex5
```

## Mapping TradingView ke MT5

| TradingView | MT5 |
| --- | --- |
| `array<float/int>` swing storage | Array struct `SwingPoint` dan array state MQL5. |
| `line.new` | Object `OBJ_TREND` / line helper MT5. |
| `label.new` | Object label/text MT5. |
| `table.new` | Panel `OBJ_LABEL`. |
| `alert()` | `Alert()` dan optional `SendNotification()`. |
| `alertcondition()` | Signal buffer dan Global Variables. |
| `bar_index` | Index array time/price MT5. |
| `ta.pivothigh/ta.pivotlow` | Raw pivot helper dengan confirmation delay. |

## Catatan Validasi

- Compile terakhir indikator: `0 errors, 0 warnings`.
- Compile terakhir EA: `0 errors, 0 warnings`.
- Perbandingan visual tetap perlu dilakukan di chart MT5 dan TradingView pada symbol/timeframe yang sama karena broker feed dapat menyebabkan selisih candle high/low.
