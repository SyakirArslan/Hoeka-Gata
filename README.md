# MT5 Conversion Workspace

Folder ini dipakai untuk kebutuhan konversi indikator Pine Script TradingView menjadi indikator MT5 desktop.

## Struktur

- `Source/`
  Tempat salinan file `.pine` yang dikonversi.

- `ConversionNotes/`
  Catatan mapping logic dari Pine ke MQL5, termasuk rule signal, wave, fib zone, alert, dan object drawing.

- `Main/MQL5/Indicators/HokaGATA/`
  Source indikator MT5. File entry point adalah `HokaGATA_Wave3_MT5.mq5`.

- `Main/MQL5/Indicators/HokaGATA/Includes/`
  Modul `.mqh` hasil split supaya indikator lebih mudah dirawat.

- `Main/MQL5/Experts/HokaGATA/`
  Source EA untuk auto trading. File entry point adalah `HokaGATA_AutoTrader.mq5`.

- `Reference/`
  Screenshot TradingView atau referensi visual pembanding.

- `TextResult/`
  Hasil test MT5, catatan perbedaan signal, dan screenshot validasi.

- `BuildExport/`
  File hasil compile/export seperti `.ex5`, paket rilis, atau zip.

- `Backup/`
  Backup manual sebelum perubahan besar.

## Modul MT5

- `HokaGATA_Config.mqh`
  Input, konstanta, buffer, state alert, dan struct data ringan.

- `HokaGATA_Swing.mqh`
  Deteksi pivot dan penyusunan swing high/low.

- `HokaGATA_WaveRules.mqh`
  Rule fibonacci, validasi Wave 2, entry/SL/TP helper, dan parallel slope.

- `HokaGATA_Stats.mqh`
  Tracking trade virtual untuk probability panel.

- `HokaGATA_Drawing.mqh`
  Object drawing chart: wave line, fib line, trendline, label, dan cleanup object.

- `HokaGATA_Panel.mqh`
  Probability panel kanan atas chart.

- `HokaGATA_Core.mqh`
  Loop utama perhitungan HokaGATA dan trigger BUY/SELL.

## EA AutoTrader

- `HokaGATA_AutoTrader.mq5`
  EA membaca buffer indikator dengan `iCustom()`, lalu open posisi jika semua filter valid.

Panel EA menyediakan:

- Algo ON/OFF.
- Risk percent, risk USD, reward USD.
- Min lot dan max lot.
- Trading time ON/OFF dengan format 24 jam `HH:MM`.
- Spread filter ON/OFF.
- Buy Enabled dan Sell Enabled.
- Magic Number.

Rule internal EA:

- Satu posisi aktif per symbol dan magic number.
- Entry memakai signal indikator.
- Lot dihitung dari risk percent dan jarak harga entry ke SL HokaGATA.
- Jam trading memakai server time broker.
- Spread memakai `SYMBOL_SPREAD` dalam points.

## Urutan kerja konversi

1. Copy file `.pine` final ke `Source/`.
2. Buat catatan rule penting di `ConversionNotes/`.
3. Implementasi indikator MT5 di `Main/MQL5/Indicators/HokaGATA/`.
4. Bandingkan hasil MT5 dengan screenshot TradingView di `Reference/`.
5. Simpan hasil compile dan release di `BuildExport/`.

## Urutan compile MT5

1. Copy `Main/MQL5/Indicators/HokaGATA/` ke folder data MT5 `MQL5/Indicators/HokaGATA/`.
2. Copy `Main/MQL5/Experts/HokaGATA/` ke folder data MT5 `MQL5/Experts/HokaGATA/`.
3. Compile indikator `Indicators/HokaGATA/HokaGATA_Wave3_MT5.mq5`.
4. Compile EA `Experts/HokaGATA/HokaGATA_AutoTrader.mq5`.
5. Pasang EA ke chart symbol/timeframe yang sama dengan indikator.
