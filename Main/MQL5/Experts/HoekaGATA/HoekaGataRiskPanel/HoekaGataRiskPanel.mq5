//+------------------------------------------------------------------+
//|                                          HoekaGataRiskPanel.mq5   |
//|   AMIS Risk Panel for HoekaGATA                                   |
//|                                                                   |
//|   Fase 1: engine clone 1:1 dari Position Sizer (EarnForex).       |
//|   Sumber rumus: _reference/Position Sizer.mqh                     |
//|   Setiap fungsi engine ditandai // CLONE-SRC: <baris asal>        |
//|                                                                   |
//|   UI (63 kontrol, 5 tab) menyusul di fase 3 — desain acuan:       |
//|   Main/Docs/amis-sizer-panel.html                                 |
//+------------------------------------------------------------------+
#property copyright "HoekaGATA"
#property link      ""
#property version   "1.00"
#property description "AMIS Risk Panel - position sizing untuk HoekaGATA"
#property description "Engine perhitungan di-clone 1:1 dari Position Sizer."
#property strict

//--- Prefix objek chart. JANGAN pakai PS_ (milik Position Sizer asli).
#define HGRP_PREFIX "HGRP_"

//+------------------------------------------------------------------+
//| Struktur pengaturan — subset dari PS `sets` yang dipakai engine.  |
//| Nama field sengaja mengikuti PS agar audit 1:1 mudah.             |
//+------------------------------------------------------------------+
struct HGRP_Sets
  {
   //--- mode risiko
   bool              UseMoneyInsteadOfPercentage;   // true = risiko dalam uang
   double            Risk;                          // persen
   double            MoneyRisk;                     // mata uang akun
   bool              RiskFromPositionSize;          // hitung risiko dari lot, bukan sebaliknya

   //--- level harga
   double            EntryLevel;
   double            StopLossLevel;
   bool              TPLockedOnSL;
   double            EntryLevelSet;
   int               Direction;                     // POSITION_TYPE_BUY / SELL / -1 (belum diketahui)

   //--- biaya
   double            CommissionPerLot;
   int               CommissionType;                // 0 = currency, 1 = percent
   bool              AutoCommission;
   bool              CommissionProfitOnly;

   //--- batas ukuran
   bool              CalculateUnadjustedPositionSize;
   bool              SurpassBrokerMaxPositionSize;
   bool              CapMaxPositionSizeBasedOnMargin;

   //--- penyesuaian
   bool              SpreadAdjustmentSL;

   //--- take profit
   int               TakeProfitsNumber;
   int               TPShare[20];
   double            TPLevel;
   double            TP2Level;
   double            TPAdditional[20];   // level TP 2..n (indeks 0 = TP2, selaras TPShare[1..])
   double            StopPriceLevel;
   double            AccountBalance;

   //--- trailing (tab Trading)
   int               TrailingStop;
   int               Breakeven;
   int               Slippage;
   long              MagicNumber;
   string            Commentary;
  };

//+------------------------------------------------------------------+
//| Info simbol & akun — dibaca sekali, dipakai engine.               |
//+------------------------------------------------------------------+
struct HGRP_Symbol
  {
   string            Symbol;
   double            TickSize;
   double            Point;
   double            ContractSize;
   double            MinLot;
   double            MaxLot;
   double            LotStep;
   int               LotStepDigits;
   int               CalcMode;
   string            BaseCurrency;
   string            ProfitCurrency;
   string            AccountCurrency;
   int               AccountCurrencyDigits;
  };

//+------------------------------------------------------------------+
//| Hasil perhitungan — inilah yang dibandingkan dengan PS asli.      |
//+------------------------------------------------------------------+
struct HGRP_Result
  {
   double            PositionSize;      // lot akhir (sudah di-brokerize)
   double            RiskMoney;         // risiko aktual untuk lot tsb
   double            BaseRiskMoney;     // tanpa penyesuaian spread
   double            DisplayRisk;       // persen dari saldo
   double            RewardMoney;       // potensi reward untuk lot tsb (total semua TP)
   double            RewardRisk;        // rasio reward/risk (total semua TP)
   double            RewardPerTP[20];   // reward per level TP (indeks 0 = TP1)
   double            RewardRiskPerTP[20]; // RR per level TP
   bool              TPInvalid[20];     // level TP tidak valid (salah sisi / terlalu dekat)
   double            PositionMargin;    // margin posisi (tab Margin)
   double            UsedMargin;        // margin terpakai setelah posisi baru
   double            FreeMargin;        // free margin setelah posisi baru
   double            MaxPositionSizeByMargin;
   double            UnitCostLoss;
   double            UnitCostReward;
   double            Commission;        // per lot, satu sisi (sisi risiko)
   double            CommissionReward;  // per lot, satu sisi (sisi reward, termasuk komisi profit-only)
   bool              CommissionProfitOnly; // ada komponen komisi yang hanya kena saat profit
   int               Direction;         // POSITION_TYPE_BUY / SELL / -1
   bool              Valid;             // false = tidak ada trade
   bool              CappedByMargin;    // lot dipotong OutputMaxPositionSize
   //--- portofolio (tab Risk) — diisi HGRP_CalculatePortfolio()
   double            CurrentRiskMoney;
   double            CurrentRiskPercent;
   double            PotentialRiskMoney;
   double            PotentialRiskPercent;
   int               OpenPositions;
   int               PendingOrders;
  };

//--- state global
HGRP_Sets         g_sets;
HGRP_Symbol       g_sym;
HGRP_Result       g_result;

//--- panel UI fase 3
#include "HGRP_Lines.mqh"
#include "HGRP_Panel.mqh"
HGRP_Panel        g_panel;


//+------------------------------------------------------------------+
//| Baca spesifikasi simbol & akun ke g_sym.                          |
//+------------------------------------------------------------------+
void HGRP_LoadSymbol(const string symbol)
  {
   g_sym.Symbol           = symbol;
   g_sym.TickSize         = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   g_sym.Point            = SymbolInfoDouble(symbol, SYMBOL_POINT);
   g_sym.ContractSize     = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   g_sym.MinLot           = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   g_sym.MaxLot           = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   g_sym.LotStep          = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   g_sym.CalcMode         = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
   g_sym.BaseCurrency     = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   g_sym.ProfitCurrency   = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   g_sym.AccountCurrency  = AccountInfoString(ACCOUNT_CURRENCY);
   g_sym.AccountCurrencyDigits = (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS);

   //--- jumlah desimal LotStep, dipakai Round(..., LotStep_digits)
   g_sym.LotStepDigits = 0;
   if(g_sym.LotStep > 0)
     {
      double step = g_sym.LotStep;
      while(step < 1.0 - 1e-12 && g_sym.LotStepDigits < 8)
        {
         step *= 10.0;
         g_sym.LotStepDigits++;
        }
     }
  }

//+------------------------------------------------------------------+
//| Sisi mana dari harga acuan yang dipakai untuk konversi.           |
//| CLONE-SRC: Position Sizer.mqh enum PROFIT_LOSS (Defines.mqh)      |
//|                                                                   |
//| PENTING: nilai enum HARUS Profit=0, Loss=1 supaya identik dengan  |
//| referensi. Jangan diganti jadi BUY/SELL — Position Sizer memilih  |
//| bid/ask dari sisi profit/loss, bukan dari arah posisi.            |
//+------------------------------------------------------------------+
enum HGRP_PROFIT_LOSS
  {
   HGRP_Profit = 0,   // nilai profit: pakai harga BID
   HGRP_Loss   = 1    // nilai loss  : pakai harga ASK
  };

//+------------------------------------------------------------------+
//| Konversi mata uang.                                               |
//| CLONE-SRC: Position Sizer.mqh:9067 CalculateAdjustment()          |
//| Mengembalikan rasio CCY1 -> CCY2 dalam mata uang akun.            |
//|                                                                   |
//| Tiga jalur wajib (kalau satu hilang, hasilnya diam-diam 1.0 dan   |
//| risiko salah untuk akun non-USD):                                 |
//|   1. pair langsung  CCY1CCY2 -> Profit: bid, Loss: ask            |
//|   2. pair terbalik  CCY2CCY1 -> Profit: 1/ask, Loss: 1/bid        |
//|   3. silang lewat USD bila keduanya bukan USD                     |
//+------------------------------------------------------------------+
double HGRP_CalculateAdjustment(const HGRP_PROFIT_LOSS calc_mode,
                                const string ccy1, const string ccy2,
                                const string symbol,
                                const int depth = 0)
  {
   if(ccy1 == ccy2)
      return 1.0;

   //--- 1) pair langsung: misal EURUSD untuk EUR -> USD
   if(HGRP_SymbolByCurrencies(ccy1, ccy2))
     {
      const double bid = SymbolInfoDouble(ccy1 + ccy2, SYMBOL_BID);
      const double ask = SymbolInfoDouble(ccy1 + ccy2, SYMBOL_ASK);

      if(bid <= 0 || ask <= 0)
         return -1;                               // data belum siap

      return (calc_mode == HGRP_Profit) ? bid : ask;
     }

   //--- 2) pair terbalik: misal USDEUR untuk EUR -> USD
   if(HGRP_SymbolByCurrencies(ccy2, ccy1))
     {
      const double bid = SymbolInfoDouble(ccy2 + ccy1, SYMBOL_BID);
      const double ask = SymbolInfoDouble(ccy2 + ccy1, SYMBOL_ASK);

      if(bid <= 0 || ask <= 0)
         return -1;

      return (calc_mode == HGRP_Profit) ? (1.0 / ask) : (1.0 / bid);
     }

   //--- 3) kurs silang lewat USD (dijaga depth supaya tidak rekursif liar)
   if(ccy1 != "USD" && ccy2 != "USD" && depth < 2)
     {
      const double a = HGRP_CalculateAdjustment(calc_mode, ccy1, "USD", symbol, depth + 1);
      const double b = HGRP_CalculateAdjustment(calc_mode, "USD", ccy2, symbol, depth + 1);

      if(a > 0 && b > 0)
         return a * b;
     }

   //--- tidak bisa dikonversi: 1.0 (sama seperti referensi) + peringatan
   //    sekali per kombinasi agar log tester tidak dibanjiri.
   HGRP_WarnCannotConvert(ccy1, ccy2, symbol);
   return 1.0;
  }

//+------------------------------------------------------------------+
//| Cek keberadaan simbol CCY1CCY2 (PS GetSymbolByCurrencies, :9137). |
//| Tidak memakai SymbolSelect() kecuali perlu: mengubah Market Watch |
//| dari dalam EA memperlambat tick berikutnya.                       |
//+------------------------------------------------------------------+
bool HGRP_SymbolByCurrencies(const string base_ccy, const string profit_ccy)
  {
   const string name = base_ccy + profit_ccy;

   bool is_custom = false;

   if(!SymbolExist(name, is_custom))
      return false;

   if(!(bool)SymbolInfoInteger(name, SYMBOL_SELECT))
      SymbolSelect(name, true);

   return true;
  }

//+------------------------------------------------------------------+
//| Peringatan konversi, dicetak sekali per kombinasi.                |
//+------------------------------------------------------------------+
string g_warned_convert[];

void HGRP_WarnCannotConvert(const string ccy1, const string ccy2, const string symbol)
  {
   const string combo = ccy1 + "/" + ccy2 + "@" + symbol;
   const int    n     = ArraySize(g_warned_convert);

   for(int i = 0; i < n; i++)
      if(g_warned_convert[i] == combo)
         return;

   ArrayResize(g_warned_convert, n + 1);
   g_warned_convert[n] = combo;

   PrintFormat("%s: tidak bisa konversi %s -> %s untuk %s; dipakai 1.0",
               HGRP_PREFIX, ccy1, ccy2, symbol);
  }

//+------------------------------------------------------------------+
//| E1 — CalculateUnitCost                                            |
//| CLONE-SRC: Position Sizer.mqh:9505                                |
//| Nilai satu tick (TickSize) dalam mata uang akun, dipisah sisi     |
//| loss dan sisi profit karena broker bisa memberi keduanya berbeda. |
//+------------------------------------------------------------------+
void HGRP_CalculateUnitCost(double &unit_cost_loss, double &unit_cost_profit)
  {
   const int mode = g_sym.CalcMode;

   //--- CLONE-SRC: :9510 — daftar mode yang TIDAK memakai tick value.
   //    Semua di luar daftar ini memakai tick value, jadi FUTURES ikut
   //    cabang tick value. Port sebelumnya hanya memeriksa FOREX,
   //    sehingga FUTURES memakai TickSize*ContractSize (salah).
   const bool uses_tick_size = (mode != SYMBOL_CALC_MODE_FOREX) &&
                               (mode != SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE) &&
                               (mode != SYMBOL_CALC_MODE_FUTURES) &&
                               (mode != SYMBOL_CALC_MODE_EXCH_FUTURES) &&
                               (mode != SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS);

   //--- Non tick-value. (PS 9508-9521)
   if(uses_tick_size)
     {
      unit_cost_loss   = g_sym.TickSize * g_sym.ContractSize;
      unit_cost_profit = unit_cost_loss;

      //--- Profit currency berbeda dari mata uang akun -> konversi.
      //    Loss dan Profit dikonversi TERPISAH (ask vs bid), persis
      //    seperti referensi; memakai satu rasio untuk keduanya membuat
      //    sisi loss meleset sebesar spread.
      if(g_sym.ProfitCurrency != g_sym.AccountCurrency)
        {
         double ccc = HGRP_CalculateAdjustment(HGRP_Loss, g_sym.ProfitCurrency,
                                               g_sym.AccountCurrency, g_sym.Symbol);
         if(ccc > 0)
            unit_cost_loss *= ccc;

         ccc = HGRP_CalculateAdjustment(HGRP_Profit, g_sym.ProfitCurrency,
                                        g_sym.AccountCurrency, g_sym.Symbol);
         if(ccc > 0)
            unit_cost_profit *= ccc;
        }

      return;
     }

   //--- Forex/futures: tick value sudah merupakan nilai 1 unit. (PS 9522-9528)
   unit_cost_loss   = SymbolInfoDouble(g_sym.Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   unit_cost_profit = SymbolInfoDouble(g_sym.Symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);

   if(unit_cost_loss == 0 || unit_cost_profit == 0)
      PrintFormat("%s: peringatan — tick value loss/profit %s = 0, "
                  "risiko tidak bisa dihitung (cek spesifikasi simbol).",
                  HGRP_PREFIX, g_sym.Symbol);
  }

//+------------------------------------------------------------------+
//| Nilai satu kontrak (1 lot) dalam mata uang akun — dipakai untuk   |
//| komisi persen.                                                    |
//| CLONE-SRC: Position Sizer.mqh:9649 CalculateContractValue()       |
//|                                                                   |
//| Port lama memakai ContractSize * ASK untuk semua simbol, sehingga |
//| akun yang mata uangnya = base currency (mis. akun USD trading     |
//| USD/CAD) mendapat nilai kontrak yang salah.                       |
//+------------------------------------------------------------------+
double HGRP_CalculateContractValue(void)
  {
   const double contract_size = g_sym.ContractSize;
   const double ask           = SymbolInfoDouble(g_sym.Symbol, SYMBOL_ASK);
   double       value         = 0.0;

   const bool is_forex = (g_sym.CalcMode == SYMBOL_CALC_MODE_FOREX ||
                          g_sym.CalcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);

   if(is_forex)
     {
      if(g_sym.BaseCurrency == g_sym.AccountCurrency)
         value = contract_size;                    // PS :9656 USD/CAD di akun USD
      else
         if(g_sym.ProfitCurrency == g_sym.AccountCurrency)
            value = contract_size * ask;           // PS :9661 EUR/USD di akun USD
         else
           {
            //--- butuh konversi, mis. GBP/JPY di akun USD (PS :9666)
            const double ccc = HGRP_CalculateAdjustment(HGRP_Loss, g_sym.BaseCurrency,
                                                        g_sym.AccountCurrency, g_sym.Symbol);
            value = contract_size * ((ccc > 0) ? ccc : 1.0);
           }
     }
   else
     {
      //--- non-forex: harga kontrak dianggap dalam profit currency (PS :9677)
      if(g_sym.ProfitCurrency == g_sym.AccountCurrency)
         value = contract_size * ask;
      else
        {
         const double ccc = HGRP_CalculateAdjustment(HGRP_Loss, g_sym.BaseCurrency,
                                                     g_sym.AccountCurrency, g_sym.Symbol);
         value = contract_size * ask * ((ccc > 0) ? ccc : 1.0);
        }
     }

   return value;
  }

//+------------------------------------------------------------------+
//| E2 — BrokerizePositionSize                                        |
//| CLONE-SRC: Position Sizer.mqh:8158                                |
//| Bedanya dengan E3: di sini lot di bawah minimum dibulatkan ke 0   |
//| (trade dibatalkan), bukan dinaikkan ke MinLot.                    |
//+------------------------------------------------------------------+
double HGRP_BrokerizePositionSize(const double position_size)
  {
   if(g_sets.CalculateUnadjustedPositionSize)
      return position_size;                       // PS 8160

   if(position_size < g_sym.MinLot)
      return 0;                                   // PS 8162-8165

   if((position_size > g_sym.MaxLot) && (!g_sets.SurpassBrokerMaxPositionSize))
      return g_sym.MaxLot;                        // PS 8166-8169

   double steps = 0;
   if(g_sym.LotStep != 0)
      steps = position_size / g_sym.LotStep;      // PS 8171

   //--- toleransi floating point, PS memakai 1e-8 (baris 8172)
   if(MathAbs(MathRound(steps) - steps) < 1e-8)
      steps = MathRound(steps);

   if(MathFloor(steps) < steps)
      return MathFloor(steps) * g_sym.LotStep;    // PS 8173

   return position_size;
  }

//+------------------------------------------------------------------+
//| E3 — AdjustPositionSizeByMinMaxStep                               |
//| CLONE-SRC: Position Sizer.mqh:9911                                |
//| Di sini lot di bawah minimum DINAIKKAN ke MinLot (beda dgn E2).   |
//+------------------------------------------------------------------+
double HGRP_AdjustPositionSizeByMinMaxStep(double ps)
  {
   if(ps < g_sym.MinLot)
      ps = g_sym.MinLot;                          // PS 9913
   else
      if((ps > g_sym.MaxLot) && (!g_sets.SurpassBrokerMaxPositionSize))
         ps = g_sym.MaxLot;                       // PS 9914

   double steps = 0;
   if(g_sym.LotStep != 0)
      steps = ps / g_sym.LotStep;                 // PS 9916

   if(MathAbs(MathRound(steps) - steps) < 1e-8)
      steps = MathRound(steps);                   // PS 9917

   if(MathFloor(steps) < steps)
      ps = MathFloor(steps) * g_sym.LotStep;      // PS 9918

   return ps;
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Komisi otomatis dari aturan broker.                               |
//| CLONE-SRC: Position Sizer.mqh:9699 CalculateAutoCommission()      |
//|                                                                   |
//| Mengembalikan komisi SATU SISI per lot untuk skenario kalah, dan  |
//| mengisi CommissionReward (skenario menang, termasuk komponen      |
//| profit-only) serta CommissionProfitOnly lewat g_result.           |
//|                                                                   |
//| Nilai balik:                                                      |
//|   <0 -> aturan tidak bisa diambil, pemanggil pakai isian manual   |
//|    0 -> simbol memang tidak punya aturan komisi                   |
//|   >0 -> komisi satu sisi per lot, dalam mata uang akun           |
//|                                                                   |
//| Volume acuan pemilihan tier = lot hasil hitung terakhir. Kalau    |
//| belum ada (panel baru dibuka), dipakai MinLot lalu 1. Karena itu  |
//| komisi bisa berubah ketika lot berubah — itu perilaku referensi,  |
//| bukan bug.                                                        |
//+------------------------------------------------------------------+
double HGRP_CalculateAutoCommission()
  {
   MqlCommission commissions[];
   const int total = SymbolInfoCommissions(g_sym.Symbol, commissions);

   if(total < 0)
     {
      //--- peringatan hanya sekali per simbol agar log tidak banjir
      static string warned_symbol = "";

      if(warned_symbol != g_sym.Symbol)
        {
         PrintFormat("%s: SymbolInfoCommissions gagal (%s) - memakai isian Commission.",
                     HGRP_PREFIX, HGRP_ErrorText(GetLastError()));
         warned_symbol = g_sym.Symbol;
        }

      return -1.0;
     }

   g_result.CommissionReward     = 0.0;
   g_result.CommissionProfitOnly = false;

   if(total == 0)
      return 0.0;                                  // PS 9712-9717

   //--- volume acuan (PS 9719-9721)
   double ref_volume = g_result.PositionSize;

   if(ref_volume <= 0)
      ref_volume = g_sym.MinLot;
   if(ref_volume <= 0)
      ref_volume = 1.0;

   //--- harga & nilai deal untuk tier berbasis value (PS 9723-9725)
   double price = SymbolInfoDouble(g_sym.Symbol, SYMBOL_ASK);

   if(g_sets.EntryLevel > 0)
      price = g_sets.EntryLevel;

   const double deal_value = ref_volume * g_sym.ContractSize * price;

   //--- unit cost untuk tier berbasis poin & persen-profit (PS 9727-9729)
   double uc_temp_loss = 0.0, uc_temp_reward = 0.0;

   HGRP_CalculateUnitCost(uc_temp_loss, uc_temp_reward);

   const double symbol_point = g_sym.Point;

   //--- arah trade: pakai g_sets.Direction bila sudah dihitung, kalau
   //    belum bandingkan entry dengan Ask seperti PS (sets.TradeDirection)
   const bool entry_is_buy = (g_sets.Direction >= 0)
                             ? (g_sets.Direction == POSITION_TYPE_BUY)
                             : (g_sets.EntryLevel >= SymbolInfoDouble(g_sym.Symbol, SYMBOL_ASK));

   //--- total per-deal: sisi kalah (risk) dan sisi menang (reward)
   double entry_risk = 0.0, exit_risk = 0.0;
   double entry_reward = 0.0, exit_reward = 0.0;
   bool   profit_only_found = false;

   for(int i = 0; i < total; i++)
     {
      const int tiers_total = ArraySize(commissions[i].tiers);

      if(tiers_total == 0)
         continue;                                 // PS 9738

      //--- pilih tier sesuai mode_range (PS 9740-9752).
      //    Range turnover/profit tidak bisa diketahui di muka -> tier pertama.
      double range_indicator = 0.0;

      if(commissions[i].mode_range == SYMBOL_COMMISSION_RANGE_VOLUME)
         range_indicator = ref_volume;
      else
         if(commissions[i].mode_range == SYMBOL_COMMISSION_RANGE_VALUE)
            range_indicator = deal_value;

      int t = 0;

      for(int j = 0; j < tiers_total; j++)
        {
         const bool in_range = (range_indicator >= commissions[i].tiers[j].range_from) &&
                               ((range_indicator < commissions[i].tiers[j].range_to) ||
                                (commissions[i].tiers[j].range_to == 0));   // 0 = tanpa batas atas

         if(in_range)
           {
            t = j;
            break;
           }
        }

      if(commissions[i].tiers[t].mode == SYMBOL_COMMISSION_DISABLED)
         continue;                                 // PS 9754

      //--- mata uang nilai komisi -> konversi ke mata uang akun (PS 9756-9767)
      string ccy = g_sym.AccountCurrency;

      if(commissions[i].tiers[t].mode == SYMBOL_COMMISSION_MONEY_SYMBOL_BASE)
         ccy = g_sym.BaseCurrency;
      else
         if(commissions[i].tiers[t].mode == SYMBOL_COMMISSION_MONEY_SYMBOL_PROFIT)
            ccy = g_sym.ProfitCurrency;
         else
            if(commissions[i].tiers[t].mode == SYMBOL_COMMISSION_MONEY_SYMBOL_MARGIN)
               ccy = SymbolInfoString(g_sym.Symbol, SYMBOL_CURRENCY_MARGIN);
            else
               if(commissions[i].tiers[t].mode == SYMBOL_COMMISSION_MONEY_SPECIFIED)
                 {
                  if(commissions[i].tiers[t].currency != "")
                     ccy = commissions[i].tiers[t].currency;
                  else
                     if(commissions[i].currency != "")
                        ccy = commissions[i].currency;
                 }

      double conversion = 1.0;

      if(ccy != g_sym.AccountCurrency)
        {
         const double adj = HGRP_CalculateAdjustment(HGRP_Loss, ccy,
                                                     g_sym.AccountCurrency, g_sym.Symbol);

         if(adj > 0)
            conversion = adj;
        }


   //--- total per-deal: sisi kalah (risk) dan sisi menang (reward)
   double entry_risk = 0.0, exit_risk = 0.0;
   double entry_reward = 0.0, exit_reward = 0.0;
   bool   profit_only_found = false;


//| Teks pesan galat MQL5 untuk log.                                  |
//+------------------------------------------------------------------+
      //--- komisi per-deal untuk aturan ini (PS 9769-9794)
      double deal_commission  = 0.0;
      bool   tier_profit_only = false;   // %-profit otomatis hanya kena saat profit

      switch(commissions[i].tiers[t].mode)
        {
         case SYMBOL_COMMISSION_MONEY_DEPOSIT:
         case SYMBOL_COMMISSION_MONEY_SYMBOL_BASE:
         case SYMBOL_COMMISSION_MONEY_SYMBOL_PROFIT:
         case SYMBOL_COMMISSION_MONEY_SYMBOL_MARGIN:
         case SYMBOL_COMMISSION_MONEY_SPECIFIED:
            if(commissions[i].tiers[t].volume_type == SYMBOL_COMMISSION_VOLUME_TYPE_TRADE)
               deal_commission = commissions[i].tiers[t].value * conversion;              // nominal per deal
            else
               deal_commission = commissions[i].tiers[t].value * conversion * ref_volume; // proporsional lot
            break;

         case SYMBOL_COMMISSION_PIPS:
            if(g_sym.TickSize > 0)
               deal_commission = commissions[i].tiers[t].value * uc_temp_loss / g_sym.TickSize *
                                 symbol_point * ref_volume;
            break;

         case SYMBOL_COMMISSION_PERCENT:
            deal_commission = HGRP_CalculateContractValue() * ref_volume *
                              commissions[i].tiers[t].value / 100.0;
            break;

         case SYMBOL_COMMISSION_PERCENT_PROFIT:
            //--- % dari profit: hanya kena saat menang, diperkirakan dari TP aktif
            tier_profit_only = true;

            if(g_sets.TPLevel > 0 && g_sym.TickSize > 0)
               deal_commission = commissions[i].tiers[t].value / 100.0 *
                                 MathAbs(g_sets.TPLevel - price) * uc_temp_reward /
                                 g_sym.TickSize * ref_volume;
            break;

         default:
            break;
        }

      if(deal_commission == 0.0)
         continue;

      //--- clamp min/max (0 = batas tidak diset) — PS 9797-9799
      if(commissions[i].tiers[t].min_value > 0 &&
         deal_commission < commissions[i].tiers[t].min_value * conversion)
         deal_commission = commissions[i].tiers[t].min_value * conversion;

      if(commissions[i].tiers[t].max_value > 0 &&
         deal_commission > commissions[i].tiers[t].max_value * conversion)
         deal_commission = commissions[i].tiers[t].max_value * conversion;

      //--- aturan ini masuk skenario yang mana (PS 9801-9804)
      const bool include_in_risk   = (commissions[i].mode_profit != SYMBOL_COMMISSION_PROFIT_PROFIT) &&
                                     !tier_profit_only;
      const bool include_in_reward = (commissions[i].mode_profit != SYMBOL_COMMISSION_PROFIT_LOSS);

      if(include_in_reward &&
         (commissions[i].mode_profit == SYMBOL_COMMISSION_PROFIT_PROFIT || tier_profit_only))
         profit_only_found = true;

      //--- filter arah (PS 9807-9808)
      const bool applies_to_buy  = (commissions[i].mode_direction == SYMBOL_COMMISSION_DIRECTION_BOTH) ||
                                   (commissions[i].mode_direction == SYMBOL_COMMISSION_DIRECTION_BUY);
      const bool applies_to_sell = (commissions[i].mode_direction == SYMBOL_COMMISSION_DIRECTION_BOTH) ||
                                   (commissions[i].mode_direction == SYMBOL_COMMISSION_DIRECTION_SELL);

      if(tier_profit_only)
        {
         //--- %-profit direalisasi sekali saat posisi ditutup -> hitung di deal exit
         if((entry_is_buy && applies_to_sell) || (!entry_is_buy && applies_to_buy))
            exit_reward += deal_commission;
         continue;
        }

      //--- deal entry (PS 9814-9821)
      if(commissions[i].mode_entry == SYMBOL_COMMISSION_ENTRY_IN ||
         commissions[i].mode_entry == SYMBOL_COMMISSION_ENTRY_INOUT)
        {
         if((entry_is_buy && applies_to_buy) || (!entry_is_buy && applies_to_sell))
           {
            if(include_in_risk)
               entry_risk += deal_commission;
            if(include_in_reward)
               entry_reward += deal_commission;
           }
        }

      //--- deal exit: arahnya berlawanan dengan entry (PS 9822-9829)
      if(commissions[i].mode_entry == SYMBOL_COMMISSION_ENTRY_OUT ||
         commissions[i].mode_entry == SYMBOL_COMMISSION_ENTRY_INOUT)
        {
         if((entry_is_buy && applies_to_sell) || (!entry_is_buy && applies_to_buy))
           {
            if(include_in_risk)
               exit_risk += deal_commission;
            if(include_in_reward)
               exit_reward += deal_commission;
           }
        }
     }

   //--- PS 9832-9837: PS memakai komisi satu sisi per lot
   g_result.CommissionReward = (entry_reward + exit_reward) / 2.0 / ref_volume;

   if(g_result.CommissionReward > 0 &&
      NormalizeDouble(g_result.CommissionReward, g_sym.AccountCurrencyDigits) == 0)
      g_result.CommissionReward = MathPow(0.1, g_sym.AccountCurrencyDigits);  // sub-sen tetap 1 sen

   g_result.CommissionProfitOnly = profit_only_found;

   return (entry_risk + exit_risk) / 2.0 / ref_volume;
  }

//+------------------------------------------------------------------+
//| Teks pesan galat MQL5 untuk log.                                  |
//+------------------------------------------------------------------+
string HGRP_ErrorText(const int code)
  {
   switch(code)
     {
      case 0:    return "no error";
      case 4001: return "ERR_INTERNAL_ERROR";
      case 4003: return "ERR_INVALID_PARAMETER";
      case 4014: return "ERR_FUNCTION_NOT_ALLOWED";
      case 4106: return "ERR_UNKNOWN_SYMBOL";
      default:   return "error " + IntegerToString(code);
     }
  }

//+------------------------------------------------------------------+
//| E4 — CalculateCommission                                          |
//| CLONE-SRC: Position Sizer.mqh:9839 CalculateCommission()          |
//| Mengembalikan komisi satu sisi per lot, dalam mata uang akun.     |
//| Sekaligus mengisi g_result.CommissionReward dan                   |
//| g_result.CommissionProfitOnly agar sisi reward memakai angka      |
//| yang benar (komisi profit-only tidak boleh masuk sisi risiko).    |
//+------------------------------------------------------------------+
double HGRP_CalculateCommission()
  {
   const int acc_dig = g_sym.AccountCurrencyDigits;

   //--- jalur otomatis: baca aturan komisi broker (PS 9841-9852)
   if(g_sets.AutoCommission)
     {
      const double auto_commission = HGRP_CalculateAutoCommission();

      if(auto_commission >= 0)
        {
         double one_side = auto_commission;

         if(one_side > 0 && NormalizeDouble(one_side, acc_dig) == 0)
            one_side = MathPow(0.1, acc_dig);   // sub-sen tetap ditagih 1 sen

         //--- komisi otomatis SELALU per-lot mata uang akun (PS 9847)
         g_sets.CommissionType = 0;

         //--- tampilkan nilai penuh, termasuk bagian profit-only (PS 9848)
         g_sets.CommissionPerLot = g_result.CommissionProfitOnly ? g_result.CommissionReward
                                                                 : one_side;

         return one_side;
        }

      //--- auto_commission < 0: aturan gagal diambil, jatuh ke isian manual
     }

   double commission = g_sets.CommissionPerLot;   // PS 9853

   //--- komisi dalam persen dari nilai kontrak (PS 9854-9858).
   //    Nilai kontrak memakai CalculateContractValue(), bukan
   //    ContractSize*ASK mentah — lihat PS :9651.
   if(g_sets.CommissionType == 1)
      commission = HGRP_CalculateContractValue() * g_sets.CommissionPerLot / 100.0;

   //--- komisi manual berlaku untuk kedua sisi (PS 9859-9860)
   g_result.CommissionReward     = commission;
   g_result.CommissionProfitOnly = false;

   return commission;                             // PS 9861
  }

//+------------------------------------------------------------------+
//| E6 — CalculateRiskAndPositionSize                                 |
//| CLONE-SRC: Position Sizer.mqh:7909                                |
//| Inti engine: dari risiko + jarak SL menghasilkan lot.             |
//| Versi ini mengembalikan hasil lewat g_result, tidak menyentuh UI. |
//+------------------------------------------------------------------+
void HGRP_CalculateRiskAndPositionSize()
  {
   //--- reset hasil
   g_result.PositionSize  = 0;
   g_result.RiskMoney     = 0;
   g_result.BaseRiskMoney = 0;
   g_result.DisplayRisk   = 0;
   g_result.RewardMoney   = 0;
   g_result.RewardRisk    = 0;
   g_result.Valid         = false;
   g_result.Direction     = -1;
   g_result.CappedByMargin = false;

   const double acc_size   = AccountInfoDouble(ACCOUNT_BALANCE);
   const int    acc_dig    = g_sym.AccountCurrencyDigits;
   const double commission = HGRP_CalculateCommission();

   g_result.Commission = commission;

   //--- batas margin dihitung lebih dulu agar cap di bawah tidak
   //    bergantung pada urutan pemanggilan (lihat HGRP_CalculateMarginCap)
   HGRP_CalculateMarginCap();

   //--- PS :7917-7928 — risk money
   double display_risk = g_sets.Risk;
   double risk_money   = 0;

   if(!g_sets.UseMoneyInsteadOfPercentage)
     {
      risk_money = HGRP_Round(acc_size * g_sets.Risk / 100.0, acc_dig, true);
      g_sets.MoneyRisk = risk_money;
     }
   else
     {
      risk_money = g_sets.MoneyRisk;
      if(acc_size != 0)
         display_risk = HGRP_Round(g_sets.MoneyRisk / acc_size * 100.0, 2);
      else
         display_risk = 0;
      g_sets.Risk = display_risk;
     }

   double unit_cost, unit_cost_reward;
   HGRP_CalculateUnitCost(unit_cost, unit_cost_reward);
   g_result.UnitCostLoss   = unit_cost;
   g_result.UnitCostReward = unit_cost_reward;

   //--- PS :7932-7942 — arah posisi ditentukan dari posisi SL vs entry
   const double entry = g_sets.EntryLevel;
   const double sl    = g_sets.StopLossLevel;

   if(sl < entry)
      g_result.Direction = POSITION_TYPE_BUY;
   else
      if(sl > entry)
         g_result.Direction = POSITION_TYPE_SELL;
      else
         return;                                  // tidak ada sinyal

   //--- PS :7945-7958 — koreksi kurs masa depan.
   //    Hanya berlaku bila mata uang akun == base currency simbol forex.
   const bool is_forex = (g_sym.CalcMode == SYMBOL_CALC_MODE_FOREX ||
                          g_sym.CalcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);

   if((g_sym.AccountCurrency == g_sym.BaseCurrency) && is_forex && (sl != 0))
     {
      //--- Profit -> BID, Loss -> ASK (PS :7949-7956)
      const double current_rate = (sl < entry)
                                  ? SymbolInfoDouble(g_sym.Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(g_sym.Symbol, SYMBOL_BID);

      if(current_rate > 0)
         unit_cost *= (current_rate / sl);
     }

   //--- PS menyimpan StopLoss sebagai JARAK DALAM POIN, bukan selisih
   //    harga mentah. CLONE-SRC: Position Sizer.mqh:2232 / :3203
   //    sets.StopLoss = (int)MathRound(MathAbs(StopLossLevel - EntryLevel) / _Point);
   const double stop_loss_points = (double)(int)MathRound(MathAbs(entry - sl) / g_sym.Point);

   //--- PS :7960-7976 — lot dari risiko
   double position_size = g_result.PositionSize;   // OutputPositionSize (PS :7969)

   if((stop_loss_points != 0) && (unit_cost != 0) && (g_sym.TickSize != 0))
     {
      //--- PS :7973 — StopLoss(poin) * UnitCost / TickSize + 2 * komisi
      const double cost_per_lot = stop_loss_points * unit_cost / g_sym.TickSize +
                                  2.0 * commission;

      if(g_sets.RiskFromPositionSize)
        {
         //--- PS :7964. BUG LAMA: g_result.PositionSize sudah di-reset ke 0
         //    di awal fungsi, sehingga mode ini selalu menghasilkan risiko 0.
         //    Referensi memakai OutputPositionSize (lot yang dipegang).
         risk_money = HGRP_Round(position_size * cost_per_lot, acc_dig);
         g_sets.MoneyRisk = risk_money;

         if(acc_size != 0)
            display_risk = HGRP_Round(g_sets.MoneyRisk / acc_size * 100.0, 2);
         else
            display_risk = 0;

         g_sets.Risk = display_risk;
        }
      else
        {
         //--- PS :7973-7974
         if(cost_per_lot != 0)
            position_size = HGRP_Round(risk_money / cost_per_lot, g_sym.LotStepDigits, true);

         g_result.PositionSize = position_size;     // PS :7974
        }
     }

   //--- PS :7978-7981 — clamp ke batas broker
   if(!g_sets.CalculateUnadjustedPositionSize)
      g_result.PositionSize = HGRP_AdjustPositionSizeByMinMaxStep(g_result.PositionSize);

   //--- PS :7982 — cap oleh free margin. Port lama mendeklarasikan flag ini
   //    (InpCapMaxPositionSizeBasedOnMargin) tetapi tidak pernah memakainya,
   //    jadi lot bisa melebihi daya tampung margin.
   g_result.CappedByMargin = false;

   if(g_sets.CapMaxPositionSizeBasedOnMargin &&
      g_result.MaxPositionSizeByMargin > 0 &&
      g_result.PositionSize > g_result.MaxPositionSizeByMargin)
     {
      g_result.PositionSize   = g_result.MaxPositionSizeByMargin;
      g_result.CappedByMargin = true;
     }

   g_result.RiskMoney   = risk_money;
   g_result.DisplayRisk = display_risk;

   if(g_sym.TickSize == 0)
      return;

   const double cost_per_lot_final = stop_loss_points * unit_cost / g_sym.TickSize +
                                     2.0 * commission;

   //--- PS :7985 — risiko aktual untuk lot final
   g_result.RiskMoney = HGRP_Round(cost_per_lot_final * g_result.PositionSize, acc_dig);

   //--- PS :7987-7993 — risiko dasar, sebelum koreksi spread
   double base_sl = stop_loss_points;
   if(g_sets.SpreadAdjustmentSL && base_sl > 0)
     {
      base_sl -= HGRP_CurrentSpread();
      if(base_sl < 0)
         base_sl = 0;
     }

   g_result.BaseRiskMoney = HGRP_Round(
      (base_sl * unit_cost / g_sym.TickSize + 2.0 * commission) * g_result.PositionSize,
      acc_dig);

   g_result.Valid = (g_result.PositionSize > 0);

   HGRP_CalculateReward();
  }

//+------------------------------------------------------------------+
//| Batas lot menurut free margin, dihitung SEBELUM ukuran posisi.     |
//| CLONE-SRC: Position Sizer.mqh:7982 (OutputMaxPositionSize)         |
//|                                                                   |
//| Kenapa fungsi terpisah: HGRP_UpdateMarginTab() menghitung margin   |
//| untuk lot yang SUDAH dihitung, jadi nilainya baru tersedia di      |
//| siklus berikutnya. Kalau cap memakai nilai itu, lot yang tampil    |
//| bisa bergantung pada sisa siklus sebelumnya (tidak stabil saat     |
//| panel baru dibuka). Di sini batas diturunkan dari margin per lot   |
//| tanpa bergantung pada hasil sebelumnya.                            |
//+------------------------------------------------------------------+
void HGRP_CalculateMarginCap()
  {
   g_result.MaxPositionSizeByMargin = 0.0;

   const double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   if(free_margin <= 0 || g_sym.LotStep <= 0)
      return;

   //--- margin untuk 1 lot sebagai acuan
   const ENUM_ORDER_TYPE ot = (g_sets.EntryLevel >= SymbolInfoDouble(g_sym.Symbol, SYMBOL_ASK))
                              ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   double margin_per_lot = 0.0;

   if(!OrderCalcMargin(ot, g_sym.Symbol, 1.0, g_sets.EntryLevel, margin_per_lot))
      return;

   if(margin_per_lot <= 0)
      return;

   double cap = HGRP_Round(free_margin / margin_per_lot, g_sym.LotStepDigits, true);

   //--- batas atas broker (PS AdjustPositionSizeByMinMaxStep tidak boleh
   //    dilampaui walaupun margin masih longgar)
   if(!g_sets.SurpassBrokerMaxPositionSize && g_sym.MaxLot > 0 && cap > g_sym.MaxLot)
      cap = g_sym.MaxLot;

   g_result.MaxPositionSizeByMargin = cap;
  }

//+------------------------------------------------------------------+
//| Margin untuk lot hasil hitung + batas ukuran menurut margin.      |
//| Dipakai tab Margin. Rumus mengikuti OrderCalcMargin bawaan MT5,   |
//| bukan clone PS (PS memakai akun free margin yang sama).           |
//+------------------------------------------------------------------+
//| Filter portofolio — dipakai bersama oleh posisi dan order.        |
//+------------------------------------------------------------------+
bool HGRP_PassesFilter(const string symbol, const bool is_buy)
  {
   const HGRP_PanelState st = g_panel.State();

   //--- arah
   if(st.f_dir == 1 && !is_buy)
      return(false);
   if(st.f_dir == 2 && is_buy)
      return(false);

   //--- simbol
   if(st.f_symbols == 1 && symbol != _Symbol)
      return(false);
   if(st.f_symbols == 2 && symbol == _Symbol)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| Order pending: hanya dipakai bila filter "Include orders" != Open |
//+------------------------------------------------------------------+
bool HGRP_IncludePending()
  {
   return(g_panel.State().f_orders != 1);
  }

//+------------------------------------------------------------------+
//| Portofolio: risiko terbuka (posisi) dan risiko potensial (order). |
//| Keduanya dihitung dari SL yang benar-benar terpasang, dan hanya   |
//| posisi/order yang lolos filter yang dijumlahkan.                  |
//+------------------------------------------------------------------+
void HGRP_CalculatePortfolio()
  {
   const HGRP_PanelState st = g_panel.State();
   const double tick_value  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tick_size   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double open_risk  = 0.0;
   double pend_risk  = 0.0;
   int    open_cnt   = 0;
   int    pend_cnt   = 0;

   //--- 1) posisi terbuka
   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      const string sym = PositionGetString(POSITION_SYMBOL);
      const bool   buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double sl  = PositionGetDouble(POSITION_SL);

      if(!HGRP_PassesFilter(sym, buy))
         continue;

      //--- "Ignore orders without stop-loss": posisi tanpa SL dilewati
      if(sl <= 0 && st.f_ignore_nosl)
         continue;

      //--- "Ignore orders without take-profit" (spec rowsRisk :452)
      if(PositionGetDouble(POSITION_TP) <= 0 && st.f_ignore_notp)
         continue;

      const double open = PositionGetDouble(POSITION_PRICE_OPEN);
      const double lots = PositionGetDouble(POSITION_VOLUME);

      if(sl <= 0 || lots <= 0)
        {
         open_cnt++;
         continue;
        }

      //--- nilai per point untuk simbol posisi
      double tv = tick_value;
      double ts = tick_size;

      if(sym != _Symbol)
        {
         tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
         ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
        }

      if(ts <= 0)
        {
         open_cnt++;
         continue;
        }

      const double value_per_point = tv / (ts / SymbolInfoDouble(sym, SYMBOL_POINT));
      const double dist_points     = MathAbs(open - sl) / SymbolInfoDouble(sym, SYMBOL_POINT);

      open_risk += dist_points * value_per_point * lots;
      open_cnt++;
     }

   //--- 2) order pending (stop / limit)
   if(HGRP_IncludePending())
     {
      for(int i = 0; i < OrdersTotal(); i++)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;

         const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         const string sym = OrderGetString(ORDER_SYMBOL);

         if(StringFind(EnumToString(type), "BUY") < 0 &&
            StringFind(EnumToString(type), "SELL") < 0)
            continue;

         const bool buy = (StringFind(EnumToString(type), "BUY") >= 0);

         if(!HGRP_PassesFilter(sym, buy))
            continue;

         const double sl   = OrderGetDouble(ORDER_SL);
         const double open = OrderGetDouble(ORDER_PRICE_OPEN);
         const double lots = OrderGetDouble(ORDER_VOLUME_CURRENT);

         if(sl <= 0 && st.f_ignore_nosl)
            continue;

         if(OrderGetDouble(ORDER_TP) <= 0 && st.f_ignore_notp)
            continue;

         pend_cnt++;

         if(sl <= 0 || lots <= 0 || open <= 0)
            continue;

         double tv = tick_value;
         double ts = tick_size;

         if(sym != _Symbol)
           {
            tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
            ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
           }

         const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);

         if(ts <= 0 || pt <= 0)
            continue;

         pend_risk += (MathAbs(open - sl) / pt) * (tv / (ts / pt)) * lots;
        }
     }

   //--- 3) tulis ke hasil
   const int dig = g_sym.AccountCurrencyDigits;

   g_result.CurrentRiskMoney   = NormalizeDouble(open_risk, dig);
   g_result.CurrentRiskPercent = (g_sets.AccountBalance > 0)
                                 ? NormalizeDouble(open_risk / g_sets.AccountBalance * 100.0, 2)
                                 : 0.0;
   g_result.PotentialRiskMoney   = NormalizeDouble(open_risk + pend_risk, dig);
   g_result.PotentialRiskPercent = (g_sets.AccountBalance > 0)
                                   ? NormalizeDouble((open_risk + pend_risk) / g_sets.AccountBalance * 100.0, 2)
                                   : 0.0;
   g_result.OpenPositions   = open_cnt;
   g_result.PendingOrders   = pend_cnt;
  }


//+------------------------------------------------------------------+
void HGRP_UpdateMarginTab()
  {
   g_result.PositionMargin          = 0.0;
   g_result.UsedMargin              = 0.0;
   g_result.FreeMargin              = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   g_result.MaxPositionSizeByMargin = 0.0;

   if(g_result.PositionSize <= 0)
      return;

   const ENUM_ORDER_TYPE ot = (g_sets.EntryLevel >= SymbolInfoDouble(_Symbol, SYMBOL_ASK))
                              ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   double margin = 0.0;

   if(OrderCalcMargin(ot, _Symbol, g_result.PositionSize, g_sets.EntryLevel, margin))
     {
      g_result.PositionMargin = NormalizeDouble(margin, g_sym.AccountCurrencyDigits);
      g_result.UsedMargin     = NormalizeDouble(
                                 AccountInfoDouble(ACCOUNT_MARGIN) + margin,
                                 g_sym.AccountCurrencyDigits);
      g_result.FreeMargin     = NormalizeDouble(
                                 AccountInfoDouble(ACCOUNT_MARGIN_FREE) - margin,
                                 g_sym.AccountCurrencyDigits);
     }

   //--- lot maksimum yang masih tertampung free margin
   const double free_now = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   if(free_now > 0 && g_result.PositionMargin > 0)
     {
      const double per_lot = g_result.PositionMargin / g_result.PositionSize;
      if(per_lot > 0)
         g_result.MaxPositionSizeByMargin = HGRP_Round(
                                               free_now / per_lot, g_sym.LotStepDigits, true);
     }
  }

//+------------------------------------------------------------------+
//| Spread saat ini DALAM POIN — PS juga memakai poin di sini, agar   |
//| konsisten dengan base_sl yang juga poin.                          |
//+------------------------------------------------------------------+
double HGRP_CurrentSpread()
  {
   const double ask = SymbolInfoDouble(g_sym.Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(g_sym.Symbol, SYMBOL_BID);
   if(g_sym.Point <= 0)
      return 0;
   return MathMax((ask - bid) / g_sym.Point, 0);
  }

//+------------------------------------------------------------------+
//| Ambil level TP ke-i (0 = TP utama, 1.. = TP tambahan).            |
//+------------------------------------------------------------------+
double HGRP_TPLevelAt(const int i)
  {
   if(i <= 0)
      return g_sets.TPLevel;

   //--- TP2 punya field sendiri (TP2Level) karena juga dipakai UI legacy
   if(i == 1 && g_sets.TP2Level > 0)
      return g_sets.TP2Level;

   if(i - 1 < 20 && g_sets.TPAdditional[i - 1] > 0)
      return g_sets.TPAdditional[i - 1];

   return 0.0;
  }

//+------------------------------------------------------------------+
//| Reward / risk-reward untuk SEMUA level take-profit.               |
//| CLONE-SRC: Position Sizer.mqh:8019-8130                           |
//|                                                                   |
//| Selisih penting dengan port lama:                                 |
//|  * reward memakai unit cost SISI PROFIT (UnitCostReward),          |
//|    bukan sisi loss — spread membuat keduanya berbeda.             |
//|  * komisi reward memakai CommissionReward x2, BUKAN sisi risiko.   |
//|    Komisi profit-only memang tidak pernah masuk skenario kalah,    |
//|    jadi memakai sisi risiko akan mengecilkan reward.               |
//|  * reward dibulatkan ke BAWAH, RR juga ke bawah ke 2 desimal.     |
//|  * RR per level memakai risiko milik porsi lot level itu.          |
//|  * total reward = jumlah semua level; RR total = total reward /    |
//|    total risiko (PS :8100-8116). Kalau ada satu level tidak valid, | 
//|    RR total ikut ditandai tidak valid.                             |
//+------------------------------------------------------------------+
void HGRP_CalculateReward()
  {
   g_result.RewardMoney = 0;
   g_result.RewardRisk  = 0;

   ArrayInitialize(g_result.RewardPerTP, 0.0);
   ArrayInitialize(g_result.RewardRiskPerTP, 0.0);
   ArrayInitialize(g_result.TPInvalid, false);

   const double entry = g_sets.EntryLevel;
   const double sl    = g_sets.StopLossLevel;

   if(g_sym.TickSize == 0 || g_result.PositionSize <= 0)
      return;

   const int acc_dig = g_sym.AccountCurrencyDigits;

   //--- PS :8025-8029 — unit cost sisi reward
   const double unit_cost_reward = g_result.UnitCostReward;

   if(unit_cost_reward == 0)
      return;

   //--- pecah lot total ke setiap TP (PS PositionSizeToArray)
   double sizes[];
   HGRP_PositionSizeToArray(g_result.PositionSize, sizes);

   const int n = ArraySize(sizes);

   if(n < 1)
      return;

   const int tp_count = (g_sets.TakeProfitsNumber > 1) ? MathMin(g_sets.TakeProfitsNumber, n) : 1;

   //--- risiko per lot, lalu per porsi lot tiap level (PS :8051)
   const double risk_per_lot = g_result.RiskMoney / g_result.PositionSize;

   double total_reward = 0.0;
   double total_risk   = 0.0;
   bool   any_invalid  = false;
   bool   any_valid    = false;

   for(int i = 0; i < tp_count; i++)
     {
      const double tp_i = HGRP_TPLevelAt(i);

      if(tp_i <= 0)
         continue;

      if(sizes[i] <= 0)
         continue;

      //--- PS :8034 / :8073 — reward level ini
      const double reward_i = HGRP_Round(
                                 (MathAbs(tp_i - entry) * unit_cost_reward / g_sym.TickSize -
                                  2.0 * g_result.CommissionReward) * sizes[i],
                                 acc_dig, true);

      g_result.RewardPerTP[i] = reward_i;
      total_reward += reward_i;

      //--- PS :8048 — TP harus di sisi yang benar terhadap entry dan SL
      const bool tp_ok = ((tp_i > entry) && (entry > sl)) ||
                         ((tp_i < entry) && (entry < sl));

      if(!tp_ok)
        {
         g_result.TPInvalid[i] = true;
         any_invalid           = true;
         continue;
        }

      const double risk_i = risk_per_lot * sizes[i];

      if(risk_i <= 0)
         continue;

      //--- PS :8051 / :8082 — RR level ini
      g_result.RewardRiskPerTP[i] = HGRP_Round(reward_i / risk_i, 2, true);

      total_risk += risk_i;
      any_valid   = true;
     }

   g_result.RewardMoney = total_reward;

   //--- PS :8114-8118 — RR total; satu level tidak valid membatalkan total
   if(!any_invalid && any_valid && total_risk > 0)
      g_result.RewardRisk = HGRP_Round(total_reward / total_risk, 2, true);
  }

//+------------------------------------------------------------------+
//| Pembulatan Persis seperti Position Sizer.                         |
//| CLONE-SRC: Position Sizer.mqh:9403 Round()                        |
//|                                                                   |
//| round_down=false -> MathRound (dipakai untuk nilai uang)          |
//| round_down=true  -> MathFloor (dipakai untuk risk money & lot)    |
//|                                                                   |
//| Port lama memakai MathFloor + epsilon 1e-9. Epsilon itu           |
//| menutupi galat floating point pada kasus umum, tetapi nilainya     |
//| bisa membuat 0.2999999999 naik ke 0.30 — referensi membulatkan    |
//| langsung, jadi hasilnya bisa berbeda 1 step lot.                  |
//+------------------------------------------------------------------+
double HGRP_Round(const double value, const double digits, const bool round_down = false)
  {
   // CLONE-SRC: Position Sizer.mqh:9405 — int norm = (int)MathPow(10, digits);
   const int norm = (int)MathPow(10.0, digits);

   if(norm == 0)
      return value;

   if(!round_down)
      return MathRound(value * norm) / norm;

   return MathFloor(value * norm) / norm;
  }

//+------------------------------------------------------------------+
//| E5 — PositionSizeToArray                                          |
//| CLONE-SRC: Position Sizer.mqh:9880                                |
//|                                                                   |
//| Memecah lot total menjadi N take-profit sesuai TPShare[]:         |
//| dibulatkan ke bawah dulu, lalu sisanya dibagikan satu LotStep     |
//| sekaligus (round-robin) sampai sisa habis. Ini yang membuat      |
//| jumlah lot per TP selalu tepat sama dengan lot total.            |
//+------------------------------------------------------------------+
void HGRP_PositionSizeToArray(const double ps, double &sizes[])
  {
   if(!g_sets.TakeProfitsNumber || g_sets.TakeProfitsNumber <= 1)
     {
      ArrayResize(sizes, 1);
      sizes[0] = ps;
      return;
     }

   const int n = g_sets.TakeProfitsNumber;

   ArrayResize(sizes, n);

   double accumulated = 0;

   for(int i = n - 1; i >= 0; i--)
     {
      const double share = HGRP_BrokerizePositionSize(ps * (double)g_sets.TPShare[i] / 100.0);

      accumulated = NormalizeDouble(accumulated + share, g_sym.LotStepDigits);
      sizes[i]    = share;
     }

   //--- bagikan sisa satu LotStep bergiliran (LotStep > 0 mencegah loop liar)
   if(g_sym.LotStep > 0)
     {
      int guard = 0;

      while(ps - accumulated > 0 && guard < 100000)
        {
         for(int i = 0; i < n; i++)
           {
            sizes[i]    = NormalizeDouble(sizes[i] + g_sym.LotStep, g_sym.LotStepDigits);
            accumulated = NormalizeDouble(accumulated + g_sym.LotStep, g_sym.LotStepDigits);

            if(accumulated >= ps)
               break;
           }

         guard++;
        }
     }
  }

//+------------------------------------------------------------------+
//| Nilai awal pengaturan — mirror default Position Sizer.            |
//+------------------------------------------------------------------+
void HGRP_SetDefaults()
  {
   g_sets.UseMoneyInsteadOfPercentage      = false;
   g_sets.Risk                             = 1.0;
   g_sets.MoneyRisk                        = 100.0;
   g_sets.RiskFromPositionSize             = false;
   g_sets.EntryLevel                       = 0.0;
   g_sets.StopLossLevel                    = 0.0;
   g_sets.TPLockedOnSL                     = false;
   g_sets.EntryLevelSet                    = 0.0;
   g_sets.CommissionPerLot                 = 0.0;
   g_sets.CommissionType                   = 0;      // currency
   g_sets.AutoCommission                   = false;
   g_sets.CommissionProfitOnly             = false;
   g_sets.CalculateUnadjustedPositionSize  = false;
   g_sets.SurpassBrokerMaxPositionSize     = false;
   g_sets.CapMaxPositionSizeBasedOnMargin  = false;
   g_sets.SpreadAdjustmentSL               = false;
   g_sets.TakeProfitsNumber                = 1;
   ArrayInitialize(g_sets.TPShare, 0);
   g_sets.TPShare[0] = 100;
  }

//+------------------------------------------------------------------+
//| Hitung ulang dari level harga saat ini.                           |
//| Dipakai sebagai entry point sampai UI fase 3 siap.                |
//+------------------------------------------------------------------+
void HGRP_RecalculateFromMarket(const int direction, const double sl_price)
  {
   HGRP_LoadSymbol(_Symbol);

   if(direction == POSITION_TYPE_BUY)
      g_sets.EntryLevel = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   else
      g_sets.EntryLevel = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   g_sets.StopLossLevel = sl_price;

   HGRP_CalculateRiskAndPositionSize();

   PrintFormat("%s %s -> lot=%.2f risk=%.*f (%.2f%%) spread-adj=%.*f valid=%s",
               HGRP_PREFIX, _Symbol,
               g_result.PositionSize,
               g_sym.AccountCurrencyDigits, g_result.RiskMoney,
               g_result.DisplayRisk,
               g_sym.AccountCurrencyDigits, g_result.BaseRiskMoney,
               (g_result.Valid ? "yes" : "no"));
  }

//+------------------------------------------------------------------+
//| Guard reentrancy. Panjang 1 supaya tidak membebani stack.         |
//| Kenapa perlu: HGRP_SyncFromPanel() -> HGRP_WriteLine() mengubah    |
//| objek chart di dalam OnChartEvent. Tanpa guard, perubahan itu      |
//| memicu CHARTEVENT_OBJECT_CHANGE lagi dan MT5 bisa masuk loop       |
//| repaint tanpa henti (gejala: chart membeku saat panel diklik).     |
//+------------------------------------------------------------------+
bool g_syncing = false;

//+------------------------------------------------------------------+
//| Baca semua input panel ke g_sets, hitung, lalu tulis hasil balik. |
//| Ini jembatan UI -> engine. Tidak ada OrderSend di sini.           |
//+------------------------------------------------------------------+
void HGRP_SyncFromPanel()
  {
   //--- sudah di dalam sinkronisasi: abaikan panggilan bersarang
   if(g_syncing)
      return;

   g_syncing = true;
   const HGRP_PanelState st = g_panel.State();

   //--- arah
   g_sets.Direction  = st.direction;          // POSITION_TYPE_BUY / SELL
   g_sets.EntryLevel = (st.direction == POSITION_TYPE_BUY)
                       ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- level: garis chart adalah sumber kebenaran (bisa digeser user)
   const double line_sl = HGRP_ReadLine(ChartID(), HGRP_LINE_SL);
   const double line_tp = HGRP_ReadLine(ChartID(), HGRP_LINE_TP);

   const double sl = g_panel.ReadNumber("EDT_SL");
   g_sets.StopLossLevel = (line_sl > 0) ? line_sl : sl;

   if(line_tp > 0)
      g_sets.TPLevel = line_tp;
   else
     {
      const double edt = g_panel.ReadNumber("EDT_TP");
      if(edt > 0)
         g_sets.TPLevel = edt;
     }

   const double tp2 = g_panel.ReadNumber("EDT_TP2");
   if(tp2 > 0)
      g_sets.TP2Level = tp2;

   //--- TP3..n: masing-masing punya field sendiri (EDT_TP3, EDT_TP4, ...)
   //    dan share-nya (EDT_TP3SHARE, ...). dulu semua membaca TP2.
   g_sets.TakeProfitsNumber = MathMax(st.tps, 1);
   ArrayInitialize(g_sets.TPAdditional, 0.0);

   for(int i = 3; i <= g_sets.TakeProfitsNumber; i++)
     {
      const double lvl = g_panel.ReadNumber("EDT_TP" + IntegerToString(i));
      if(lvl > 0 && (i - 2) < 20)
         g_sets.TPAdditional[i - 2] = lvl;      // indeks 0 = TP2, jadi TP3 -> 1
     }

   //--- porsi lot tiap TP (%)
   for(int i = 1; i <= g_sets.TakeProfitsNumber && i <= 20; i++)
     {
      const double sh = g_panel.ReadNumber("EDT_TP" + IntegerToString(i) + "SHARE");
      if(sh >= 0)
         g_sets.TPShare[i - 1] = (int)MathRound(sh);
     }

   const double stopp = g_panel.ReadNumber("EDT_STOPP");
   if(stopp > 0)
      g_sets.StopPriceLevel = stopp;

   //--- biaya
   //    Saat Auto aktif, EDT_COMM diisi ulang oleh engine dengan nilai hasil
   //    baca aturan broker, jadi jangan dibaca balik — kalau dibaca balik
   //    nilai manual user hilang dan tidak bisa dipakai lagi setelah Auto
   //    dimatikan.
   g_sets.CommissionType = (st.commission_pct ? 1 : 0);
   g_sets.AutoCommission = st.auto_comm;

   if(!st.auto_comm)
      g_sets.CommissionPerLot = g_panel.ReadNumber("EDT_COMM");

   //--- saldo
   const double acct = g_panel.ReadNumber("EDT_ACCT");
   if(acct > 0)
      g_sets.AccountBalance = acct;

   //--- risiko: dua isian terpisah (Risk % dan Risk money), sesuai spec
   //    rowsMain(:420-423). Reference Position Sizer hanya punya SATU mode
   //    aktif (sets.UseMoneyInsteadOfPercentage); di panel AMIS keduanya
   //    tampil. Aturannya: kalau user mengisi Risk money (> 0) mode uang
   //    yang aktif, jika tidak mode persen. Nilai yang tidak aktif tidak
   //    ditimpa supaya user bisa bolak-balik tanpa kehilangan angka.
   const double risk_pct = g_panel.ReadNumber("EDT_RISKP");
   if(risk_pct > 0)
      g_sets.Risk = risk_pct;

   const double risk_money_in = g_panel.ReadNumber("EDT_RISKM");
   if(risk_money_in > 0)
      g_sets.MoneyRisk = risk_money_in;

   g_sets.UseMoneyInsteadOfPercentage = (risk_money_in > 0);

   //--- take profit & spread
   //    TakeProfitsNumber sudah di-set di blok TP di atas bersama harga
   //    dan porsi tiap level; jangan di-set ulang dari st.tps di sini.
   g_sets.SpreadAdjustmentSL  = st.spread_adj;
   g_sets.TPLockedOnSL        = st.tp_locked;
   g_sets.TrailingStop        = (int)g_panel.ReadNumber("EDT_TRAIL");
   g_sets.Breakeven           = (int)g_panel.ReadNumber("EDT_BE");
   g_sets.MagicNumber         = (long)g_panel.ReadNumber("EDT_MAGIC");
   g_sets.Commentary          = g_panel.ReadText("EDT_COMMENT");

   //--- panel -> garis: input yang diubah di panel ikut memindahkan garis
   HGRP_WriteLine(ChartID(), HGRP_LINE_SL, g_sets.StopLossLevel);
   HGRP_WriteLine(ChartID(), HGRP_LINE_TP, g_sets.TPLevel);

   HGRP_CalculateRiskAndPositionSize();
   HGRP_UpdateMarginTab();
   HGRP_CalculatePortfolio();

   //--- mode Auto: tampilkan komisi hasil baca broker di field Commission
   if(g_sets.AutoCommission)
      g_panel.SetAutoCommissionView(g_result.Commission);

   g_panel.UpdateResults(g_result.PositionSize,
                         g_result.RiskMoney,
                         g_result.DisplayRisk,
                         g_result.RewardMoney,
                         g_result.RewardRisk,
                         g_result.PositionMargin,
                         g_result.UsedMargin,
                         g_result.FreeMargin,
                         g_result.MaxPositionSizeByMargin,
                         g_result.Valid);

   g_syncing = false;
  }

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   HGRP_SetDefaults();
   HGRP_LoadSymbol(_Symbol);

   if(g_sym.TickSize <= 0)
     {
      PrintFormat("%s: simbol %s tidak punya TickSize valid — EA berhenti.",
                  HGRP_PREFIX, _Symbol);
      return(INIT_FAILED);
     }

   //--- saldo awal & SL default
   g_sets.AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   g_sets.EntryLevel    = ask;
   g_sets.StopLossLevel = NormalizeDouble(ask - 200 * g_sym.Point, _Digits);
   g_sets.TPLevel       = NormalizeDouble(ask + 400 * g_sym.Point, _Digits);

   g_sets.MagicNumber = 20220527;
   g_sets.Commentary  = "HGRP";

   g_panel.Create(ChartID(), 10, 20);

   //--- garis level: dibuat hanya bila belum ada, lalu dipulihkan
   HGRP_EnsureLines(ChartID(), _Symbol, _Digits);
   HGRP_LoadState();

   HGRP_SyncFromPanel();

   PrintFormat("%s: fase 3 aktif. 5 tab, engine clone, TANPA OrderSend.",
               HGRP_PREFIX);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Max: jarak SL/TP terjauh yang masih tertampung free margin.       |
//| Dihitung dari OrderCalcMargin, bukan angka ajaib.                 |
//+------------------------------------------------------------------+
void HGRP_ApplyMax()
  {
   const double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   const double min_lot     = g_sym.MinLot;
   const double ask         = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid         = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(free_margin <= 0 || min_lot <= 0 || _Point <= 0)
      return;

   double margin = 0.0;

   //--- margin untuk satu MinLot pada harga Ask
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, min_lot, ask, margin) || margin <= 0)
     {
      PrintFormat("%s: Max gagal, OrderCalcMargin error %d",
                  HGRP_PREFIX, GetLastError());
      return;
     }

   //--- berapa MinLot yang masih tertampung free margin
   const double lots = MathFloor(free_margin / margin) * min_lot;

   if(lots < min_lot)
     {
      PrintFormat("%s: Max ditolak, free margin %.2f tidak cukup untuk %.2f lot",
                  HGRP_PREFIX, free_margin, min_lot);
      return;
     }

   //--- jarak SL: seluruh free margin dipakai sebagai risiko satu posisi
   const double value_per_point = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) /
                                  (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) / _Point);

   if(value_per_point <= 0)
      return;

   //--- berapa lot yang muat, lalu jarak SL yang membuat loss = free margin
   const double sl_distance = free_margin / (lots * value_per_point) * _Point;
   const double tp_distance = sl_distance * 2.0;

   const double sl = NormalizeDouble(ask - sl_distance, _Digits);
   const double tp = NormalizeDouble(bid + tp_distance, _Digits);

   HGRP_WriteLine(ChartID(), HGRP_LINE_SL, sl);
   HGRP_WriteLine(ChartID(), HGRP_LINE_TP, tp);

   HGRP_SyncFromPanel();

   PrintFormat("%s: Max -> SL %s TP %s (free margin %.2f, %.2f lot)",
               HGRP_PREFIX, DoubleToString(sl, _Digits),
               DoubleToString(tp, _Digits), free_margin, lots);
  }

//+------------------------------------------------------------------+
//| Lock: saat aktif, TP mengikuti SL dengan jarak awal yang sama.    |
//+------------------------------------------------------------------+
void HGRP_ApplyLock(const double old_sl)
  {
   if(!g_panel.State().tp_locked)
      return;

   const double sl = HGRP_ReadLine(ChartID(), HGRP_LINE_SL);

   if(sl <= 0 || old_sl <= 0)
      return;

   const double tp   = HGRP_ReadLine(ChartID(), HGRP_LINE_TP);
   const double dist = MathAbs(tp - old_sl);

   if(dist <= 0)
      return;

   //--- SL turun -> TP ikut turun; SL naik -> TP ikut naik
   const double new_tp = (sl < old_sl)
                         ? NormalizeDouble(sl + dist, _Digits)
                         : NormalizeDouble(sl - dist, _Digits);

   HGRP_WriteLine(ChartID(), HGRP_LINE_TP, new_tp);
  }

string HGRP_GVKey(const string suffix)
  {
   return(HGRP_PREFIX + "STATE_" + (string)ChartID() + "_" + suffix);
  }

//+------------------------------------------------------------------+
//| Simpan posisi + state penting antar restart.                      |
//+------------------------------------------------------------------+
void HGRP_SaveState(void)
  {
   GlobalVariableSet(HGRP_GVKey("X"),    g_panel.PosX());
   GlobalVariableSet(HGRP_GVKey("Y"),    g_panel.PosY());
   GlobalVariableSet(HGRP_GVKey("TAB"),  g_panel.ActiveTab());
   GlobalVariableSet(HGRP_GVKey("RISK"), g_sets.Risk);
   GlobalVariableSet(HGRP_GVKey("ACCT"), g_sets.AccountBalance);
  }

//+------------------------------------------------------------------+
//| Pulihkan state. Mengembalikan true bila ada yang tersimpan.       |
//+------------------------------------------------------------------+
bool HGRP_LoadState(void)
  {
   if(!GlobalVariableCheck(HGRP_GVKey("X")))
      return(false);

   g_panel.SetTab((int)GlobalVariableGet(HGRP_GVKey("TAB")));
   g_panel.SetPos((int)GlobalVariableGet(HGRP_GVKey("X")),
                  (int)GlobalVariableGet(HGRP_GVKey("Y")));

   const double risk = GlobalVariableGet(HGRP_GVKey("RISK"));
   if(risk > 0)
      g_sets.Risk = risk;

   const double acct = GlobalVariableGet(HGRP_GVKey("ACCT"));
   if(acct > 0)
      g_sets.AccountBalance = acct;

   return(true);
  }

//+------------------------------------------------------------------+
//| Hapus state milik chart ini (dipakai saat EA dihapus).            |
//+------------------------------------------------------------------+
void HGRP_ClearState(void)
  {
   string keys[5];
   keys[0] = "X";
   keys[1] = "Y";
   keys[2] = "TAB";
   keys[3] = "RISK";
   keys[4] = "ACCT";

   for(int i = 0; i < 5; i++)
     {
      const string k = HGRP_GVKey(keys[i]);
      if(GlobalVariableCheck(k))
         GlobalVariableDel(k);
     }
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Hitung objek chart yang namanya diawali prefix tertentu.          |
//+------------------------------------------------------------------+
int HGRP_CountPrefix(const string prefix)
  {
   const long chart = ChartID();
   const int  total = ObjectsTotal(chart, -1, -1);
   const int  plen  = StringLen(prefix);
   int        n     = 0;

   for(int i = 0; i < total; i++)
     {
      const string nm = ObjectName(chart, i, -1, -1);

      if(StringLen(nm) >= plen && StringFind(nm, prefix) == 0)
         n++;
     }

   return(n);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   HGRP_SaveState();

   //--- state milik chart dihapus hanya bila EA benar-benar dicabut
   if(reason == REASON_REMOVE || reason == REASON_CLOSE)
      HGRP_ClearState();

   //--- Garis level ikut dihapus saat EA dicabut / chart ditutup.
   //    Destroy() membersihkan prefix HGRP_ DAN HGRPL_.
   //
   //    CATATAN: garis dibuat dengan OBJPROP_SELECTABLE=true supaya user
   //    bisa menggeser level. Objek seperti itu diperlakukan MT5 sebagai
   //    milik user, jadi kita hapus eksplisit di sini — bukan mengandalkan
   //    pembersihan otomatis.
   g_panel.Destroy();

   ObjectsDeleteAll(ChartID(), HGRPL_PREFIX);

   PrintFormat("%s: OnDeinit reason=%d, sisa objek HGRPL_=%d",
               HGRP_PREFIX, reason, HGRP_CountPrefix(HGRPL_PREFIX));

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| OnChartEvent — klik, drag, resize chart.                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam,
                  const string &sparam)
  {
   static bool dragging   = false;
   static bool drag_reset = false;
   static int  drag_off_x = 0;
   static int  drag_off_y = 0;

   //--- chart di-resize / di-scroll.
   //    PEMBELAJARAN DARI _reference (Position Sizer.mq5:1040-1095):
   //    panel referensi SENGAJA tidak memanggil handler panel pada
   //    CHARTEVENT_CHART_CHANGE — komentarnya: "workaround for minimization
   //    bug on chart switch". Mereka hanya membaca lebar chart, dan TIDAK
   //    memindahkan objek panel sama sekali pada event ini.
   //
   //    Kode kita sebelumnya memanggil ClampToChart() -> Shift() yang
   //    memindahkan SEMUA objek panel pada SETIAP event CHART_CHANGE.
   //    Scroll chart mengirim puluhan event per detik, jadi ini membanjiri
   //    thread chart dan membekukan MT5. Sekarang: tidak ada pemindahan
   //    objek pada CHART_CHANGE sama sekali.
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      //--- safety net: bila drag pernah dimulai lalu tombol lepas di luar
      //    chart, CHART_MOUSE_SCROLL bisa tertinggal false dan scroll mati.
      if(ChartGetInteger(ChartID(), CHART_MOUSE_SCROLL) == 0)
         ChartSetInteger(ChartID(), CHART_MOUSE_SCROLL, true);

      return;
     }

   //--- mode geser: tombol kiri tertahan = geser, dilepas = selesai
   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      if(!dragging)
         return;

      const bool left_down = ((int)StringToInteger(sparam) & 1) == 1;

      if(!left_down)
        {
         dragging = false;
         ChartSetInteger(ChartID(), CHART_MOUSE_SCROLL, true);
         HGRP_SaveState();   // simpan sekali saat lepas, bukan per pixel
         return;
        }

      //--- pengaman: bila tombol sudah lepas di luar chart, MT5 berhenti
      //    mengirim MOUSE_MOVE dan CHART_MOUSE_SCROLL tertinggal di false —
      //    scroll chart mati permanen. Timeout ini mengembalikannya.
      static uint drag_start_ms = 0;
      static int  drag_last_x   = -1, drag_last_y = -1;

      const uint now = GetTickCount();

      static int  last_x  = -1, last_y = -1;
      static uint last_ms = 0;

      if(drag_reset || drag_start_ms == 0)
        {
         drag_start_ms = now;
         drag_last_x   = (int)lparam;
         drag_last_y   = (int)dparam;
         drag_reset    = false;
         last_x        = -1;
         last_y        = -1;
        }

      const int nx = (int)lparam - drag_off_x;
      const int ny = (int)dparam - drag_off_y;

      //--- abaikan gerakan < 2 px: mouse bisa kirim ratusan event per detik
      //    dan setiap SetPos memindahkan puluhan objek chart.
      if(MathAbs(nx - last_x) < 2 && MathAbs(ny - last_y) < 2)
         return;
      if(now - last_ms < 16)
         return;

      last_x  = nx;
      last_y  = ny;
      last_ms = now;

      g_panel.SetPos(nx, ny);
      return;
     }

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(StringFind(sparam, HGRP_PREFIX) != 0)
      return;

   //--- tap dance: MT5 membiarkan objek "tertekan"; lepaskan
   ObjectSetInteger(ChartID(), sparam, OBJPROP_STATE, false);

   //--- klik pada handle drag: mulai mode geser
   if(sparam == HGRP_PREFIX + "DRAG")
     {
      dragging   = true;
      drag_off_x = (int)lparam - g_panel.PosX();
      drag_off_y = (int)dparam - g_panel.PosY();
      drag_reset = true;   // MOUSE_MOVE berikutnya menyegarkan baseline
      ChartSetInteger(ChartID(), CHART_MOUSE_SCROLL, false);
      return;
     }

   const double sl_before = HGRP_ReadLine(ChartID(), HGRP_LINE_SL);

   if(!g_panel.OnClick(sparam))
      return;

   const string n = StringSubstr(sparam, StringLen(HGRP_PREFIX));

   if(n == "BTN_MAX" || n == "BTN_MAX_BG")
      HGRP_ApplyMax();
   else
     {
      HGRP_ApplyLock(sl_before);
      HGRP_SyncFromPanel();
     }

   HGRP_SaveState();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| OnTick — hanya refresh harga agar panel tidak basi.               |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- sengaja kosong: panel hanya menghitung saat pengguna mengubah
   //    input. Tidak ada order, tidak ada state otomatis.
  }

