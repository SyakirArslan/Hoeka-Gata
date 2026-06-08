# HoekaGata Wave3 Pro TradingView

`HoekaGata_Wave3Pro.pine` adalah source Pine Script v5 yang menjadi acuan konversi ke MT5.

## Lokasi File

```text
Source/HoekaGata_Wave3Pro.pine
```

## Fungsi Utama

- Deteksi pivot dan swing high/low.
- Validasi struktur Wave 0-1-2-3.
- Validasi Wave 2 dengan zona fib `0.500` sampai `0.618`.
- Signal BUY/SELL saat Wave 3 terbentuk.
- Drawing wave line, fibonacci line, trendline, label entry, SL, dan TP.
- Panel probability untuk statistik TP/SL virtual.
- Alert TradingView untuk Wave 3, BUY, dan SELL.

## Input TradingView

| Input | Fungsi |
| --- | --- |
| `Pivot Min` | Jarak swing minimal. |
| `Pivot Max` | Jarak swing maksimal. |
| `Wave 2 Fibo Tol` | Toleransi area fib Wave 2. |
| `Entry Barrier` | Mengaktifkan barrier minimum sebelum signal entry valid. |
| `Trigger Fibo` | Level fibo trigger entry, contoh `1.272`, `1.414`, atau `1.618`. |
| `Slope Rule` | Validasi kemiripan slope 0-2 dan 1-3. |
| `Slope Tol` | Toleransi slope parallel. |
| `Entry Gap (Candle)` | Jarak minimal antar signal entry dalam candle. |
| `BUY Alert` | Mengaktifkan alert BUY. |
| `SELL Alert` | Mengaktifkan alert SELL. |
| `Waves Line` | Menampilkan garis wave. |
| `Trendline` | Menampilkan trendline validasi 0-2 dan 1-3. |
| `Fibo Line` | Menampilkan fibonacci. |
| `1.618 Line` | Menampilkan garis/label fibo entry `1.618`. |
| `Mode` | `Latest only` atau `History`. |
| `Max Objects` | Batas jumlah object chart. |
| `Width` | Ketebalan garis drawing. |
| `Label` | Ukuran label chart. |
| `HoekaGata Panel` | Menampilkan panel statistik. |

## Level Fibo

| Level | Fungsi |
| --- | --- |
| `0.500` dan `0.618` | Zona validasi Wave 2. |
| `1.618` | Area extension Wave 3 dan warna untuk trigger barrier. |
| `-0.270` | Area SL. |
| `0.618` | TP Wave 4 di TradingView. |
| `0.786` | Extend TP Wave 4. |

## Alert

Script menyediakan:

- `alert()` dinamis berisi side, entry, SL, TP, ticker, dan timeframe.
- `alertcondition()` untuk Wave 3 umum, BUY, dan SELL mengikuti toggle `BUY Alert` dan `SELL Alert`.
- Tidak ada master alert Wave 3 terpisah; jika BUY/SELL alert aktif, signal Wave 3 arah tersebut ikut aktif.

Untuk alert yang membawa harga entry/SL/TP, gunakan opsi TradingView `Any alert() function call`.

## Hubungan dengan MT5

Source ini adalah referensi logic. Versi MT5 mengikuti rule utama yang sama, tetapi object TradingView seperti `table`, `label`, dan `line` dikonversi menjadi object chart MT5. Buffer signal dan Global Variables ditambahkan di MT5 agar EA bisa membaca signal otomatis.
