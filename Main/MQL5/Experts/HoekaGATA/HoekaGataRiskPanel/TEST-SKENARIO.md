# Skenario Uji — Verifikasi Engine HGRP vs Position Sizer

Tujuan: membuktikan bahwa lot & risiko hasil `HoekaGataRiskPanel` **identik**
dengan Position Sizer asli sebelum UI (fase 3) dipasang.

Cara pakai: pasang **kedua** panel di chart yang sama (akun **demo**), isi angka
yang sama, bandingkan kolom `HGRP` vs `PS`. Kolom "Toleransi" adalah batas
selisih yang masih dianggap benar.

> Catatan: `_Point` berbeda per simbol. XAUUSD broker retail biasanya
> `Point=0.01`, EURUSD `Point=0.00001`. Ini justru yang menguji bug SL-dalam-poin.

---

## Kelompok A — XAUUSD, risiko persen, tanpa komisi

Basis: saldo **$10,000**, `Risk = 1%` → `RiskMoney = $100.00`

| # | SL (poin) | Entry | SL price | UnitCost | Cost/lot | Lot diharapkan | Toleransi |
|---|---|---|---|---|---|---|---|
| A1 | 100 | 2000.00 | 1999.00 | 1.0 | 1.00 | **100.00** | ±0.01 |
| A2 | 250 | 2000.00 | 1997.50 | 1.0 | 2.50 | **40.00** | ±0.01 |
| A3 | 10 | 2000.00 | 1999.90 | 1.0 | 0.10 | **1000.00** | ±0.01 |

`Cost/lot = SL_points × UnitCost / TickSize` dengan `TickSize = 0.01`
→ `100 × 1.0 / 0.01 = 10000`? Tidak — lihat catatan di bawah.

**PENTING — cara membaca tabel ini.** Untuk XAUUSD, `TickSize = 0.01` dan
`UnitCost` (tick value) biasanya **$1 per 0.01** untuk 1 lot. Maka:

```
biaya_per_lot = SL_points × UnitCost / TickSize
              = 100 × 1.0 / 0.01 = 10,000
```

Itu tidak masuk akal untuk 100 poin, jadi angka `UnitCost` di tabel harus
dibaca sebagai **tick value per tick**, yaitu `$1.00`.

**Karena itu: JANGAN memakai tabel ini sebagai patokan angka.**
Tabel ini hanya daftar *kasus yang harus diuji*. Angka pembanding yang sah
adalah **keluaran Position Sizer asli di akun Anda**, bukan hitungan saya.

Ganti kolom "Lot diharapkan" dengan hasil PS, lalu bandingkan.

---

## Kelompok B — kasus batas (yang paling sering salah)

| # | Kasus | Yang harus terjadi | Kenapa penting |
|---|---|---|---|
| B1 | Risiko sangat kecil (SL sangat lebar) | lot = `MinLot` atau **0** | membedakan E2 (→0) vs E3 (→MinLot) |
| B2 | SL sangat ketat → lot > `MaxLot` | di-clamp ke `MaxLot` | uji `SurpassBrokerMaxPositionSize` |
| B3 | `LotStep = 0.1` | lot kelipatan 0.1 | uji floor step |
| B4 | `LotStep = 0.01` | lot kelipatan 0.01 | uji `LotStepDigits` |
| B5 | SL = 0 | **tidak ada trade** | PS return lebih awal |
| B6 | Entry = SL | **tidak ada trade** | arah tidak bisa ditentukan |

---

## Kelompok C — komisi

| # | Kasus | Rumus |
|---|---|---|
| C1 | Komisi tetap `$7/lot` | `cost = SL×UC/TS + 2×7` |
| C2 | Komisi `%` dari nilai kontrak | `commission = ContractSize × Ask × pct/100` |
| C3 | AutoCommission (`BTN_AUTOCOMM` = A) | **sudah di-clone** — harus **SAMA** dengan PS dengan Auto aktif |

C3 dulu dicatat sebagai perbedaan yang diketahui. Sejak `HGRP_CalculateAutoCommission`
(`CLONE-SRC: Position Sizer.mqh:9699`) diport penuh, Auto **harus** cocok dengan PS:

- komisi satu sisi per lot dari `SymbolInfoCommissions()`, tier dipilih menurut
  volume acuan (= lot hasil hitung);
- komisi `%-profit` hanya masuk sisi reward (ditandai `CommissionProfitOnly`);
- reward memakai `CommissionReward`, risiko memakai nilai kembalian (sisi risiko);
- bila aturan gagal dibaca, panel **menulis satu peringatan** ke log lalu jatuh ke
  isian Commission manual — ini satu-satunya kasus C3 boleh berbeda.

---

## Kelompok D — mode risiko terbalik

| # | Kasus | Harapan |
|---|---|---|
| D1 | `RiskFromPositionSize = true`, lot 1.00 | EA menampilkan risiko uang dari lot itu, bukan sebaliknya |
| D2 | mode uang (`$50`), bukan persen | lot dihitung dari `$50` |

---

## Kelompok E — mata uang akun = base currency

| # | Kasus | Harapan |
|---|---|---|
| E1 | Akun USD, simbol USDxxx | berlaku koreksi kurs PS:7945 |
| E2 | Akun EUR, simbol EURUSD | idem |

Jika tidak punya akun seperti ini, tulis "N/A" — jangan dipaksakan.

---

## Lembar hasil (isi manual)

| # | Symbol | Balance | Risk% | SL | HGRP lot | PS lot | Selisih | Lulus? |
|---|---|---|---|---|---|---|---|---|
| A1 | | | | | | | | |
| A2 | | | | | | | | |
| A3 | | | | | | | | |
| B1 | | | | | | | | |
| B2 | | | | | | | | |
| B3 | | | | | | | | |
| B4 | | | | | | | | |
| B5 | | | | | | | | |
| B6 | | | | | | | | |
| C1 | | | | | | | | |
| C2 | | | | | | | | |
| D1 | | | | | | | | |
| D2 | | | | | | | | |

**Aturan lulus:** selisih lot harus `0.00` untuk **semua** kasus, termasuk C3
(auto commission) selama aturan komisi broker berhasil dibaca. Selisih > 0 pada
`LotStep` terkecil berarti ada bug pembulatan — laporkan, jangan diabaikan.
