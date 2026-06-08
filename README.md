# HoekaGata MT5 Conversion Workspace

Repository ini berisi source TradingView Pine Script, hasil konversi indikator MT5, dan EA MT5 untuk auto trading berbasis signal HoekaGata Wave3.

## Isi Utama

| Bagian | File utama | Dokumentasi |
| --- | --- | --- |
| TradingView | `Source/HoekaGata_Wave3Pro.pine` | `Docs/TradingView.md` |
| Indikator MT5 | `Main/MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5` | `Docs/Indicator_MT5.md` |
| EA MT5 | `Main/MQL5/Experts/HokaGATA/HoekaGataAlgo.mq5` | `Docs/EA_MT5.md` |
| Catatan konversi | `ConversionNotes/HokaGATA_MT5_mapping.md` | Rule mapping Pine ke MQL5 |

## Struktur Folder

```text
ConversionNotes/
  Catatan mapping logic dari Pine Script ke MQL5.

Docs/
  Dokumentasi pemakaian EA, indikator MT5, dan TradingView.

Main/MQL5/Experts/HokaGATA/
  Source dan hasil compile EA MT5.

Main/MQL5/Experts/HokaGATA/Includes/
  Modul pendukung EA: konfigurasi, trading engine, dan panel.

Main/MQL5/Indicators/HokaGATA/
  Source dan hasil compile indikator MT5.

Main/MQL5/Indicators/HokaGATA/Includes/
  Modul pendukung indikator: config, swing, wave rules, stats, drawing, panel, dan license.

Source/
  Source Pine Script TradingView.
```

## Alur Install ke MT5

1. Buka MetaTrader 5.
2. Pilih `File > Open Data Folder`.
3. Copy folder `Main/MQL5/Indicators/HokaGATA/` ke:
   `MQL5/Indicators/HokaGATA/`
4. Copy folder `Main/MQL5/Experts/HokaGATA/` ke:
   `MQL5/Experts/HokaGATA/`
5. Compile indikator:
   `MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5`
6. Compile EA:
   `MQL5/Experts/HokaGATA/HoekaGataAlgo.mq5`
7. Restart MT5 atau refresh Navigator jika file belum muncul.

## Urutan Pakai

1. Pasang `HoekaGataIndicator` pada chart symbol dan timeframe yang ingin dipakai.
2. Pastikan indikator tampil normal dan menghasilkan signal BUY/SELL.
3. Pasang `HoekaGataAlgo` pada chart yang sama.
4. Aktifkan Algo dari panel EA hanya setelah parameter risk, spread, time filter, dan arah trading sudah sesuai.

## Status Compile Terakhir

Compile terakhir yang dicek:

- `HoekaGataIndicator.mq5`: `0 errors, 0 warnings`
- `HoekaGataAlgo.mq5`: `0 errors, 0 warnings`

File `.ex5` tersedia di folder masing-masing untuk kebutuhan install/tester MT5, tetapi source `.mq5` dan `.mqh` tetap menjadi acuan utama.

## Catatan Penting

- EA membaca indikator dengan `iCustom(_Symbol, _Period, "HokaGATA\\HoekaGataIndicator")`.
- Indikator memakai 5 buffer: BUY, SELL, SL, TP, dan Extend TP.
- EA dan indikator harus berada pada symbol/timeframe yang sama agar signal valid.
- Folder kosong tidak akan ikut tersimpan di Git. Folder muncul di GitHub hanya jika ada file di dalamnya.
- Untuk push notification MT5, konfigurasi MetaTrader harus disiapkan dulu sebelum `InpEnablePushNotify` diaktifkan.
