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
| `Display Mode` | `Latest only` atau `History`. |
| `Show Wave 3` | Mengaktifkan signal Wave 3. |
| `Show Wave Lines` | Menampilkan garis wave. |
| `Show Fibo Lines` | Menampilkan fibonacci. |
| `Show Trendline 0-2 and 1-3` | Menampilkan trendline validasi. |
| `Line Width` | Ketebalan garis drawing. |
| `Label Size` | Ukuran label chart. |
| `Enable Wave 3 Formed Alerts` | Mengaktifkan alert umum Wave 3. |
| `Enable BUY Alerts` | Mengaktifkan alert BUY. |
| `Enable SELL Alerts` | Mengaktifkan alert SELL. |
| `Use Parallel Slope Rule` | Validasi kemiripan slope 0-2 dan 1-3. |
| `Parallel Slope Tolerance` | Toleransi slope parallel. |
| `Wave 2 Fibo Tolerance` | Toleransi area fib Wave 2. |
| `Min Bars Between Entry` | Jarak minimal antar signal entry. |
| `Max Drawing Objects` | Batas jumlah object chart. |
| `Show Probability Panel` | Menampilkan panel statistik. |

## Level Fibo

| Level | Fungsi |
| --- | --- |
| `0.500` dan `0.618` | Zona validasi Wave 2. |
| `1.618` | Area entry Wave 3. |
| `-0.270` | Area SL. |
| `0.618` | TP Wave 4 di TradingView. |
| `0.786` | Extend TP Wave 4. |

## Alert

Script menyediakan:

- `alert()` dinamis berisi side, entry, SL, TP, ticker, dan timeframe.
- `alertcondition()` untuk Wave 3 umum.
- `alertcondition()` untuk Wave 3 BUY.
- `alertcondition()` untuk Wave 3 SELL.

Untuk alert yang membawa harga entry/SL/TP, gunakan opsi TradingView `Any alert() function call`.

## Hubungan dengan MT5

Source ini adalah referensi logic. Versi MT5 mengikuti rule utama yang sama, tetapi object TradingView seperti `table`, `label`, dan `line` dikonversi menjadi object chart MT5. Buffer signal dan Global Variables ditambahkan di MT5 agar EA bisa membaca signal otomatis.
