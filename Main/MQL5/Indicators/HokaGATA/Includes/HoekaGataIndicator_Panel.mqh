// HokaGATA Engulfing Breakout MT5
// Results panel: 2-column statistics table with a FULLY TRANSPARENT background.
// Mirrors .pine RESULTS PANEL.
//
// Transparency in MT5:
//   * OBJ_RECTANGLE_LABEL has no alpha channel. OBJPROP_BGCOLOR = clrNONE means
//     "do not fill the interior", so the chart background shows straight through.
//   * The outline is still drawn because OBJPROP_BORDER_TYPE = BORDER_FLAT uses
//     OBJPROP_COLOR independently of BGCOLOR. That gives a border-only frame.
//   * OBJ_LABEL text is always opaque, so the panel text stays white and is
//     intended for a dark chart theme.

struct EngulfStats
{
   int nSig;
   int nRun;
   int nWin;
   int nLos;
   int nCancelled;
   int nBuyRun;
   int nSellRun;
   int buyWins;
   int buyLoss;
   int sellWins;
   int sellLoss;
   int maxTPStreak;
   int maxSLStreak;
   int state;
};

// Last snapshot handed to EngulfDrawPanel(). MT5 does not call OnCalculate when
// the user scrolls, zooms or resizes the chart, so the CHARTEVENT_CHART_CHANGE
// repaint needs the numbers without re-running the whole engine.
EngulfStats LastPanelStats;
bool        HasLastPanelStats = false;

// Snapshot the panel objects currently show. EngulfDrawPanel() compares against
// it so an unchanged result does not refresh ~35 labels (11 ObjectSet* each) on
// every recalculation.
EngulfStats PanelPaintedStats;
bool        PanelHasPainted = false;

bool EngulfStatsEqual(const EngulfStats &a, const EngulfStats &b)
{
   return a.nSig        == b.nSig
       && a.nRun        == b.nRun
       && a.nWin        == b.nWin
       && a.nLos        == b.nLos
       && a.nCancelled  == b.nCancelled
       && a.nBuyRun     == b.nBuyRun
       && a.nSellRun    == b.nSellRun
       && a.buyWins     == b.buyWins
       && a.buyLoss     == b.buyLoss
       && a.sellWins    == b.sellWins
       && a.sellLoss    == b.sellLoss
       && a.maxTPStreak == b.maxTPStreak
       && a.maxSLStreak == b.maxSLStreak
       && a.state       == b.state;
}

// .pine: position.top_right, 2 columns
// 13 rows inside the frame: title, byline, SETUP, 3 setup rows, RESULTS,
// 6 result rows. The Probability footer is NOT a row - it is a separate
// framed box drawn directly below the panel.
const int PANEL_ROWS = 13;

// ---- LOCKED LAYOUT -------------------------------------------------------
// Compact table (option A): 20px horizontal / 10px vertical padding,
// 16px row pitch, 8pt body text / 9pt title. InpPanelSize no longer affects
// the panel (it still drives the chart SL/TP labels through EngulfFontSize).
const int PANEL_PANEL_W   = 180;  // total panel width
const int PANEL_PAD_X     = 20;   // inner left/right padding
const int PANEL_PAD_Y     = 10;   // inner top/bottom padding
const int PANEL_MARGIN_X  = 12;   // distance from the right chart edge
const int PANEL_MARGIN_Y  = 12;   // distance from the top chart edge
const int PANEL_FONT_BODY = 8;    // body font size (pt)
const int PANEL_FONT_HEAD = 9;    // title font size (pt)
const int PANEL_LINE_H    = 16;   // row pitch

// Body text is ~11px tall, so a 16px row slot leaves 2px above and below. Every
// cell takes this offset so all rows share one baseline (the mockup relies on
// CSS line-height:16px). Centred rows use ANCHOR_UPPER - horizontal centre with
// a vertical TOP anchor - because ANCHOR_CENTER treats Y as the MIDDLE of the
// text, which lifts those rows ~5px above their neighbours and makes e.g.
// RESULTS collide with the Cancel row above it.
const int PANEL_TEXT_DY = 2;

// ---- MOCKUP-SYNCED GEOMETRY ----------------------------------------------
// Mirrors Main/Docs/panel-mockup.html exactly.
//   * subtitle row ("by Syakir Arslan") is 6px taller so its underline sits
//     6px below the text baseline instead of hugging it;
//   * 4px extra space between the author rule and the SETUP header;
//   * the Probability footer is its own 1px-framed box, 6px below the panel.
const int PANEL_SUBTITLE_GAP = 6;   // extra height of the byline row
const int PANEL_SECTION_GAP  = 4;   // space between author rule and SETUP
const int PANEL_FOOTER_GAP   = 6;   // space between panel and footer box
const int PANEL_FOOTER_H     = 20;  // footer box height (1px frame + 3px pad + 12px text + 3px pad + 1px frame)

// Row indices. The Probability footer is NOT a row - it is a separate box.
const int PANEL_ROW_TITLE    = 0;
const int PANEL_ROW_SUBTITLE = 1;
const int PANEL_ROW_SETUP    = 2;
const int PANEL_ROW_RR       = 3;
const int PANEL_ROW_STATUS   = 4;
const int PANEL_ROW_CANCEL   = 5;
const int PANEL_ROW_RESULTS  = 6;
const int PANEL_ROW_SIGNALS  = 7;
const int PANEL_ROW_RUNS     = 8;
const int PANEL_ROW_BUY      = 9;
const int PANEL_ROW_SELL     = 10;
const int PANEL_ROW_TPSTREAK = 11;
const int PANEL_ROW_SLSTREAK = 12;

// Neutral grey that stays visible on both dark and light chart themes.
const color PANEL_BORDER = C'70,70,70';
const color PANEL_HEADER = C'255,255,255';
const color PANEL_RULE   = C'70,70,70';

int EngulfPanelLineHeight() { return PANEL_LINE_H; }

// Height of one row. Only the byline row is taller (PANEL_SUBTITLE_GAP) so its
// underline sits 6px below the text instead of hugging it.
int EngulfPanelRowHeight(const int row)
{
   if(row == PANEL_ROW_SUBTITLE)
      return PANEL_LINE_H + PANEL_SUBTITLE_GAP;
   return PANEL_LINE_H;
}

int EngulfPanelRowY(const int row)
{
   int y = PANEL_MARGIN_Y + PANEL_PAD_Y;
   for(int r = 0; r < row; r++)
      y += EngulfPanelRowHeight(r);
   if(row >= PANEL_ROW_SETUP)
      y += PANEL_SECTION_GAP;
   return y;
}

// Y of the separator rule drawn directly BELOW the given row.
// Equivalent to the top of the next row minus 1px.
int EngulfPanelRuleY(const int row)
{
   return EngulfPanelRowY(row) + EngulfPanelRowHeight(row) - 1;
}

// X of the panel's OUTER LEFT boundary: the distance from the chart's right
// edge to the left side of the frame. The left frame bar occupies the single
// pixel column [left - 1, left], so its own left edge is exactly this value.
// That matters because rectangle labels are anchored on their LEFT edge (see
// EngulfPanelBar) - the -1 that used to live here is now folded into the bar
// drawing instead, which keeps the label column one padding step inside the
// frame instead of one pixel inside it.
int EngulfPanelLeftX()
{
   return PANEL_MARGIN_X + PANEL_PANEL_W;
}

// Label column: left-aligned, one padding step inside the left frame bar.
int EngulfPanelLabelX()
{
   return EngulfPanelLeftX() - PANEL_PAD_X;
}

// Value column: right-aligned, one padding step inside the right frame bar.
int EngulfPanelValueX()
{
   return PANEL_MARGIN_X + PANEL_PAD_X;
}

// Centre of the panel. Used with ANCHOR_UPPER (horizontal centre + vertical top)
// so merged rows (title, subtitle, section headers) are horizontally centred
// inside the frame while still sitting on the same baseline as the data rows.
int EngulfPanelCenterX()
{
   return PANEL_MARGIN_X + PANEL_PANEL_W / 2;
}

// Total panel height: top padding + all rows + bottom padding.
// The frame bars are drawn ON the outermost pixel row/column, so they do not
// add to the height - they replace the first and last pixel of the box.
int EngulfPanelHeight()
{
   return PANEL_PAD_Y * 2 + PANEL_ROWS * PANEL_LINE_H
          + PANEL_SUBTITLE_GAP + PANEL_SECTION_GAP;
}

// Y of the top frame bar of the detached Probability footer box.
int EngulfPanelFooterY()
{
   return PANEL_MARGIN_Y + EngulfPanelHeight() + PANEL_FOOTER_GAP;
}

// Draws / updates a single text cell. Objects are reused when possible so the
// panel does not flicker; text, colour and size are refreshed every call.
void EngulfPanelCell(const int row, const int column, const string text,
                     const color textColor, const int anchor, const int x, const int y,
                     const int fontSize)
{
   string name = PREFIX + "PANEL_" + IntegerToString(row) + "_" + IntegerToString(column);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + PANEL_TEXT_DY);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

string EngulfStatusText(const int state)
{
   if(state == STATE_BUY_ACTIVE)
      return "BUY";
   if(state == STATE_SELL_ACTIVE)
      return "SELL";
   if(state == STATE_BUY_SETUP || state == STATE_BUY_ARMED)
      return "PENDING BUY";
   if(state == STATE_SELL_SETUP || state == STATE_SELL_ARMED)
      return "PENDING SELL";
   return "NONE";
}

color EngulfStatusColor(const int state)
{
   if(state == STATE_BUY_ACTIVE || state == STATE_BUY_SETUP || state == STATE_BUY_ARMED)
      return InpCBuyText;
   if(state == STATE_SELL_ACTIVE || state == STATE_SELL_SETUP || state == STATE_SELL_ARMED)
      return InpCSellText;
   return clrSilver;
}

// Draws one horizontal separator rule. A rule is a 1px-tall filled rectangle:
// it needs an opaque BGCOLOR to be visible, which is fine because only the
// PANEL body must stay transparent - the rule is just a line.
void EngulfPanelRule(const int row)
{
   string name = PREFIX + "PANEL_RULE" + IntegerToString(row);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   // Same fixed-anchor rule as EngulfPanelBar: XDISTANCE addresses the rule's
   // LEFT edge, so the left padding has to be added on top of the width.
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,
                    EngulfPanelValueX() + PANEL_PANEL_W - 2 * PANEL_PAD_X);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, EngulfPanelRuleY(row));
   ObjectSetInteger(0, name, OBJPROP_XSIZE, PANEL_PANEL_W - 2 * PANEL_PAD_X);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 1);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, PANEL_RULE);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, PANEL_RULE);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
}

// Removes every rule object, used when the table is switched off.
void EngulfPanelDeleteRules()
{
   for(int r = 0; r < PANEL_ROWS; r++)
      EngulfDeleteObject(PREFIX + "PANEL_RULE" + IntegerToString(r));
   EngulfDeleteObject(PREFIX + "PANEL_BAR_TOP");
   EngulfDeleteObject(PREFIX + "PANEL_BAR_BOT");
   EngulfDeleteObject(PREFIX + "PANEL_BAR_LFT");
   EngulfDeleteObject(PREFIX + "PANEL_BAR_RGT");
   EngulfDeleteObject(PREFIX + "PANEL_CAPTION");
   EngulfDeleteObject(PREFIX + "PANEL_FOOTER_TEXT");
   EngulfDeleteObject(PREFIX + "PANEL_BAR_FTOP");
   EngulfDeleteObject(PREFIX + "PANEL_BAR_FBOT");
   EngulfDeleteObject(PREFIX + "PANEL_BAR_FLFT");
   EngulfDeleteObject(PREFIX + "PANEL_BAR_FRGT");
}

// True when an object name belongs to the CURRENT panel layout. Anything else
// that still starts with PREFIX+"PANEL_" is a leftover from an older build.
bool EngulfPanelOwnsName(const string name)
{
   const string p = PREFIX + "PANEL_";

   if(name == p + "BAR_TOP"  || name == p + "BAR_BOT"  ||
      name == p + "BAR_LFT"  || name == p + "BAR_RGT"  ||
      name == p + "BAR_FTOP" || name == p + "BAR_FBOT" ||
      name == p + "BAR_FLFT" || name == p + "BAR_FRGT" ||
      name == p + "FOOTER_TEXT")
      return true;

   for(int r = 0; r < PANEL_ROWS; r++)
   {
      const string row = IntegerToString(r);

      if(name == p + row + "_0" || name == p + row + "_1")
         return true;
      if(name == p + "RULE" + row)
         return true;
   }

   return false;
}

// One-shot purge of panel objects the current layout no longer owns.
// Swapping a freshly compiled .ex5 into a running terminal does NOT call
// OnDeinit, so everything the previous build drew stays welded to the chart and
// is painted on top of the new palette. The retired PANEL_CAPTION title and the
// frame bars from the era when XDISTANCE pointed at the wrong edge both looked
// like a scrambled border, so they are removed before the first redraw.
//
// Returns true when something was removed, so the caller knows the on-screen
// cells may be incomplete and the "unchanged stats" shortcut must be skipped.
bool EngulfPanelPurgeStale()
{
   static bool done = false;

   if(done)
      return false;
   done = true;

   const string prefix = PREFIX + "PANEL_";
   string stale[];

   const int total = ObjectsTotal(0, -1, -1);

   for(int i = 0; i < total; i++)
   {
      const string nm = ObjectName(0, i, -1, -1);

      if(StringFind(nm, prefix) != 0 || EngulfPanelOwnsName(nm))
         continue;

      const int n = ArraySize(stale);
      ArrayResize(stale, n + 1);
      stale[n] = nm;
   }

   for(int i = 0; i < ArraySize(stale); i++)
      EngulfDeleteObject(stale[i]);

   return ArraySize(stale) > 0;
}

// Draws one filled rectangle in panel-corner coordinates. All four sides of the
// frame, the byline rule and the footer box are drawn through this helper,
// because a plain OBJ_RECTANGLE_LABEL with BGCOLOR=clrNONE renders no border at
// all on current MT5 builds - so the frame must be painted manually as 1px bars.
//
// CRITICAL: OBJ_RECTANGLE_LABEL has a FIXED ANCHOR_LEFT_UPPER anchor and
// OBJPROP_ANCHOR cannot be changed for it (MQL5 docs, ENUM_ANCHOR_POINT: "The
// OBJ_BUTTON, OBJ_RECTANGLE_LABEL, OBJ_EDIT and OBJ_CHART objects have a fixed
// anchor point in the upper left corner"). Combined with CORNER_RIGHT_UPPER
// that means XDISTANCE is the distance from the chart's right edge to the
// rectangle's LEFT edge, and the rectangle then grows RIGHTWARDS by XSIZE -
// i.e. off the chart. So a bar whose right edge must sit at xRight has to be
// placed at xRight + w, otherwise the whole frame is pushed past the right
// edge of the window and only a few stray 1px dashes stay visible.
//
// xRight = distance from the chart's RIGHT edge to the bar's right edge
// w      = bar width in px (1 for the frame sides)
void EngulfPanelBar(const string tag, const int xRight, const int y,
                    const int w, const int h, const color c)
{
   string name = PREFIX + "PANEL_BAR_" + tag;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xRight + w);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, c);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
}

// ---------------------------------------------------------------------------
// Probability footer: its own 1px-framed box sitting PANEL_FOOTER_GAP px below
// the panel. Mirrors the detached ".prob-below" box of the HTML mockup.
// ---------------------------------------------------------------------------
void EngulfPanelFooter(const string text)
{
   const int xRight = PANEL_MARGIN_X;
   const int xLeft  = PANEL_MARGIN_X + PANEL_PANEL_W - 1;
   const int yTop   = EngulfPanelFooterY();
   const int yBot   = yTop + PANEL_FOOTER_H - 1;
   const int innerH = PANEL_FOOTER_H - 2;

   EngulfPanelBar("FTOP", xRight, yTop,     PANEL_PANEL_W, 1,      PANEL_BORDER);
   EngulfPanelBar("FBOT", xRight, yBot,     PANEL_PANEL_W, 1,      PANEL_BORDER);
   EngulfPanelBar("FLFT", xLeft,  yTop + 1, 1,             innerH, PANEL_BORDER);
   EngulfPanelBar("FRGT", xRight, yTop + 1, 1,             innerH, PANEL_BORDER);

   string name = PREFIX + "PANEL_FOOTER_TEXT";

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, EngulfPanelCenterX());
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yTop + PANEL_FOOTER_H / 2);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, PANEL_FONT_HEAD);
   ObjectSetInteger(0, name, OBJPROP_COLOR, PANEL_HEADER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, "Probability: " + text);
}


void EngulfDrawPanel(const EngulfStats &stats, const bool force = false)
{
   // Drop leftovers from any earlier build before the first redraw, otherwise
   // they keep covering the freshly painted frame.
   const bool purged = EngulfPanelPurgeStale();

   if(!InpShowTable)
   {
      for(int r = 0; r < PANEL_ROWS; r++)
      {
         EngulfDeleteObject(PREFIX + "PANEL_" + IntegerToString(r) + "_0");
         EngulfDeleteObject(PREFIX + "PANEL_" + IntegerToString(r) + "_1");
      }
      EngulfPanelDeleteRules();
      return;
   }

   // Merged rows (title / byline / SETUP / RESULTS) only own column 0. Earlier
   // builds drew column 1 on some of them, so drop those leftovers once: a hot
   // .ex5 swap without detaching the indicator never runs OnDeinit, and the old
   // cells would otherwise stay glued to the chart forever.
   static bool mergedRowsCleaned = false;

   if(!mergedRowsCleaned)
   {
      EngulfDeleteObject(PREFIX + "PANEL_" + IntegerToString(PANEL_ROW_TITLE)    + "_1");
      EngulfDeleteObject(PREFIX + "PANEL_" + IntegerToString(PANEL_ROW_SUBTITLE) + "_1");
      EngulfDeleteObject(PREFIX + "PANEL_" + IntegerToString(PANEL_ROW_SETUP)    + "_1");
      EngulfDeleteObject(PREFIX + "PANEL_" + IntegerToString(PANEL_ROW_RESULTS)  + "_1");
      mergedRowsCleaned = true;
   }

   // Refresh only when the numbers actually moved: applying the same ~11
   // properties to ~35 label objects on every recalculation is by far the most
   // expensive part of the panel. Never skipped after a purge (the objects the
   // cells live in may be gone) and never skipped on the forced path, because
   // the scroll/zoom repaint relies on the properties being re-applied.
   if(!force && !purged && PanelHasPainted && EngulfStatsEqual(stats, PanelPaintedStats))
      return;

   int closedTrades = stats.nWin + stats.nLos;
   int closedBuy = stats.buyWins + stats.buyLoss;
   int closedSell = stats.sellWins + stats.sellLoss;

   // All text white so it stays readable on a dark chart theme.
   color neutralColor  = clrWhiteSmoke;
   color headerColor   = PANEL_HEADER;
   color positiveColor = InpCTP;
   color negativeColor = InpCSL;

   const int lx = EngulfPanelLabelX();
   const int vx = EngulfPanelValueX();
   const int cx = EngulfPanelCenterX();

   // ---- ROW 0 : title ------------------------------------------------------
   EngulfPanelCell(PANEL_ROW_TITLE, 0, "Engulfing Breakout", headerColor,
                   ANCHOR_UPPER, cx, EngulfPanelRowY(PANEL_ROW_TITLE), PANEL_FONT_HEAD);

   // ---- ROW 1 : author / subtitle -----------------------------------------
   EngulfPanelCell(PANEL_ROW_SUBTITLE, 0, "by Syakir Arslan", headerColor,
                   ANCHOR_UPPER, cx, EngulfPanelRowY(PANEL_ROW_SUBTITLE), PANEL_FONT_BODY);

   // ---- ROW 2 : SETUP header ----------------------------------------------
   EngulfPanelCell(PANEL_ROW_SETUP, 0, "SETUP", headerColor, ANCHOR_UPPER,
                   cx, EngulfPanelRowY(PANEL_ROW_SETUP), PANEL_FONT_BODY);

   // ---- ROW 3 : risk : reward ---------------------------------------------
   EngulfPanelCell(PANEL_ROW_RR, 0, "R:R", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_RR), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_RR, 1, EngulfFormatRatio(InpRrRatio), neutralColor,
                   ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_RR), PANEL_FONT_BODY);

   // ---- ROW 4 : status ----------------------------------------------------
   EngulfPanelCell(PANEL_ROW_STATUS, 0, "Status", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_STATUS), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_STATUS, 1, EngulfStatusText(stats.state), EngulfStatusColor(stats.state),
                   ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_STATUS), PANEL_FONT_BODY);

   // ---- ROW 5 : cancelled count -------------------------------------------
   EngulfPanelCell(PANEL_ROW_CANCEL, 0, "Cancel", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_CANCEL), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_CANCEL, 1, IntegerToString(stats.nCancelled), neutralColor,
                   ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_CANCEL), PANEL_FONT_BODY);

   // ---- ROW 6 : RESULTS header --------------------------------------------
   EngulfPanelCell(PANEL_ROW_RESULTS, 0, "RESULTS", headerColor, ANCHOR_UPPER,
                   cx, EngulfPanelRowY(PANEL_ROW_RESULTS), PANEL_FONT_BODY);

   // ---- ROW 7 : signals ----------------------------------------------------
   EngulfPanelCell(PANEL_ROW_SIGNALS, 0, "Signals", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_SIGNALS), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_SIGNALS, 1, IntegerToString(stats.nSig), neutralColor,
                   ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_SIGNALS), PANEL_FONT_BODY);

   // ---- ROW 8 : runs -------------------------------------------------------
   EngulfPanelCell(PANEL_ROW_RUNS, 0, "Runs", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_RUNS), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_RUNS, 1, IntegerToString(stats.nRun), neutralColor,
                   ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_RUNS), PANEL_FONT_BODY);

   // ---- ROW 9 : buy probability -------------------------------------------
   EngulfPanelCell(PANEL_ROW_BUY, 0, "Buy %", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_BUY), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_BUY, 1, EngulfFormatProb(stats.buyWins, closedBuy) +
                   " (" + IntegerToString(stats.nBuyRun) + ")",
                   InpCBuyText, ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_BUY), PANEL_FONT_BODY);

   // ---- ROW 10 : sell probability -----------------------------------------
   EngulfPanelCell(PANEL_ROW_SELL, 0, "Sell %", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_SELL), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_SELL, 1, EngulfFormatProb(stats.sellWins, closedSell) +
                   " (" + IntegerToString(stats.nSellRun) + ")",
                   InpCSellText, ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_SELL), PANEL_FONT_BODY);

   // ---- ROW 11 : TP streak ------------------------------------------------
   EngulfPanelCell(PANEL_ROW_TPSTREAK, 0, "TP Streak", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_TPSTREAK), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_TPSTREAK, 1, IntegerToString(stats.maxTPStreak), positiveColor,
                   ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_TPSTREAK), PANEL_FONT_BODY);

   // ---- ROW 12 : SL streak ------------------------------------------------
   EngulfPanelCell(PANEL_ROW_SLSTREAK, 0, "SL Streak", neutralColor, ANCHOR_LEFT_UPPER,
                   lx, EngulfPanelRowY(PANEL_ROW_SLSTREAK), PANEL_FONT_BODY);
   EngulfPanelCell(PANEL_ROW_SLSTREAK, 1, IntegerToString(stats.maxSLStreak), negativeColor,
                   ANCHOR_RIGHT_UPPER, vx, EngulfPanelRowY(PANEL_ROW_SLSTREAK), PANEL_FONT_BODY);

   // Probability lives in its own framed box below the panel, not in a row.
   EngulfPanelFooter(EngulfFormatProb(stats.nWin, closedTrades));

   // ---- SINGLE SEPARATOR RULE: only under the byline ----------------------
   // The mockup draws exactly one divider (border-bottom of .row.subtitle);
   // every other row has no rule, so the table stays clean and airy.
   EngulfPanelRule(PANEL_ROW_SUBTITLE);

   // ---- OUTER FRAME as 4 filled 1px bars -----------------------------------
   // OBJ_RECTANGLE_LABEL with clrNONE renders no border at all on current MT5
   // builds, so the frame is painted manually. Everything below is expressed in
   // columns counted LEFTWARDS from the right chart edge; EngulfPanelBar turns
   // the right-edge column into the XDISTANCE a rectangle actually needs.
   //
   //   xRight = 12                                  (right frame column)
   //   xLeft  = 12 + 180 - 1 = 191                  (left  frame column)
   //   yTop   = 12,  yBot = 12 + height - 1
   //
   // Horizontal bars span the full width INCLUDING both corner pixels; vertical
   // bars span only the interior height so corners are covered exactly once.
   // The frame occupies columns 12..192 => exactly PANEL_PANEL_W = 180 px.
   const int xRight = PANEL_MARGIN_X;
   const int xLeft  = PANEL_MARGIN_X + PANEL_PANEL_W - 1;
   const int yTop   = PANEL_MARGIN_Y;
   const int fh     = EngulfPanelHeight();
   const int yBot   = yTop + fh - 1;
   const int innerH = fh - 2;

   EngulfPanelBar("TOP", xRight, yTop,    PANEL_PANEL_W, 1,      PANEL_BORDER);
   EngulfPanelBar("BOT", xRight, yBot,    PANEL_PANEL_W, 1,      PANEL_BORDER);
   EngulfPanelBar("LFT", xLeft,  yTop + 1, 1,            innerH, PANEL_BORDER);
   EngulfPanelBar("RGT", xRight, yTop + 1, 1,            innerH, PANEL_BORDER);

   // Remember what is now on screen so the next call can short-circuit.
   PanelPaintedStats = stats;
   PanelHasPainted   = true;
}

// Repaints the panel from the cached snapshot without re-running the engine.
// Called from OnChartEvent() on CHARTEVENT_CHART_CHANGE / CHARTEVENT_MOUSE_WHEEL:
// corner-anchored objects are only re-composited on a full chart redraw, and a
// scroll does not produce a tick, so without this the table kept whatever frame
// the last tick painted and looked like it had disappeared.
void EngulfPanelRepaintCached()
{
   if(!HasLastPanelStats)
      return;

   // force = true: the numbers did not change, the chart did. Re-applying the
   // cell properties is what makes MT5 re-composite the corner-anchored objects
   // on the following ChartRedraw().
   EngulfDrawPanel(LastPanelStats, true);
}
