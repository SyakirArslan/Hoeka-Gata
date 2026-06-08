# HoekaGata Trading System

Repository ini berisi trading system HoekaGata Wave3 untuk TradingView dan MetaTrader 5. Di dalamnya ada indikator TradingView, indikator MT5, dan EA MT5 yang dapat mengeksekusi signal dari indikator MT5.

## Komponen

| Komponen | Path | Dokumentasi |
| --- | --- | --- |
| Indikator TradingView | `Source/HoekaGata_Wave3Pro.pine` | `Docs/TradingView.md` |
| Indikator MT5 | `Main/MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5` | `Docs/Indicator_MT5.md` |
| EA MT5 | `Main/MQL5/Experts/HokaGATA/HoekaGataAlgo.mq5` | `Docs/EA_MT5.md` |
| Mapping logic | `ConversionNotes/HokaGATA_MT5_mapping.md` | Catatan kesetaraan Pine, indikator MT5, dan EA |

## Alur Sistem

1. Indikator TradingView dipakai untuk analisis visual dan validasi logic HoekaGata Wave3.
2. Indikator MT5 menerapkan rule yang sama untuk menghasilkan signal BUY/SELL, SL, TP, dan Extend TP.
3. EA MT5 membaca buffer signal dari indikator MT5.
4. EA mengeksekusi order berdasarkan signal indikator, filter risk, spread, time window, dan pengaturan panel EA.

Ringkasnya:

```text
TradingView indicator -> referensi visual dan rule
MT5 indicator         -> signal engine di MetaTrader 5
MT5 EA                -> eksekusi trade dari signal indikator MT5
```

## Struktur Folder

```text
Docs/
```

Dokumentasi pemakaian TradingView, indikator MT5, dan EA MT5.

```text
Source/
```

Source Pine Script indikator TradingView.

```text
Main/MQL5/Indicators/HokaGATA/
```

Source, include, dan hasil compile indikator MT5.

```text
Main/MQL5/Experts/HokaGATA/
```

Source, include, dan hasil compile EA MT5.

```text
ConversionNotes/
```

Catatan mapping logic dari Pine Script ke MQL5.

## Alur Install ke MT5

1. Copy isi folder `Main/MQL5/Indicators/HokaGATA/` ke:

```text
MQL5/Indicators/HokaGATA/
```

2. Copy isi folder `Main/MQL5/Experts/HokaGATA/` ke:

```text
MQL5/Experts/HokaGATA/
```

3. Compile indikator:

```text
MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5
```

4. Compile EA:

```text
MQL5/Experts/HokaGATA/HoekaGataAlgo.mq5
```

5. Restart MT5 atau refresh Navigator jika file belum muncul.

## Cara Pakai

1. Pasang `HoekaGataIndicator` ke chart MT5.
2. Pastikan indikator menghasilkan signal BUY/SELL dan buffer SL/TP.
3. Pasang `HoekaGataAlgo` EA pada symbol dan timeframe yang sama.
4. Atur risk, spread filter, time filter, arah trading, magic number, dan opsi TP.
5. Aktifkan Algo dari panel EA hanya setelah konfigurasi sesuai.

## Catatan Penting

- EA membaca indikator melalui `iCustom(_Symbol, _Period, "HokaGATA\\HoekaGataIndicator")`.
- Nama folder dan file indikator MT5 harus tetap sama agar EA bisa membaca signal.
- EA dan indikator harus berjalan pada symbol/timeframe yang sama.
- Di Strategy Tester, EA membuat instance indikator sendiri dan memakai default input indikator hasil compile.
- Jika input default indikator berubah, compile ulang indikator sebelum test EA.
- File `.ex5` tersedia untuk install/tester MT5, tetapi source `.mq5` dan `.mqh` tetap menjadi acuan utama.
- Push notification MT5 hanya bekerja jika terminal sudah dikonfigurasi dan `InpEnablePushNotify = true`.
