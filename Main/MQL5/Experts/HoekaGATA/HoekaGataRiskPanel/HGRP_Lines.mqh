//+------------------------------------------------------------------+
//|                                                HGRP_Lines.mqh     |
//|   Tiga garis level yang bisa digeser user di chart.               |
//|                                                                   |
//|   Sumber kebenaran level BUKAN panel, melainkan objek chart       |
//|   (sama seperti Position Sizer: `StopLossLine` dst.). Panel        |
//|   membaca harga garis setiap kali menghitung.                     |
//|                                                                   |
//|   Garis TIDAK dihapus saat EA dilepas — itu setup milik user.     |
//|   Hanya dihapus bila EA dihapus dengan alasan lain (chart close). |
//+------------------------------------------------------------------+
//| Garis level memakai prefix TERPISAH (HGRPL_) supaya tidak ikut       |
//| terhapus oleh ObjectsDeleteAll(HGRP_PREFIX) di Redraw().             |
//+------------------------------------------------------------------+
#ifndef HGRP_LINES_MQH
#define HGRP_LINES_MQH

#define HGRPL_PREFIX    "HGRPL_"
#define HGRP_LINE_ENTRY "HGRPL_EntryLine"
#define HGRP_LINE_SL    "HGRPL_StopLossLine"
#define HGRP_LINE_TP    "HGRPL_TakeProfitLine"

//+------------------------------------------------------------------+
//| Buat satu garis bila belum ada. Warna & style tidak ditimpa bila  |
//| garis sudah ada, agar setup user tidak berubah saat re-attach.    |
//+------------------------------------------------------------------+
void HGRP_CreateLine(const long chart, const string name, const double price,
                     const color clr, const string text)
  {
   if(ObjectFind(chart, name) >= 0)
      return;

   if(!ObjectCreate(chart, name, OBJ_HLINE, 0, 0, price))
     {
      PrintFormat("%s: gagal membuat garis %s (error %d)",
                  HGRP_PREFIX, name, GetLastError());
      return;
     }

   ObjectSetInteger(chart, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(chart, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(chart, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(chart, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(chart, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(chart, name, OBJPROP_BACK, false);
   ObjectSetInteger(chart, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(chart, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(chart, name, OBJPROP_RAY_RIGHT, false);

   if(StringLen(text) > 0)
      ObjectSetString(chart, name, OBJPROP_TEXT, text);
  }

//+------------------------------------------------------------------+
//| Baca harga garis. Mengembalikan 0.0 bila garis tidak ada.         |
//+------------------------------------------------------------------+
double HGRP_ReadLine(const long chart, const string name)
  {
   if(ObjectFind(chart, name) < 0)
      return(0.0);

   return(ObjectGetDouble(chart, name, OBJPROP_PRICE));
  }

//+------------------------------------------------------------------+
//| Tulis harga garis (tanpa ObjectCreate).                           |
//+------------------------------------------------------------------+
void HGRP_WriteLine(const long chart, const string name, const double price)
  {
   if(ObjectFind(chart, name) < 0 || price <= 0)
      return;

   ObjectSetDouble(chart, name, OBJPROP_PRICE, 0, price);
  }

//+------------------------------------------------------------------+
//| Tampilkan / sembunyikan garis. Hide lines memakai TIMEFRAMES      |
//| supaya garis bisa kembali tanpa kehilangan harganya.              |
//+------------------------------------------------------------------+
void HGRP_ShowLines(const long chart, const bool show)
  {
   string names[3];
   names[0] = HGRP_LINE_ENTRY;
   names[1] = HGRP_LINE_SL;
   names[2] = HGRP_LINE_TP;

   const ENUM_OBJECT_PROPERTY_INTEGER tf_prop = OBJPROP_TIMEFRAMES;
   const long tf = (show ? (long)OBJ_ALL_PERIODS : (long)OBJ_NO_PERIODS);

   for(int i = 0; i < 3; i++)
     {
      if(ObjectFind(chart, names[i]) >= 0)
         ObjectSetInteger(chart, names[i], tf_prop, tf);
     }
  }

//+------------------------------------------------------------------+
//| Pastikan ketiga garis ada. Dipanggil sekali di OnInit.            |
//| Bila belum ada, pakai indikator HoekaGATA bila kebetulan hidup    |
//| (dibaca sekali, tanpa iCustom/handle), kalau tidak bid +/- 1%.    |
//+------------------------------------------------------------------+
void HGRP_EnsureLines(const long chart, const string symbol, const int digits)
  {
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double pct = (bid > 0) ? bid * 0.01 : 1.0;

   //--- per garis: hanya dibuat bila belum ada. Jangan overwrite setup user.
   if(ObjectFind(chart, HGRP_LINE_ENTRY) < 0)
      HGRP_CreateLine(chart, HGRP_LINE_ENTRY, bid, C'46,196,182', "Entry");

   if(ObjectFind(chart, HGRP_LINE_SL) < 0)
      HGRP_CreateLine(chart, HGRP_LINE_SL, NormalizeDouble(bid - pct, digits),
                      C'229,72,77', "SL");

   if(ObjectFind(chart, HGRP_LINE_TP) < 0)
      HGRP_CreateLine(chart, HGRP_LINE_TP, NormalizeDouble(bid + pct * 2, digits),
                      C'38,166,154', "TP");
  }

#endif // HGRP_LINES_MQH
