//+------------------------------------------------------------------+
//|                                              HGRP_Panel.mqh       |
//|   Panel UI AMIS — fase 3 lengkap (5 tab).                         |
//|                                                                   |
//|   Acuan desain (1:1):  Main/Docs/amis-sizer-panel.html            |
//|   Palet & geometri :   .root CSS di file yang sama.               |
//|                                                                   |
//|   Semua objek memakai prefix HGRP_.                               |
//|                                                                   |
//|   CATATAN READ-ONLY:                                              |
//|   OBJPROP_READONLY diabaikan sebagian build MT5 pada OBJ_EDIT.    |
//|   Karena itu pill read-only TIDAK memakai OBJ_EDIT, melainkan     |
//|   OBJ_RECTANGLE_LABEL (latar field-ro) + OBJ_LABEL (teks).        |
//|   Hasilnya tidak bisa diklik-edit sama sekali, jadi perilakunya   |
//|   tidak bergantung pada OBJPROP_READONLY.                         |
//+------------------------------------------------------------------+
#ifndef HGRP_PANEL_MQH
#define HGRP_PANEL_MQH

//--- palet
#define HGRP_C_BG        C'16,21,28'
#define HGRP_C_LINE      C'42,52,65'
#define HGRP_C_TEXT      C'230,235,241'
#define HGRP_C_LABEL     C'211,218,227'
#define HGRP_C_MUTED     C'138,151,166'
#define HGRP_C_TEAL      C'46,196,182'
#define HGRP_C_GREEN     C'38,166,154'
#define HGRP_C_RED       C'229,72,77'
#define HGRP_C_AMBER     C'224,160,42'
#define HGRP_C_CARD      C'26,32,41'
#define HGRP_C_LINECARD  C'38,46,57'
#define HGRP_C_LINEPILL  C'59,70,85'
#define HGRP_C_FIELD     C'14,19,26'
#define HGRP_C_FIELD_RO  C'21,27,35'
#define HGRP_C_SEGON     C'52,54,60'
#define HGRP_C_BUY       C'15,122,85'
#define HGRP_C_SELL      C'179,38,44'
#define HGRP_C_DIV       C'43,51,63'

//--- geometri
#define HGRP_PANEL_W      360
#define HGRP_PAD_X         14
#define HGRP_PAD_T         12
#define HGRP_TITLE_H       30
#define HGRP_CARD_GAP      10
#define HGRP_CARD_PAD       8
#define HGRP_SEC_H         18
#define HGRP_ROW_H         24
#define HGRP_PILL_H        22
#define HGRP_PILL_W       118
#define HGRP_BTN_H         22
#define HGRP_TAB_H         26
#define HGRP_FOOT_H        54

//--- tab
#define HGRP_TAB_MAIN       0
#define HGRP_TAB_RISK       1
#define HGRP_TAB_MARGIN     2
#define HGRP_TAB_SWAPS      3
#define HGRP_TAB_TRADING    4
#define HGRP_TAB_COUNT      5

//+------------------------------------------------------------------+
//| State panel — dipakai lintas tab dan oleh EA.                     |
//+------------------------------------------------------------------+
struct HGRP_PanelState
  {
   int               direction;        // POSITION_TYPE_BUY / SELL
   bool              use_money;        // risiko dalam uang
   bool              commission_pct;   // komisi persen
   bool              auto_comm;        // komisi dibaca otomatis dari broker
   int               order_type;       // 0 instant, 1 pending, 2 stop limit
   bool              tp_locked;
   bool              spread_adj;       // tombol SA
   bool              hide_lines;
   int               tps;              // jumlah take-profit
   //--- filter portofolio (tab Risk)
   int               f_orders;         // 0 All, 1 Open, 2 Pending
   int               f_symbols;        // 0 All, 1 Current, 2 Other
   int               f_dir;            // 0 All, 1 Buy, 2 Sell
   bool              f_ignore_nosl;
   bool              f_ignore_notp;    // abaikan order tanpa take-profit
  };

//+------------------------------------------------------------------+
//| Panel AMIS.                                                       |
//+------------------------------------------------------------------+
class HGRP_Panel
  {
private:
   long              m_chart;
   int               m_x, m_y;
   int               m_w, m_h;
   int               m_active_tab;
   bool              m_minimized;
   HGRP_PanelState   m_st;
   color             m_dir_color;

   //--- pembuat objek
   void              Rect(const string name, const int x, const int y,
                          const int w, const int h,
                          const color bg, const color border);
   void              Label(const string name, const int x, const int y,
                           const string text, const color clr,
                           const int size, const bool bold = false);
   void              Edit(const string name, const int x, const int y,
                          const int w, const int h, const string text);
   void              PillRO(const string name, const int x, const int y,
                            const int w, const string text,
                            const color clr);
   void              Card(const string name, const int x, const int y,
                          const int w, const int h, const string title);
   void              Btn(const string name, const int x, const int y,
                         const int w, const string text, const bool on);
   void              RowLabel(const string name, const int x, const int y,
                              const string text, const bool small = false);
   void              Seg(const string name, const int x, const int y,
                         const int w, const string &items[],
                         const int active);
   void              DragHandle(void);

   //--- panel per tab
   void              DrawFrame(void);
   void              DrawTabs(void);
   void              DrawTabMain(const int y0, const int cardW);
   void              DrawTabRisk(const int y0, const int cardW);
   void              DrawTabRiskTables(const int y0, const int cardW);
   void              DrawTabMargin(const int y0, const int cardW);
   void              DrawTabSwaps(const int y0, const int cardW);
   void              DrawTabTrading(const int y0, const int cardW);
   void              ClearTab(const int tab);

public:
                     HGRP_Panel(void);
                    ~HGRP_Panel(void) {}

   bool              Create(const long chart, const int x, const int y);
   void              Destroy(void);
   void              SetTab(const int tab);
   void              Redraw(void);
   int               ActiveTab(void) const { return m_active_tab; }
   int               Width(void)  const { return m_w; }
   int               Height(void) const { return m_h; }

   //--- posisi panel (dipakai drag & persistensi)
   int               PosX(void) const { return m_x; }
   int               PosY(void) const { return m_y; }
   void              SetPos(const int x, const int y);
   void              Shift(const int dx, const int dy);
   void              ClampToChart(void);
   void              SnapToCenter(void);
   void              SeedTakeProfits(void);
   void              SetAutoCommissionView(const double value);

   //--- state yang dibaca EA
   HGRP_PanelState   State(void) const { return m_st; }
   void              SetDirection(const int dir);
   void              SetState(const HGRP_PanelState &st) { m_st = st; }

   //--- tulis hasil engine ke panel
   void              UpdateResults(const double position_size,
                                   const double risk_money,
                                   const double display_risk,
                                   const double reward_money,
                                   const double rr,
                                   const double margin,
                                   const double used_margin,
                                   const double free_margin,
                                   const double max_ps_margin,
                                   const bool   valid);

   //--- baca teks input mentah dari chart
   string            ReadText(const string name) const;
   double            ReadNumber(const string name) const;
   void              WriteText(const string name, const string value);

   //--- klik
   bool              OnClick(const string obj);
  };

//+------------------------------------------------------------------+
HGRP_Panel::HGRP_Panel(void)
  {
   m_chart      = 0;
   m_x          = 10;
   m_y          = 20;
   m_w          = HGRP_PANEL_W;
   m_h          = 0;
   m_active_tab = HGRP_TAB_MAIN;
   m_minimized  = false;
   m_dir_color  = HGRP_C_BUY;

   m_st.direction      = POSITION_TYPE_BUY;
   m_st.use_money      = false;
   m_st.commission_pct = false;
   m_st.auto_comm      = false;
   m_st.order_type     = 0;
   m_st.tp_locked      = false;
   m_st.spread_adj     = false;
   m_st.hide_lines     = false;
   m_st.tps            = 1;
  }


//+------------------------------------------------------------------+
//| Tampilkan nilai komisi hasil baca broker di field Commission.     |
//| Dipakai hanya saat mode Auto aktif, supaya user melihat angka yang |
//| benar-benar dipakai engine. Saat Auto mati, field kembali bisa     |
//| diedit dan nilainya milik user.                                   |
//+------------------------------------------------------------------+
void HGRP_Panel::SetAutoCommissionView(const double value)
  {
   if(!m_st.auto_comm)
      return;

   //--- hanya tulis bila nilainya beda, agar chart tidak redraw terus
   const string txt = DoubleToString(value, 2);

   if(ReadText("EDT_COMM") == txt)
      return;

   WriteText("EDT_COMM", txt);
  }

//+------------------------------------------------------------------+
//| Isi harga & porsi untuk TP yang baru ditambahkan.                 |
//|                                                                   |
//| Saat jumlah TP naik, field TP2/TP3/TP4 muncul kosong. Kotak kosong |
//| membuat TP level itu dilewati engine (HGRP_TPLevelAt -> 0) dan     |
//| porsi 0 membuat lot-nya ikut 0, sehingga total lot tidak terpakai. |
//| Di sini: harga = Entry + n*(TP1-Entry) (TP menyebar sejajar),      |
//| lalu porsi dibagi rata 100/n% dan sisanya ke TP terakhir.         |
//+------------------------------------------------------------------+
void HGRP_Panel::SeedTakeProfits(void)
  {
   const int n = MathMax(m_st.tps, 1);

   if(n <= 1)
      return;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double tp1   = g_sets.TPLevel;

   //--- jarak TP1 dari entry; kalau belum masuk akal pakai 200 poin
   double dist = (tp1 > 0 && entry > 0) ? MathAbs(tp1 - entry) : 0.0;

   if(dist <= 0)
      dist = 200 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(dist <= 0)
      return;

   //--- arah TP mengikuti posisi TP1 terhadap entry (default: ke atas)
   const double sign = (tp1 > 0 && entry > 0 && tp1 < entry) ? -1.0 : 1.0;

   for(int i = 2; i <= n; i++)
     {
      const string s   = IntegerToString(i);
      const double lvl = NormalizeDouble(entry + sign * dist * i, _Digits);

      //--- hanya isi bila field masih kosong / nol (jangan timpa isian user)
      const double cur = ReadNumber("EDT_TP" + s);

      if(cur <= 0)
         WriteText("EDT_TP" + s, DoubleToString(lvl, _Digits));
     }

   //--- porsi dibagi rata, sisa pembulatan ke TP terakhir
   int per = 100 / n;
   int acc = 0;

   for(int i = 1; i <= n; i++)
     {
      const string s  = IntegerToString(i);
      const double cur = ReadNumber("EDT_TP" + s + "SHARE");

      int share = (i == n) ? (100 - acc) : per;

      if(cur <= 0)
         WriteText("EDT_TP" + s + "SHARE", IntegerToString(share));

      acc += share;
     }
  }

void HGRP_Panel::Rect(const string name, const int x, const int y,
                      const int w, const int h,
                      const color bg, const color border)
  {
   const string obj = HGRP_PREFIX + name;

   //--- properti statis cukup diset sekali saat objek lahir.
   //    Menyetel ulang 7 properti pada setiap Redraw() berarti ribuan
   //    operasi API chart per klik (lihat _reference: panel mereka dibuat
   //    sekali lalu hanya nilainya yang diperbarui).
   if(ObjectFind(m_chart, obj) < 0)
     {
      ObjectCreate(m_chart, obj, OBJ_RECTANGLE_LABEL, 0, 0, 0);

      ObjectSetInteger(m_chart, obj, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_chart, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, obj, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, obj, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, obj, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chart, obj, OBJPROP_HIDDEN, true);
     }

   //--- properti dinamis: hanya tulis bila berbeda.
   const int nx = m_x + x;
   const int ny = m_y + y;

   if(ObjectGetInteger(m_chart, obj, OBJPROP_XDISTANCE) != nx)
      ObjectSetInteger(m_chart, obj, OBJPROP_XDISTANCE, nx);
   if(ObjectGetInteger(m_chart, obj, OBJPROP_YDISTANCE) != ny)
      ObjectSetInteger(m_chart, obj, OBJPROP_YDISTANCE, ny);
   if(ObjectGetInteger(m_chart, obj, OBJPROP_XSIZE) != w)
      ObjectSetInteger(m_chart, obj, OBJPROP_XSIZE, w);
   if(ObjectGetInteger(m_chart, obj, OBJPROP_YSIZE) != h)
      ObjectSetInteger(m_chart, obj, OBJPROP_YSIZE, h);
   if((color)ObjectGetInteger(m_chart, obj, OBJPROP_BGCOLOR) != bg)
      ObjectSetInteger(m_chart, obj, OBJPROP_BGCOLOR, bg);
   if((color)ObjectGetInteger(m_chart, obj, OBJPROP_COLOR) != border)
      ObjectSetInteger(m_chart, obj, OBJPROP_COLOR, border);
  }

//+------------------------------------------------------------------+
//| Teks.                                                             |
//+------------------------------------------------------------------+
void HGRP_Panel::Label(const string name, const int x, const int y,
                       const string text, const color clr,
                       const int size, const bool bold)
  {
   const string obj = HGRP_PREFIX + name;

   if(ObjectFind(m_chart, obj) < 0)
     {
      ObjectCreate(m_chart, obj, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(m_chart, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, obj, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(m_chart, obj, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, obj, OBJPROP_HIDDEN, true);
     }

   //--- hanya tulis properti yang berubah
   const int nx = m_x + x;
   const int ny = m_y + y;

   if(ObjectGetInteger(m_chart, obj, OBJPROP_XDISTANCE) != nx)
      ObjectSetInteger(m_chart, obj, OBJPROP_XDISTANCE, nx);
   if(ObjectGetInteger(m_chart, obj, OBJPROP_YDISTANCE) != ny)
      ObjectSetInteger(m_chart, obj, OBJPROP_YDISTANCE, ny);

   if(ObjectGetString(m_chart, obj, OBJPROP_TEXT) != text)
      ObjectSetString(m_chart, obj, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(m_chart, obj, OBJPROP_COLOR) != clr)
      ObjectSetInteger(m_chart, obj, OBJPROP_COLOR, clr);
   if((int)ObjectGetInteger(m_chart, obj, OBJPROP_FONTSIZE) != size)
      ObjectSetInteger(m_chart, obj, OBJPROP_FONTSIZE, size);

   //--- font: hanya diset bila berbeda (StringFind per objek mahal)
   const string font = (bold ? "Arial Bold" : "Arial");

   if(ObjectGetString(m_chart, obj, OBJPROP_FONT) != font)
      ObjectSetString(m_chart, obj, OBJPROP_FONT, font);
  }

//+------------------------------------------------------------------+
//| Input yang bisa diedit.                                           |
//+------------------------------------------------------------------+
void HGRP_Panel::Edit(const string name, const int x, const int y,
                      const int w, const int h, const string text)
  {
   const string obj = HGRP_PREFIX + name;

   if(ObjectFind(m_chart, obj) < 0)
      ObjectCreate(m_chart, obj, OBJ_EDIT, 0, 0, 0);

   ObjectSetInteger(m_chart, obj, OBJPROP_XDISTANCE, m_x + x);
   ObjectSetInteger(m_chart, obj, OBJPROP_YDISTANCE, m_y + y);
   ObjectSetInteger(m_chart, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(m_chart, obj, OBJPROP_YSIZE, h);
   ObjectSetString(m_chart, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(m_chart, obj, OBJPROP_BGCOLOR, HGRP_C_FIELD);
   ObjectSetInteger(m_chart, obj, OBJPROP_COLOR, HGRP_C_TEXT);
   ObjectSetInteger(m_chart, obj, OBJPROP_BORDER_COLOR, HGRP_C_LINEPILL);
   ObjectSetInteger(m_chart, obj, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(m_chart, obj, OBJPROP_ALIGN, ALIGN_RIGHT);
   ObjectSetInteger(m_chart, obj, OBJPROP_READONLY, false);
   ObjectSetInteger(m_chart, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chart, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chart, obj, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Pill read-only — TANPA OBJ_EDIT, jadi tidak mungkin diedit.       |
//| Teks disimpan sebagai OBJ_LABEL bernama <name> agar bisa diupdate.|
//+------------------------------------------------------------------+
void HGRP_Panel::PillRO(const string name, const int x, const int y,
                        const int w, const string text, const color clr)
  {
   Rect(name + "_BG", x, y, w, HGRP_PILL_H, HGRP_C_FIELD_RO, HGRP_C_LINEPILL);

   //--- teks rata kanan di dalam pill, memakai anchor kanan-atas
   const string obj = HGRP_PREFIX + name;

   if(ObjectFind(m_chart, obj) < 0)
      ObjectCreate(m_chart, obj, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(m_chart, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(m_chart, obj, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(m_chart, obj, OBJPROP_XDISTANCE, m_x + x + w - 5);
   ObjectSetInteger(m_chart, obj, OBJPROP_YDISTANCE, m_y + y + 5);
   ObjectSetString(m_chart, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(m_chart, obj, OBJPROP_COLOR, clr);
   ObjectSetInteger(m_chart, obj, OBJPROP_FONTSIZE, 8);
   ObjectSetString(m_chart, obj, OBJPROP_FONT, "Arial");
   ObjectSetInteger(m_chart, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chart, obj, OBJPROP_HIDDEN, true);
  }


//+------------------------------------------------------------------+
//| Kartu: kotak + judul seksi uppercase. Mengembalikan y isi.        |
//| Pemanggil menambah sendiri offset barisnya.                       |
//+------------------------------------------------------------------+
void HGRP_Panel::Card(const string name, const int x, const int y,
                      const int w, const int h, const string title)
  {
   Rect(name, x, y, w, h, HGRP_C_CARD, HGRP_C_LINECARD);

   if(StringLen(title) > 0)
      Label(name + "_SEC", x + HGRP_CARD_PAD, y + 4, title, HGRP_C_MUTED, 7);
  }

//+------------------------------------------------------------------+
//| Tombol teks kecil (+, -, Max, SA, TPx, Lock).                     |
//+------------------------------------------------------------------+
void HGRP_Panel::Btn(const string name, const int x, const int y,
                     const int w, const string text, const bool on)
  {
   Rect(name + "_BG", x, y, w, HGRP_PILL_H,
        (on ? HGRP_C_SEGON : HGRP_C_CARD),
        (on ? HGRP_C_TEAL : HGRP_C_LINEPILL));
   Label(name, x + 4, y + 4, text, (on ? HGRP_C_TEXT : HGRP_C_MUTED), 7);
  }

//+------------------------------------------------------------------+
//| Label baris kiri.                                                 |
//+------------------------------------------------------------------+
void HGRP_Panel::RowLabel(const string name, const int x, const int y,
                          const string text, const bool small)
  {
   Label(name, x, y + 6, text, (small ? HGRP_C_MUTED : HGRP_C_LABEL), (small ? 7 : 8));
  }

//+------------------------------------------------------------------+
//| Segmented control — aktif ditandai latar SEGON + border teal.     |
//+------------------------------------------------------------------+
void HGRP_Panel::Seg(const string name, const int x, const int y,
                     const int w, const string &items[], const int active)
  {
   const int n = ArraySize(items);
   if(n <= 0)
      return;

   const int cell = w / n;

   for(int i = 0; i < n; i++)
     {
      const bool on = (i == active);

      Rect(name + "_BG_" + IntegerToString(i), x + i * cell, y, cell,
           HGRP_PILL_H,
           (on ? HGRP_C_SEGON : HGRP_C_CARD),
           (on ? HGRP_C_TEAL : HGRP_C_LINEPILL));
      Label(name + "_" + IntegerToString(i), x + i * cell + 4, y + 6,
            items[i], (on ? HGRP_C_TEXT : HGRP_C_MUTED), 7);
     }
  }

//+------------------------------------------------------------------+
//| Bersihkan objek milik satu tab sebelum digambar ulang.            |
//+------------------------------------------------------------------+
void HGRP_Panel::ClearTab(const int tab)
  {
   //--- semua tab hidup di area isi yang sama, jadi cukup bersihkan
   //    seluruh prefix (frame akan digambar ulang oleh Redraw()).
  }

//+------------------------------------------------------------------+
//| Hapus dan gambar ulang seluruh panel.                             |
//+------------------------------------------------------------------+
void HGRP_Panel::Redraw(void)
  {
   ObjectsDeleteAll(m_chart, HGRP_PREFIX);

   DrawFrame();
   DrawTabs();
   DragHandle();

   //--- minimized: tidak ada isi tab yang perlu digambar
   if(m_minimized)
      return;

   const int y0    = HGRP_PAD_T + HGRP_TITLE_H + HGRP_TAB_H + 8;
   const int cardW = m_w - 2 * HGRP_PAD_X;

   switch(m_active_tab)
     {
      case HGRP_TAB_RISK:    DrawTabRisk(y0, cardW);    break;
      case HGRP_TAB_MARGIN:  DrawTabMargin(y0, cardW);  break;
      case HGRP_TAB_SWAPS:   DrawTabSwaps(y0, cardW);   break;
      case HGRP_TAB_TRADING: DrawTabTrading(y0, cardW); break;
      default:               DrawTabMain(y0, cardW);    break;
     }
  }

//+------------------------------------------------------------------+
//| Bingkai: latar + judul 2 baris + simbol/TF.                       |
//+------------------------------------------------------------------+
void HGRP_Panel::DrawFrame(void)
  {
   int body_h = 0;

   //--- saat minimized: hanya header + tab yang tersisa, isi tab tidak ada.
   //    Tanpa cabang ini minimize jadi no-op dan Redraw() membangun ulang
   //    ~120 objek setiap klik (chart tampak membeku).
   if(m_minimized)
     {
      m_h = HGRP_PAD_T + HGRP_TITLE_H + HGRP_TAB_H + 10;

      Rect("BG", 0, 0, m_w, m_h, HGRP_C_BG, HGRP_C_LINE);

      const int ym = HGRP_PAD_T;

      Label("TITLE_1",    HGRP_PAD_X,      ym,      "HoekaGata", HGRP_C_TEXT, 11, true);
      Label("TITLE_AMIS", HGRP_PAD_X + 64, ym,      "AMIS",      HGRP_C_TEAL, 11, true);
      Label("TITLE_2",    HGRP_PAD_X,      ym + 16, "minimized", HGRP_C_MUTED, 7);

      const int right_m = m_w - HGRP_PAD_X;

      Btn("BTN_CENTER", right_m - 34, ym + 1, 15, "+", false);
      Btn("BTN_MIN",    right_m - 17, ym + 1, 15, "=", false);
      return;
     }

   switch(m_active_tab)
     {
      case HGRP_TAB_RISK:    body_h = 366; break;
      case HGRP_TAB_MARGIN:  body_h = 190; break;
      case HGRP_TAB_SWAPS:   body_h = 210; break;
      case HGRP_TAB_TRADING: body_h = 400; break;
      default:
         //--- tab Main: tinggi mengikuti jumlah TP (baris TP & kartu share
         //    tumbuh bersama), supaya kartu paling bawah tidak terpotong.
         body_h = 420 + MathMax(m_st.tps - 1, 0) * (2 * HGRP_ROW_H);
         break;
     }

   m_h = HGRP_PAD_T + HGRP_TITLE_H + HGRP_TAB_H + 8 + body_h + HGRP_FOOT_H;

   Rect("BG", 0, 0, m_w, m_h, HGRP_C_BG, HGRP_C_LINE);

   //--- judul
   const int y = HGRP_PAD_T;

   Label("TITLE_1",    HGRP_PAD_X,       y,      "HoekaGata",      HGRP_C_TEXT, 11, true);
   Label("TITLE_AMIS", HGRP_PAD_X + 64,  y,      "AMIS",           HGRP_C_TEAL, 11, true);
   Label("TITLE_2",    HGRP_PAD_X,       y + 16, "AMIS Risk Panel", HGRP_C_MUTED, 7);

   //--- kanan atas: simbol + timeframe + tombol
   const int right = m_w - HGRP_PAD_X;

   Label("SYM", right - 104, y,      _Symbol,                          HGRP_C_TEXT,  9, true);
   Label("TF",  right - 104, y + 16, EnumToString(_Period),            HGRP_C_MUTED, 7);

   Btn("BTN_CENTER", right - 34, y + 1, 15, "+", false);
   Btn("BTN_MIN",    right - 17, y + 1, 15, "-", false);

   //--- footer
   const int fy = m_h - HGRP_FOOT_H + 8;

   Rect("FOOT", 0, m_h - HGRP_FOOT_H, m_w, HGRP_FOOT_H, HGRP_C_CARD, HGRP_C_LINECARD);
   Label("FOOT_HINT", HGRP_PAD_X, fy + 14, "Engine clone aktif — tidak mengirim order",
         HGRP_C_MUTED, 7);
  }

//+------------------------------------------------------------------+
//| Strip 5 tab.                                                      |
//+------------------------------------------------------------------+
void HGRP_Panel::DrawTabs(void)
  {
   string names[HGRP_TAB_COUNT];

   names[0] = "Main";
   names[1] = "Risk";
   names[2] = "Margin";
   names[3] = "Swaps";
   names[4] = "Trading";

   const int y     = HGRP_PAD_T + HGRP_TITLE_H + 4;
   const int tab_w = (m_w - 2 * HGRP_PAD_X) / HGRP_TAB_COUNT;

   for(int i = 0; i < HGRP_TAB_COUNT; i++)
     {
      const int  x  = HGRP_PAD_X + i * tab_w;
      const bool on = (i == m_active_tab);

      Rect("TAB_BG_" + IntegerToString(i), x, y, tab_w - 2, HGRP_TAB_H,
           (on ? HGRP_C_SEGON : HGRP_C_CARD),
           (on ? HGRP_C_TEAL : HGRP_C_LINECARD));
      ObjectSetInteger(m_chart, HGRP_PREFIX + "TAB_BG_" + IntegerToString(i),
                       OBJPROP_BACK, false);
      Label("TAB_" + IntegerToString(i), x + 5, y + 6, names[i],
            (on ? HGRP_C_TEXT : HGRP_C_MUTED), 8, on);
     }
  }

//+------------------------------------------------------------------+
//| Tab MAIN — Price & targets + Calculation.                         |
//| Nilai diambil dari g_sets / g_result, bukan contoh statis.        |
//+------------------------------------------------------------------+
void HGRP_Panel::DrawTabMain(const int y0, const int cardW)
  {
   const int x0    = HGRP_PAD_X;
   const int lblX  = x0 + HGRP_CARD_PAD;
   const int pillX = lblX + 96;
   const int pillW = HGRP_PILL_W;
   const int dig   = g_sym.AccountCurrencyDigits;

   //=== kartu 1: Price & targets =============================
   // Tinggi kartu ikut jumlah baris supaya tidak ada celah kosong saat
   // TPx / Pending aktif. Baris: Entry, Stop-loss, Take-profit,
   // Take-profit 2..n, Stop price, Order type.
   int rows_price = 3;                              // entry, sl, tp
   rows_price += MathMax(m_st.tps - 1, 0);          // TP tambahan
   rows_price += (m_st.order_type != 0) ? 1 : 0;    // stop price
   rows_price += 1;                                 // order type

   const int c1h = HGRP_SEC_H + 8 + rows_price * HGRP_ROW_H + HGRP_CARD_PAD;

   Card("CARD_PRICE", x0, y0, cardW, c1h, "PRICE & TARGETS");

   int ry = y0 + HGRP_SEC_H + 8;

   //--- Entry: segmented Long/Short + harga entry (satu baris, dua kontrol)
   //    BUG LAMA: SEG_DIR dan PILL_ENTRY digambar di piksel yang sama
   //    (pillX, ry) sehingga saling menimpa. Sekarang dibagi: segmen
   //    memakai lebar tetap, pill harga mengisi sisanya.
   RowLabel("LBL_ENTRY", lblX, ry, "Entry");

   string dirs[2];
   dirs[0] = "Long";
   dirs[1] = "Short";

   const int segW = 76;
   Seg("SEG_DIR", pillX, ry, segW, dirs,
       (m_st.direction == POSITION_TYPE_BUY ? 0 : 1));

   const double entry = g_sets.EntryLevel;
   PillRO("PILL_ENTRY", pillX + segW + 4, ry, pillW - segW - 4,
          DoubleToString(entry, _Digits), HGRP_C_TEXT);

   //--- tombol - / + untuk entry (dua tombol terpisah, sesuai spec)
   Btn("BTN_EN_DN", pillX + pillW + 4,      ry, 18, "-", false);
   Btn("BTN_EN_UP", pillX + pillW + 4 + 20, ry, 18, "+", false);

   ry += HGRP_ROW_H;

   //--- Stop-loss (+ SA bila spread adjustment aktif)
   RowLabel("LBL_SL", lblX, ry, "Stop-loss");
   Edit("EDT_SL", pillX, ry + 1, 62, HGRP_PILL_H,
        DoubleToString(g_sets.StopLossLevel, _Digits));
   Btn("BTN_SL_DN", pillX + 64,  ry + 1, 18, "-", false);
   Btn("BTN_SL_UP", pillX + 84,  ry + 1, 18, "+", false);
   Btn("BTN_SL_SA", pillX + 104, ry + 1, 18, "SA", m_st.spread_adj);
   ry += HGRP_ROW_H;

   //--- Take-profit: TPx | harga | - | + | Lock
   RowLabel("LBL_TP", lblX, ry, "Take-profit");
   Btn("BTN_TPN", pillX, ry + 1, 32, "TPx" + IntegerToString(m_st.tps), false);
   Edit("EDT_TP", pillX + 34, ry + 1, 42, HGRP_PILL_H,
        DoubleToString(g_sets.TPLevel, _Digits));
   Btn("BTN_TP_DN", pillX + 78, ry + 1, 16, "-", false);
   Btn("BTN_TP_UP", pillX + 95, ry + 1, 16, "+", false);
   Btn("BTN_TP_LOCK", pillX + 113, ry + 1, 19, "L", m_st.tp_locked);
   ry += HGRP_ROW_H;

   //--- TP tambahan: label + harga + - / +
   for(int i = 2; i <= m_st.tps; i++)
     {
      RowLabel("LBL_TP" + IntegerToString(i), lblX, ry,
               "Take-profit " + IntegerToString(i));
      Edit("EDT_TP" + IntegerToString(i), pillX, ry + 1, 62, HGRP_PILL_H,
           DoubleToString((i == 2 ? g_sets.TP2Level : g_sets.TPAdditional[i - 2]), _Digits));
      Btn("BTN_TP" + IntegerToString(i) + "_DN", pillX + 64, ry + 1, 18, "-", false);
      Btn("BTN_TP" + IntegerToString(i) + "_UP", pillX + 84, ry + 1, 18, "+", false);
      ry += HGRP_ROW_H;
     }

   //--- Stop price (hanya untuk pending / stop-limit)
   if(m_st.order_type != 0)
     {
      RowLabel("LBL_STOPP", lblX, ry, "Stop price");
      Edit("EDT_STOPP", pillX, ry + 1, 62, HGRP_PILL_H,
           DoubleToString(g_sets.StopPriceLevel, _Digits));
      Btn("BTN_SP_DN", pillX + 64, ry + 1, 18, "-", false);
      Btn("BTN_SP_UP", pillX + 84, ry + 1, 18, "+", false);
      ry += HGRP_ROW_H;
     }

   //--- Order type + Hide lines
   RowLabel("LBL_ORDER", lblX, ry, "Order type");
   string otypes[3];
   otypes[0] = "Inst";
   otypes[1] = "Pend";
   otypes[2] = "S/L";
   Seg("SEG_ORDER", pillX, ry, 76, otypes, m_st.order_type);
   Btn("BTN_HIDE", pillX + 80, ry + 1, 40, "Hide", m_st.hide_lines);
   ry += HGRP_ROW_H;

   //=== kartu 2: Calculation =================================
   // Baris: Commission, Account balance, header Input/Result,
   // Risk %, Risk money, Reward money, Reward/risk, Position size = 8.
   const int c2h = HGRP_SEC_H + 8 + 8 * HGRP_ROW_H + HGRP_CARD_PAD;
   const int y2  = y0 + c1h + HGRP_CARD_GAP;

   Card("CARD_CALC", x0, y2, cardW, c2h, "CALCULATION");

   int cy = y2 + HGRP_SEC_H + 8;

   //--- Commission % / $ + toggle "Auto" (baca aturan komisi broker)
   RowLabel("LBL_COMM", lblX, cy, "Commission");
   string ctypes[2];
   ctypes[0] = "%";
   ctypes[1] = "$";
   Seg("SEG_COMMTYPE", pillX, cy, 40, ctypes, (m_st.commission_pct ? 0 : 1));
   Btn("BTN_AUTOCOMM", pillX + 42, cy, 22, "A", m_st.auto_comm);
   Edit("EDT_COMM", pillX + 66, cy + 1, pillW - 66, HGRP_PILL_H,
        DoubleToString(g_sets.CommissionPerLot, 2));
   cy += HGRP_ROW_H;

   //--- Account balance
   RowLabel("LBL_ACCT", lblX, cy, "Account balance");
   Edit("EDT_ACCT", pillX, cy + 1, pillW, HGRP_PILL_H,
        DoubleToString(g_sets.AccountBalance, 2));
   cy += HGRP_ROW_H;

   //--- header kolom Input | Result (spec rowsMain :419)
   Label("LBL_COL_IN",  pillX + 4,          cy + 5, "Input",  HGRP_C_MUTED, 7);
   Label("LBL_COL_RES", pillX + pillW / 2,  cy + 5, "Result", HGRP_C_MUTED, 7);
   cy += HGRP_ROW_H;

   //--- Risk % : input | hasil
   RowLabel("LBL_RISKP", lblX, cy, "Risk %");
   Edit("EDT_RISKP", pillX, cy + 1, 54, HGRP_PILL_H,
        DoubleToString(g_sets.Risk, 2));
   PillRO("PILL_RISKP", pillX + 58, cy + 1, pillW - 58,
          DoubleToString(g_result.DisplayRisk, 2), HGRP_C_TEXT);
   cy += HGRP_ROW_H;

   //--- Risk money : input | hasil
   RowLabel("LBL_RISKM", lblX, cy, "Risk money");
   Edit("EDT_RISKM", pillX, cy + 1, 54, HGRP_PILL_H,
        DoubleToString(g_sets.MoneyRisk, 2));
   PillRO("PILL_RISKM", pillX + 58, cy + 1, pillW - 58,
          DoubleToString(g_result.RiskMoney, dig), HGRP_C_TEXT);
   cy += HGRP_ROW_H;

   //--- Reward money (hasil; input-nya adalah TP di kartu atas)
   RowLabel("LBL_REWARD", lblX, cy, "Reward money");
   PillRO("PILL_REWARD", pillX, cy + 1, pillW,
          DoubleToString(g_result.RewardMoney, dig), HGRP_C_GREEN);
   cy += HGRP_ROW_H;

   //--- Reward/risk
   RowLabel("LBL_RR", lblX, cy, "Reward/risk");
   PillRO("PILL_RR", pillX, cy + 1, pillW,
          DoubleToString(g_result.RewardRisk, 2),
          (g_result.RewardRisk >= 1.0 ? HGRP_C_GREEN : HGRP_C_TEXT));
   cy += HGRP_ROW_H;

   //--- Position size : Max | lot
   RowLabel("LBL_PS", lblX, cy, "Position size");
   Btn("BTN_MAX", pillX, cy + 1, 32, "Max", false);
   PillRO("PILL_PS", pillX + 36, cy + 1, pillW - 36,
          DoubleToString(g_result.PositionSize, g_sym.LotStepDigits),
          (g_result.Valid ? HGRP_C_TEAL : HGRP_C_RED));
  }


//+------------------------------------------------------------------+
//| Tab RISK — Portfolio filter + Current + Potential.                |
//| Acuan: rowsRisk() di amis-sizer-panel.html.                       |
//+------------------------------------------------------------------+
void HGRP_Panel::DrawTabRisk(const int y0, const int cardW)
  {
   const int x0    = HGRP_PAD_X;
   const int lblX  = x0 + HGRP_CARD_PAD;
   const int pillX = lblX + 86;
   const int pillW = HGRP_PILL_W;
   const int dig   = g_sym.AccountCurrencyDigits;

   string opts3[3];
   opts3[0] = "All";
   opts3[1] = "Open";
   opts3[2] = "Pend";

   //=== kartu 1: Portfolio filter ============================
   // Baris: Include orders, Include symbols, Include, 2 checkbox = 5
   const int c1h = HGRP_SEC_H + 8 + 5 * HGRP_ROW_H + HGRP_CARD_PAD;
   Card("CARD_PORT", x0, y0, cardW, c1h, "PORTFOLIO FILTER");

   int ry = y0 + HGRP_SEC_H + 8;

   RowLabel("LBL_RGPORD", lblX, ry, "Include orders");
   Seg("SEG_RGPORD", pillX, ry, pillW, opts3, m_st.f_orders);
   ry += HGRP_ROW_H;

   string syms3[3];
   syms3[0] = "All";
   syms3[1] = "Cur";
   syms3[2] = "Other";
   RowLabel("LBL_RGPSYM", lblX, ry, "Include symbols");
   Seg("SEG_RGPSYM", pillX, ry, pillW, syms3, m_st.f_symbols);
   ry += HGRP_ROW_H;

   string dirs3[3];
   dirs3[0] = "All";
   dirs3[1] = "Buy";
   dirs3[2] = "Sell";
   RowLabel("LBL_RGPDIR", lblX, ry, "Include");
   Seg("SEG_RGPDIR", pillX, ry, pillW, dirs3, m_st.f_dir);
   ry += HGRP_ROW_H;

   //--- checkbox 1 (spec rowsRisk :450 chkIgnoreSL)
   Btn("BTN_IGN_SL", lblX, ry + 1, 14, "x", m_st.f_ignore_nosl);
   Label("LBL_IGN_SL", lblX + 18, ry + 7, "Ignore orders without stop-loss",
         HGRP_C_MUTED, 7);
   ry += HGRP_ROW_H;

   //--- checkbox 2 (spec rowsRisk :452 chkIgnoreTP) — sebelumnya HILANG
   Btn("BTN_IGN_TP", lblX, ry + 1, 14, "x", m_st.f_ignore_notp);
   Label("LBL_IGN_TP", lblX + 18, ry + 7, "Ignore orders without take-profit",
         HGRP_C_MUTED, 7);
  }

//+------------------------------------------------------------------+
//| Tab RISK bagian 2 — Current & Potential portfolio.                |
//+------------------------------------------------------------------+
void HGRP_Panel::DrawTabRiskTables(const int y0, const int cardW)
  {
   const int x0   = HGRP_PAD_X;
   const int lblX = x0 + HGRP_CARD_PAD;
   const int dig  = g_sym.AccountCurrencyDigits;

   //=== kartu 2: Current portfolio ===========================
   // Offset kartu 1 dihitung dari baris, bukan angka mati 138, supaya tidak
   // tumpang tindih kalau jumlah baris filter berubah.
   const int port_h = HGRP_SEC_H + 8 + 5 * HGRP_ROW_H + HGRP_CARD_PAD;
   const int y2     = y0 + port_h + HGRP_CARD_GAP;
   Card("CARD_CUR", x0, y2, cardW, 116, "CURRENT PORTFOLIO");

   int cy = y2 + HGRP_SEC_H + 6;

   //--- tiga kolom dalam lebar kartu (cardW - 2*CARD_PAD = 3*colW + 2*gap).
   //    BUG LAMA: kolom ketiga di lblX+190 lebar 86 -> 276 > lebar isi kartu,
   //    pill "Lots"/"CRRR" keluar dari bingkai kartu.
   const int gap  = 6;
   const int colW = (cardW - 2 * HGRP_CARD_PAD - 2 * gap) / 3;
   const int c1x  = lblX + 4;
   const int c2x  = c1x + colW + gap;
   const int c3x  = c2x + colW + gap;

   Label("CUR_H1", c1x + 4, cy + 2, "Risk $",   HGRP_C_MUTED, 7);
   Label("CUR_H2", c2x + 4, cy + 2, "Risk %",   HGRP_C_MUTED, 7);
   Label("CUR_H3", c3x + 4, cy + 2, "Lots",     HGRP_C_MUTED, 7);
   cy += 16;

   PillRO("CUR_RISK",  c1x, cy, colW,
          DoubleToString(g_result.CurrentRiskMoney, dig), HGRP_C_TEXT);
   PillRO("CUR_RISKP", c2x, cy, colW,
          DoubleToString(g_result.CurrentRiskPercent, 2), HGRP_C_TEXT);
   PillRO("CUR_LOTS",  c3x, cy, colW,
          IntegerToString(g_result.OpenPositions), HGRP_C_TEAL);
   cy += HGRP_ROW_H + 4;

   Label("CUR_H4", c1x + 4, cy + 2, "Reward $", HGRP_C_MUTED, 7);
   Label("CUR_H5", c2x + 4, cy + 2, "Reward %", HGRP_C_MUTED, 7);
   Label("CUR_H6", c3x + 4, cy + 2, "CRRR",     HGRP_C_MUTED, 7);
   cy += 16;

   PillRO("CUR_REW",  c1x, cy, colW,
          DoubleToString(g_result.RewardMoney, dig), HGRP_C_GREEN);
   PillRO("CUR_REWP", c2x, cy, colW,
          DoubleToString(g_result.DisplayRisk, 2), HGRP_C_TEXT);
   PillRO("CUR_CRRR", c3x, cy, colW,
          DoubleToString(g_result.RewardRisk, 2), HGRP_C_AMBER);

   //=== kartu 3: Potential portfolio =========================
   // x2/x3 sudah dihitung di kartu Current (colW/gap yang sama).
   const int y3 = y2 + 116 + HGRP_CARD_GAP;
   Card("CARD_POT", x0, y3, cardW, 100, "POTENTIAL PORTFOLIO");

   int py = y3 + HGRP_SEC_H + 6;

   Label("POT_H1", c1x + 4, py + 2, "Risk $", HGRP_C_MUTED, 7);
   Label("POT_H2", c2x + 4, py + 2, "Risk %", HGRP_C_MUTED, 7);
   Label("POT_H3", c3x + 4, py + 2, "Lots",   HGRP_C_MUTED, 7);
   py += 16;

   PillRO("POT_RISK",  c1x, py, colW,
          DoubleToString(g_result.RiskMoney, dig), HGRP_C_TEXT);
   PillRO("POT_RISKP", c2x, py, colW,
          DoubleToString(g_result.DisplayRisk, 2), HGRP_C_TEXT);
   PillRO("POT_LOTS",  c3x, py, colW,
          DoubleToString(g_result.PositionSize, g_sym.LotStepDigits), HGRP_C_TEAL);
   py += HGRP_ROW_H + 4;

   Label("POT_H4", c1x + 4, py + 2, "Reward $", HGRP_C_MUTED, 7);
   Label("POT_H5", c2x + 4, py + 2, "Reward %", HGRP_C_MUTED, 7);
   Label("POT_H6", c3x + 4, py + 2, "PRRR",     HGRP_C_MUTED, 7);
   py += 16;

   PillRO("POT_REW",  c1x, py, colW,
          DoubleToString(g_result.RewardMoney, dig), HGRP_C_GREEN);
   PillRO("POT_REWP", c2x, py, colW,
          DoubleToString(g_sets.Risk, 2), HGRP_C_TEXT);
   PillRO("POT_PRRR", c3x, py, colW,
          DoubleToString(g_result.RewardRisk, 2), HGRP_C_AMBER);
  }


//+------------------------------------------------------------------+
//| Tab MARGIN — margin posisi, leverage, batas ukuran.              |
//+------------------------------------------------------------------+
void HGRP_Panel::DrawTabMargin(const int y0, const int cardW)
  {
   const int x0    = HGRP_PAD_X;
   const int lblX  = x0 + HGRP_CARD_PAD;
   const int pillX = lblX + 118;
   const int pillW = HGRP_PILL_W - 22;
   const int dig   = g_sym.AccountCurrencyDigits;

   //=== kartu 1: Margin ======================================
   Card("CARD_MRG", x0, y0, cardW, 98, "MARGIN");

   int ry = y0 + HGRP_SEC_H + 8;

   RowLabel("LBL_POSM", lblX, ry, "Position margin");
   PillRO("PILL_POSM", pillX, ry + 1, pillW,
          DoubleToString(g_result.PositionMargin, dig), HGRP_C_TEXT);
   ry += HGRP_ROW_H;

   RowLabel("LBL_USEDM", lblX, ry, "Future used margin");
   PillRO("PILL_USEDM", pillX, ry + 1, pillW,
          DoubleToString(g_result.UsedMargin, dig), HGRP_C_TEXT);
   ry += HGRP_ROW_H;

   RowLabel("LBL_FREEM", lblX, ry, "Future free margin");
   PillRO("PILL_FREEM", pillX, ry + 1, pillW,
          DoubleToString(g_result.FreeMargin, dig),
          (g_result.FreeMargin >= 0 ? HGRP_C_GREEN : HGRP_C_RED));

   //=== kartu 2: Leverage ====================================
   const int y2 = y0 + 98 + HGRP_CARD_GAP;
   Card("CARD_LEV", x0, y2, cardW, 62, "LEVERAGE");

   int ly = y2 + HGRP_SEC_H + 8;

   RowLabel("LBL_LEV", lblX, ly, "Custom leverage");
   Label("LBL_LEV1", pillX, ly + 5, "1:", HGRP_C_MUTED, 7);
   Edit("EDT_LEV", pillX + 14, ly + 1, 50, HGRP_PILL_H, "0");
   Label("LBL_LEVACC", pillX + 68, ly + 6,
         "(Acct 1:" + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)) + ")",
         HGRP_C_MUTED, 7);
   ly += HGRP_ROW_H;

   Label("LBL_LEVSYM", pillX, ly + 2,
         "(leverage akun; simbol memakai default broker)",
         HGRP_C_MUTED, 7);

   //=== kartu 3: Batas ukuran ================================
   const int y3 = y2 + 62 + HGRP_CARD_GAP;
   Card("CARD_MAX", x0, y3, cardW, 42, "BATAS UKURAN");

   RowLabel("LBL_MAXPS", lblX, y3 + HGRP_SEC_H + 10, "Max size by margin");
   PillRO("PILL_MAXPS", pillX, y3 + HGRP_SEC_H + 11, pillW,
          DoubleToString(g_result.MaxPositionSizeByMargin, g_sym.LotStepDigits),
          HGRP_C_TEXT);
  }

//+------------------------------------------------------------------+
//| Tab SWAPS — setting, nilai per lot, catatan.                     |
//+------------------------------------------------------------------+
void HGRP_Panel::DrawTabSwaps(const int y0, const int cardW)
  {
   const int x0    = HGRP_PAD_X;
   const int lblX  = x0 + HGRP_CARD_PAD;
   const int pillX = lblX + 88;
   const int pillW = HGRP_PILL_W;
   const int half  = (pillW - 4) / 2;

   long swap_mode = SymbolInfoInteger(_Symbol, SYMBOL_SWAP_MODE);
   string mode_txt = "Points";

   if(swap_mode == SYMBOL_SWAP_MODE_CURRENCY_SYMBOL)
      mode_txt = "Currency";
   else if(swap_mode == SYMBOL_SWAP_MODE_INTEREST_CURRENT)
      mode_txt = "Interest";

   const int day3 = (int)SymbolInfoInteger(_Symbol, SYMBOL_SWAP_ROLLOVER3DAYS);
   string trip = "Wednesday";

   if(day3 == 1)      trip = "Monday";
   else if(day3 == 2) trip = "Tuesday";
   else if(day3 == 4) trip = "Thursday";
   else if(day3 == 5) trip = "Friday";

   //=== kartu 1: Swap setting ================================
   Card("CARD_SWP", x0, y0, cardW, 72, "SWAP SETTING");

   int ry = y0 + HGRP_SEC_H + 8;

   RowLabel("LBL_SWPT", lblX, ry, "Type");
   PillRO("PILL_SWPT", pillX, ry + 1, pillW, mode_txt, HGRP_C_TEXT);
   ry += HGRP_ROW_H;

   RowLabel("LBL_SWPTR", lblX, ry, "Triple swap");
   PillRO("PILL_SWPTR", pillX, ry + 1, pillW, trip, HGRP_C_TEXT);

   //=== kartu 2: Nilai swap per lot ==========================
   const int y2 = y0 + 72 + HGRP_CARD_GAP;
   Card("CARD_SWV", x0, y2, cardW, 118, "NILAI SWAP PER LOT");

   int sy = y2 + HGRP_SEC_H + 6;

   Label("SWV_HL", pillX + 6,          sy + 2, "Long",  HGRP_C_MUTED, 7);
   Label("SWV_HS", pillX + half + 8,   sy + 2, "Short", HGRP_C_MUTED, 7);
   sy += 16;

   //--- nominal: SYMBOL_SWAP_LONG / SHORT
   const double sw_long  = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
   const double sw_short = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);

   RowLabel("LBL_SWVN", lblX, sy, "Nominal");
   PillRO("PILL_SWL", pillX, sy + 1, half,
          DoubleToString(sw_long, 2), (sw_long < 0 ? HGRP_C_RED : HGRP_C_GREEN));
   PillRO("PILL_SWS", pillX + half + 4, sy + 1, half,
          DoubleToString(sw_short, 2), (sw_short < 0 ? HGRP_C_RED : HGRP_C_GREEN));
   sy += HGRP_ROW_H;

   //--- per PS: dikali lot
   const double lots = g_result.PositionSize;

   RowLabel("LBL_SWVP", lblX, sy, "Per position");
   PillRO("PILL_SWLP", pillX, sy + 1, half,
          DoubleToString(sw_long * lots, 2), HGRP_C_TEXT);
   PillRO("PILL_SWSP", pillX + half + 4, sy + 1, half,
          DoubleToString(sw_short * lots, 2), HGRP_C_TEXT);

   //=== kartu 3: Catatan =====================================
   const int y3 = y2 + 118 + HGRP_CARD_GAP;
   Card("CARD_SWN", x0, y3, cardW, 46, "");

   Label("SWN_TXT", lblX, y3 + 10,
         "Long = biaya (negatif), Short = kredit. Nilai dari spesifikasi simbol.",
         HGRP_C_MUTED, 7);
  }


//+------------------------------------------------------------------+
//| Tab TRADING — eksekusi, batas, TP share, opsi order, footer.      |
//| Catatan: tab ini hanya MENGATUR parameter. Tidak ada OrderSend.   |
//+------------------------------------------------------------------+
void HGRP_Panel::DrawTabTrading(const int y0, const int cardW)
  {
   const int x0    = HGRP_PAD_X;
   const int lblX  = x0 + HGRP_CARD_PAD;
   const int pillX = lblX + 100;
   const int pillW = HGRP_PILL_W - 6;
   const int half  = (pillW - 4) / 2;

   //=== kartu 1: Eksekusi ====================================
   Card("CARD_EXEC", x0, y0, cardW, 100, "EKSEKUSI");

   int ry = y0 + HGRP_SEC_H + 8;

   RowLabel("LBL_TRAIL", lblX, ry, "Trailing stop");
   Edit("EDT_TRAIL", pillX, ry + 1, 48, HGRP_PILL_H,
        IntegerToString(g_sets.TrailingStop));
   Label("LBL_BE", pillX + 52, ry + 6, "BE", HGRP_C_MUTED, 7);
   Edit("EDT_BE", pillX + 66, ry + 1, 46, HGRP_PILL_H,
        IntegerToString(g_sets.Breakeven));
   ry += HGRP_ROW_H;

   RowLabel("LBL_MAGIC", lblX, ry, "Magic number");
   Edit("EDT_MAGIC", pillX, ry + 1, pillW, HGRP_PILL_H,
        IntegerToString(g_sets.MagicNumber));
   ry += HGRP_ROW_H;

   RowLabel("LBL_COMMENT", lblX, ry, "Commentary");
   Edit("EDT_COMMENT", pillX, ry + 1, pillW - 24, HGRP_PILL_H, g_sets.Commentary);
   Btn("BTN_SUFFIX", pillX + pillW - 22, ry + 1, 22, "#", true);

   //=== kartu 2: Batas =======================================
   const int y2 = y0 + 100 + HGRP_CARD_GAP;
   Card("CARD_LIM", x0, y2, cardW, 92, "BATAS (MAX PARAMETERS)");

   int ly = y2 + HGRP_SEC_H + 6;

   Label("LIM_H1", pillX + 4,         ly + 2, "Total",      HGRP_C_MUTED, 7);
   Label("LIM_H2", pillX + half + 8,  ly + 2, "Per symbol", HGRP_C_MUTED, 7);
   ly += 16;

   RowLabel("LBL_MAXTR", lblX, ly, "Max trades");
   Edit("EDT_MAXTR_T", pillX, ly + 1, half, HGRP_PILL_H, "0");
   Edit("EDT_MAXTR_S", pillX + half + 4, ly + 1, half, HGRP_PILL_H, "0");
   ly += HGRP_ROW_H;

   RowLabel("LBL_MAXVOL", lblX, ly, "Max volume");
   Edit("EDT_MAXVOL_T", pillX, ly + 1, half, HGRP_PILL_H, "0.00");
   Edit("EDT_MAXVOL_S", pillX + half + 4, ly + 1, half, HGRP_PILL_H, "0.00");

   //=== kartu 3: Take-profit share ===========================
   //--- tinggi kartu mengikuti jumlah TP (1 baris TP + share per TP)
   const int share_rows = MathMax(m_st.tps, 1);
   const int shareH     = HGRP_SEC_H + 6 + HGRP_ROW_H + share_rows * HGRP_ROW_H + 8;

   const int y3 = y2 + 92 + HGRP_CARD_GAP;
   Card("CARD_SHARE", x0, y3, cardW, shareH, "TAKE-PROFIT SHARE");

   int sy = y3 + HGRP_SEC_H + 6;

   Btn("BTN_DISABLE", lblX, sy + 1, 14, "x", false);
   Label("LBL_DISABLE", lblX + 18, sy + 6,
         "Disable trading when lines hidden", HGRP_C_MUTED, 7);
   sy += HGRP_ROW_H;

   //--- satu baris per TP: harga (read-only) | porsi %
   for(int i = 1; i <= share_rows; i++)
     {
      const string s = IntegerToString(i);

      RowLabel("LBL_TP" + s, lblX, sy, "TP " + s);
      PillRO("PILL_TP" + s, pillX, sy + 1, half,
             DoubleToString(HGRP_TPLevelAt(i - 1), _Digits), HGRP_C_TEXT);
      Edit("EDT_TP" + s + "SHARE", pillX + half + 4, sy + 1, half, HGRP_PILL_H,
           IntegerToString(g_sets.TPShare[i - 1]));
      sy += HGRP_ROW_H;
     }

   //=== kartu 4: Opsi order ==================================
   const int y4 = y3 + shareH + HGRP_CARD_GAP;
   Card("CARD_OPT", x0, y4, cardW, 96, "OPSI ORDER");

   int oy = y4 + HGRP_SEC_H + 4;

   Btn("BTN_SUBPOS", lblX, oy + 1, 14, "x", false);
   Label("LBL_SUBPOS", lblX + 18, oy + 6, "Subtract open positions volume",
         HGRP_C_MUTED, 7);
   oy += 18;

   Btn("BTN_SUBORD", lblX, oy + 1, 14, "x", false);
   Label("LBL_SUBORD", lblX + 18, oy + 6, "Subtract pending orders volume",
         HGRP_C_MUTED, 7);
   oy += 18;

   Btn("BTN_NOSL", lblX, oy + 1, 14, "x", false);
   Label("LBL_NOSL", lblX + 18, oy + 6, "Do not apply stop-loss",
         HGRP_C_MUTED, 7);
   oy += 18;

   Btn("BTN_NOTP", lblX, oy + 1, 14, "x", false);
   Label("LBL_NOTP", lblX + 18, oy + 6, "Do not apply take-profit",
         HGRP_C_MUTED, 7);
  }


//+------------------------------------------------------------------+
//| Handle drag: satu-satunya objek HGRP_ dengan OBJPROP_BACK == true.|
//| Dikenali lewat flag itu, jadi tidak perlu daftar nama.           |
//+------------------------------------------------------------------+
void HGRP_Panel::DragHandle(void)
  {
   //--- Lebar: penuh sampai sebelum tombol kanan (+, -) supaya tombol tetap
   //    bisa diklik. Handle yang menutupi tombol akan menelan klik dan
   //    membuat panel tidak bisa di-restore setelah minimize.
   const int w = m_w - HGRP_PAD_X * 2 - 76;

   //--- Tinggi: hanya judul, bukan judul + tab. Tab punya tombol sendiri
   //    (Main/Risk/Margin/Swaps/Trading) yang juga tidak boleh tertutup.
   const int h = HGRP_TITLE_H + 2;

   if(w <= 0 || h <= 0)
      return;

   //--- handle drag: rectangle dengan latar transparan.
   //    CATATAN: jangan pakai OBJPROP_COLOR = clrNONE di sini. Pada beberapa
   //    build MT5 kombinasi clrNONE + OBJPROP_BACK membuat chart repaint
   //    terus-menerus. Handle tetap tak terlihat karena warnanya sama dengan
   //    latar panel, dan tetap klikable karena paling belakang.
   const string obj = HGRP_PREFIX + "DRAG";

   Rect("DRAG", HGRP_PAD_X - 4, HGRP_PAD_T - 4, w, h, HGRP_C_BG, HGRP_C_BG);

   ObjectSetInteger(m_chart, obj, OBJPROP_BACK, true);
   ObjectSetInteger(m_chart, obj, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(m_chart, obj, OBJPROP_COLOR, HGRP_C_BG);
   ObjectSetInteger(m_chart, obj, OBJPROP_BGCOLOR, HGRP_C_BG);
   ObjectSetInteger(m_chart, obj, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
//| Geser panel dengan memindahkan objek, tanpa rebuild.             |
//| Hanya objek milik panel (HGRP_) — garis HGRPL_ TIDAK ikut, jadi  |
//| level SL/TP tidak bergeser saat panel dipindah.                  |
//| Loop dibatasi: ObjectName() + StringFind per objek per pixel     |
//| gerakan mouse akan membanjiri thread chart dan membekukan MT5.   |
//+------------------------------------------------------------------+
void HGRP_Panel::Shift(const int dx, const int dy)
  {
   if(dx == 0 && dy == 0)
      return;

   m_x += dx;
   m_y += dy;

   const int pfx_len = StringLen(HGRP_PREFIX);
   const int total   = ObjectsTotal(m_chart, -1, -1);

   for(int i = total - 1; i >= 0; i--)
     {
      const string name = ObjectName(m_chart, i, -1, -1);

      if(StringLen(name) < pfx_len || StringFind(name, HGRP_PREFIX) != 0)
         continue;

      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE,
                       ObjectGetInteger(m_chart, name, OBJPROP_XDISTANCE) + dx);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE,
                       ObjectGetInteger(m_chart, name, OBJPROP_YDISTANCE) + dy);
     }

   ChartRedraw(m_chart);
  }

//+------------------------------------------------------------------+
//| Set posisi. Shift() dan ClampToChart() sama-sama memindahkan objek,|
//| jadi keduanya dipanggil sekali di sini — bukan secara rekursif.    |
//+------------------------------------------------------------------+
void HGRP_Panel::SetPos(const int x, const int y)
  {
   if(x == m_x && y == m_y)
      return;

   Shift(x - m_x, y - m_y);
   ClampToChart();
  }

//+------------------------------------------------------------------+
//| Tarik panel kembali ke layar setelah chart di-resize.            |
//| Hanya memindahkan SATU kali: Shift() di dalam loop bisa membuat  |
//| posisi berayun antara dua nilai dan menggantung thread chart.    |
//+------------------------------------------------------------------+
void HGRP_Panel::ClampToChart(void)
  {
   const int cw = (int)ChartGetInteger(m_chart, CHART_WIDTH_IN_PIXELS);
   const int ch = (int)ChartGetInteger(m_chart, CHART_HEIGHT_IN_PIXELS);

   if(cw <= 0 || ch <= 0)
      return;

   //--- tinggi dipakai untuk mencegah panel keluar dari bawah, tetapi
   //    tidak boleh lebih besar dari chart itu sendiri (panel besar di
   //    chart kecil akan menghasilkan batas negatif).
   const int usable_h = MathMin(m_h, ch);
   const int min_y    = 0;
   const int max_y    = MathMax(min_y, ch - usable_h);
   const int max_x    = MathMax(0, cw - 60);

   const int ny = (int)MathMin(MathMax(m_y, min_y), max_y);
   const int nx = (int)MathMin(MathMax(m_x, 0), max_x);

   if(nx != m_x || ny != m_y)
      Shift(nx - m_x, ny - m_y);
  }

//+------------------------------------------------------------------+
//| Taruh panel di tengah chart — fungsi HGRP_BTN_CENTER.            |
//+------------------------------------------------------------------+
void HGRP_Panel::SnapToCenter(void)
  {
   const int cw = (int)ChartGetInteger(m_chart, CHART_WIDTH_IN_PIXELS);
   const int ch = (int)ChartGetInteger(m_chart, CHART_HEIGHT_IN_PIXELS);

   if(cw <= 0 || ch <= 0)
      return;

   const int x = MathMax(0, (cw - m_w) / 2);
   const int y = MathMax(0, (ch - m_h) / 2);

   SetPos(x, y);
  }

//+------------------------------------------------------------------+
//| Buat panel.                                                       |
//+------------------------------------------------------------------+
bool HGRP_Panel::Create(const long chart, const int x, const int y)
  {
   m_chart = chart;
   m_x = x;
   m_y = y;

   Redraw();
   ChartRedraw(m_chart);

   return(true);
  }

//+------------------------------------------------------------------+
//| Hapus semua objek HGRP_ dan HGRPL_.                               |
//+------------------------------------------------------------------+
void HGRP_Panel::Destroy(void)
  {
   ObjectsDeleteAll(m_chart, HGRP_PREFIX);
   ObjectsDeleteAll(m_chart, HGRPL_PREFIX);
   ChartRedraw(m_chart);
  }

//+------------------------------------------------------------------+
//| Ganti tab lalu gambar ulang.                                      |
//+------------------------------------------------------------------+
void HGRP_Panel::SetTab(const int tab)
  {
   if(tab < 0 || tab >= HGRP_TAB_COUNT)
      return;

   m_active_tab = tab;
   Redraw();
   ChartRedraw(m_chart);
  }

//+------------------------------------------------------------------+
//| Arah trade: ubah warna header tidak diperlukan, cukup state.      |
//+------------------------------------------------------------------+
void HGRP_Panel::SetDirection(const int dir)
  {
   m_st.direction = dir;
  }

//+------------------------------------------------------------------+
//| Tulis hasil engine ke objek panel (tanpa gambar ulang penuh).     |
//+------------------------------------------------------------------+
void HGRP_Panel::UpdateResults(const double position_size,
                               const double risk_money,
                               const double display_risk,
                               const double reward_money,
                               const double rr,
                               const double margin,
                               const double used_margin,
                               const double free_margin,
                               const double max_ps_margin,
                               const bool   valid)
  {
   const int dig   = g_sym.AccountCurrencyDigits;
   const int lotd  = g_sym.LotStepDigits;
   const color ps_c = (valid ? HGRP_C_TEAL : HGRP_C_RED);

   const string s_ps  = DoubleToString(position_size, lotd);
   const string s_ris = DoubleToString(risk_money, dig);
   const string s_rd  = DoubleToString(display_risk, 2);
   const string s_rew = DoubleToString(reward_money, dig);
   const string s_mrg = DoubleToString(margin, dig);
   const string s_umr = DoubleToString(used_margin, dig);
   const string s_fmr = DoubleToString(free_margin, dig);
   const string s_mps = DoubleToString(max_ps_margin, lotd);

   WriteText("PILL_PS",    s_ps);
   WriteText("POT_LOTS",   s_ps);
   WriteText("PILL_RISKP", s_rd);
   WriteText("PILL_RISKM", s_ris);
   WriteText("PILL_RR",    DoubleToString(rr, 2));
   WriteText("POT_RISK",   s_ris);
   WriteText("POT_RISKP",  s_rd);
   WriteText("PILL_REWARD", s_rew);
   WriteText("POT_REW",    s_rew);
   WriteText("POT_PRRR",   DoubleToString(rr, 2));
   WriteText("PILL_POSM",  s_mrg);
   WriteText("PILL_USEDM", s_umr);
   WriteText("PILL_FREEM", s_fmr);
   WriteText("PILL_MAXPS", s_mps);

   ObjectSetInteger(m_chart, HGRP_PREFIX + "PILL_PS", OBJPROP_COLOR, ps_c);
   ObjectSetInteger(m_chart, HGRP_PREFIX + "POT_LOTS", OBJPROP_COLOR, ps_c);
   ObjectSetInteger(m_chart, HGRP_PREFIX + "PILL_RR", OBJPROP_COLOR,
                    (rr >= 1.0 ? HGRP_C_GREEN : HGRP_C_TEXT));
   ObjectSetInteger(m_chart, HGRP_PREFIX + "PILL_FREEM", OBJPROP_COLOR,
                    (free_margin >= 0 ? HGRP_C_GREEN : HGRP_C_RED));
  }

//+------------------------------------------------------------------+
//| Baca teks objek apa pun (EDIT maupun LABEL).                      |
//+------------------------------------------------------------------+
string HGRP_Panel::ReadText(const string name) const
  {
   return(ObjectGetString(m_chart, HGRP_PREFIX + name, OBJPROP_TEXT));
  }

//+------------------------------------------------------------------+
//| Baca angka dari objek EDIT. StringToDouble aman untuk teks kosong.|
//+------------------------------------------------------------------+
double HGRP_Panel::ReadNumber(const string name) const
  {
   return(StringToDouble(ReadText(name)));
  }

//+------------------------------------------------------------------+
//| Tulis teks ke objek. Aman bila objek belum ada.                   |
//+------------------------------------------------------------------+
void HGRP_Panel::WriteText(const string name, const string value)
  {
   const string obj = HGRP_PREFIX + name;

   if(ObjectFind(m_chart, obj) >= 0)
      ObjectSetString(m_chart, obj, OBJPROP_TEXT, value);
  }


//+------------------------------------------------------------------+
//| Tangani klik. Mengembalikan true bila objek ini milik panel.      |
//| Pemanggil (EA) yang menjalankan recompute setelah true.           |
//+------------------------------------------------------------------+
bool HGRP_Panel::OnClick(const string obj)
  {
   if(StringFind(obj, HGRP_PREFIX) != 0)
      return(false);

   const string n = StringSubstr(obj, StringLen(HGRP_PREFIX));

   //--- tab
   if(StringFind(n, "TAB_") == 0)
     {
      string tail = StringSubstr(n, 4);
      if(StringFind(tail, "BG_") == 0)
         tail = StringSubstr(tail, 3);

      const int tab = (int)StringToInteger(tail);
      if(tab >= 0 && tab < HGRP_TAB_COUNT)
         SetTab(tab);

      return(true);
     }

   //--- Long / Short
   if(n == "SEG_DIR_0" || n == "SEG_DIR_BG_0")
     {
      m_st.direction = POSITION_TYPE_BUY;
      Redraw();
      return(true);
     }
   if(n == "SEG_DIR_1" || n == "SEG_DIR_BG_1")
     {
      m_st.direction = POSITION_TYPE_SELL;
      Redraw();
      return(true);
     }

   //--- Order type
   for(int i = 0; i < 3; i++)
     {
      if(n == "SEG_ORDER_" + IntegerToString(i) ||
         n == "SEG_ORDER_BG_" + IntegerToString(i))
        {
         m_st.order_type = i;
         Redraw();
         return(true);
        }
     }
   //--- Filter portofolio di tab Risk
   for(int i = 0; i < 3; i++)
     {
      const string sfx = "_" + IntegerToString(i);

      if(n == "SEG_RGPORD" + sfx || n == "SEG_RGPORD_BG" + sfx)
        {
         m_st.f_orders = i;
         Redraw();
         return(true);
        }
      if(n == "SEG_RGPSYM" + sfx || n == "SEG_RGPSYM_BG" + sfx)
        {
         m_st.f_symbols = i;
         Redraw();
         return(true);
        }
      if(n == "SEG_RGPDIR" + sfx || n == "SEG_RGPDIR_BG" + sfx)
        {
         m_st.f_dir = i;
         Redraw();
         return(true);
        }
     }

   //--- abaikan posisi tanpa stop-loss
   if(n == "BTN_IGN_SL" || n == "BTN_IGN_SL_BG")
     {
      m_st.f_ignore_nosl = !m_st.f_ignore_nosl;
      Redraw();
      return(true);
     }

   //--- abaikan order tanpa take-profit (spec rowsRisk :452)
   if(n == "BTN_IGN_TP" || n == "BTN_IGN_TP_BG")
     {
      m_st.f_ignore_notp = !m_st.f_ignore_notp;
      Redraw();
      return(true);
     }

   //--- Commission % / $
   if(n == "SEG_COMMTYPE_0" || n == "SEG_COMMTYPE_BG_0")
     {
      m_st.commission_pct = true;
      Redraw();
      return(true);
     }
   if(n == "SEG_COMMTYPE_1" || n == "SEG_COMMTYPE_BG_1")
     {
      m_st.commission_pct = false;
      Redraw();
      return(true);
     }

   //--- komisi otomatis dari aturan broker
   if(n == "BTN_AUTOCOMM" || n == "BTN_AUTOCOMM_BG")
     {
      m_st.auto_comm = !m_st.auto_comm;
      Redraw();
      return(true);
     }

   //--- TP count
   if(n == "BTN_TPN" || n == "BTN_TPN_BG")
     {
      m_st.tps++;
      if(m_st.tps > 3)
         m_st.tps = 1;

      //--- TP baru: isi harga & porsi agar tidak kosong saat muncul.
      //    Harga = kelipatan TP1 dari entry, porsi dibagi rata.
      SeedTakeProfits();

      Redraw();
      return(true);
     }

   //--- SA (spread adjustment)
   if(n == "BTN_SL_SA" || n == "BTN_SL_SA_BG")
     {
      m_st.spread_adj = !m_st.spread_adj;
      Redraw();
      return(true);
     }

   //--- minimize / restore
   if(n == "BTN_MIN" || n == "BTN_MIN_BG")
     {
      const int old_h = m_h;

      m_minimized = !m_minimized;
      Redraw();          // DrawFrame() menghitung ulang m_h

      //--- panel mengecil/membesar: jaga agar tetap di dalam chart.
      //    Tanpa ini panel bisa berakhir di luar layar setelah restore.
      const int delta = m_h - old_h;
      if(delta != 0 && m_y + m_h > (int)ChartGetInteger(m_chart, CHART_HEIGHT_IN_PIXELS))
         SetPos(m_x, MathMax(0, m_y - delta));

      ClampToChart();
      return(true);
     }

   //--- taruh panel di tengah chart
   if(n == "BTN_CENTER" || n == "BTN_CENTER_BG")
     {
      SnapToCenter();
      return(true);
     }

   //--- Lock: TP mengikuti SL. State dibaca EA lewat State().tp_locked
   if(n == "BTN_TP_LOCK" || n == "BTN_TP_LOCK_BG")
     {
      m_st.tp_locked = !m_st.tp_locked;
      Redraw();
      return(true);
     }

   //--- Hide lines: sembunyikan / tampilkan garis level di chart
   if(n == "BTN_HIDE" || n == "BTN_HIDE_BG")
     {
      m_st.hide_lines = !m_st.hide_lines;
      HGRP_ShowLines(m_chart, !m_st.hide_lines);
      Redraw();
      return(true);
     }

   //--- semua tombol lain dianggap "butuh recompute"
   if(StringFind(n, "BTN_") == 0)
      return(true);

   //--- input yang diedit: butuh recompute
   if(StringFind(n, "EDT_") == 0)
      return(true);

   return(true);
  }

#endif // HGRP_PANEL_MQH
