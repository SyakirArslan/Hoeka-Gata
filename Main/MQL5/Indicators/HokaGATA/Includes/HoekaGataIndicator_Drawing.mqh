// HokaGATA Engulfing Breakout MT5
// Drawing helpers: Entry / SL / TP / Body-Break lines and labels.
// Mirrors .pine: CREATE NEW SETUP / EXTEND ACTIVE SETUP / FREEZE COMPLETED SETUP.

struct EngulfSetup
{
   int    dir;
   int    setupBar;
   int    entryBar;
   double pBreak;
   double pEntry;
   double pSL;
   double pTP;
   string lnE;
   string lnS;
   string lnT;
   string lbE;
   string lbS;
   string lbT;
   string lnBody;
   string lbBody;
};

ENUM_LINE_STYLE EngulfLineStyle()
{
   return InpLineStyle == LineSolid ? STYLE_SOLID : STYLE_DASH;
}

ENUM_LINE_STYLE EngulfBodyBreakStyle()
{
   if(InpBodyBreakStyle == BodyBreakDotted)
      return STYLE_DOT;
   if(InpBodyBreakStyle == BodyBreakDashed)
      return STYLE_DASH;
   return STYLE_SOLID;
}

// .pine: labelSize = Tiny/Small/Normal/Large -> size.tiny/small/normal/large
int EngulfFontSize(const EngulfLabelSize size)
{
   if(size == EngulfTiny)
      return 7;
   if(size == EngulfNormal)
      return 11;
   if(size == EngulfLarge)
      return 14;
   return 9;
}

// Maps bar index to chart time; future bars are extrapolated.
datetime EngulfTimeAt(const datetime &time[], const int rates_total, const int index)
{
   if(index < 0)
      return time[0];

   if(index < rates_total)
      return time[index];

   int sec = PeriodSeconds(_Period);
   if(sec <= 0)
      sec = 60;

   return (datetime)(time[rates_total - 1] + (long)(index - (rates_total - 1)) * sec);
}

void EngulfMakeLine(const string name, const int x1, const double y1, const int x2, const double y2,
                    const color clr, const ENUM_LINE_STYLE style, const int rates_total, const datetime &time[])
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_TREND, 0,
                EngulfTimeAt(time, rates_total, x1), y1,
                EngulfTimeAt(time, rates_total, x2), y2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void EngulfSetLineX2(const string name, const int x2, const double y2, const int rates_total, const datetime &time[])
{
   if(name == "" || ObjectFind(0, name) < 0)
      return;
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, EngulfTimeAt(time, rates_total, x2));
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, y2);
}

void EngulfSetLineStyle(const string name, const ENUM_LINE_STYLE style)
{
   if(name == "" || ObjectFind(0, name) < 0)
      return;
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
}

void EngulfSetLineColor(const string name, const color clr)
{
   if(name == "" || ObjectFind(0, name) < 0)
      return;
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

// .pine: label.new(..., style=label.style_label_left, color=transparentLabel)
void EngulfMakeLabel(const string name, const int x, const double y, const string text,
                     const color textColor, const EngulfLabelSize size,
                     const int rates_total, const datetime &time[])
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_TEXT, 0, EngulfTimeAt(time, rates_total, x), y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, EngulfFontSize(size));
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   // .pine label.style_label_left -> text sits to the LEFT of the anchor point.
   // The anchor is the LOWER-right corner, not the middle-right one: the level
   // line is drawn at exactly this price, so a middle anchor put the line
   // straight through the glyphs ("SL 4124.25", "BREAK BODY", "SELL TP ...").
   // OBJ_TEXT has no background colour in MQL5, so the label has to sit ABOVE
   // its own line. The offset comes from the font box, not from a price delta,
   // so it stays correct at every zoom level. Text objects also take part in the
   // chart auto-scale, so the top-most label cannot be clipped.
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void EngulfSetLabelX(const string name, const int x, const double y, const int rates_total, const datetime &time[])
{
   if(name == "" || ObjectFind(0, name) < 0)
      return;
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, EngulfTimeAt(time, rates_total, x));
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, y);
}

void EngulfSetLabelText(const string name, const string text, const color clr, const EngulfLabelSize size)
{
   if(name == "" || ObjectFind(0, name) < 0)
      return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, EngulfFontSize(size));
}

void EngulfDeleteObject(const string name)
{
   if(name == "" || ObjectFind(0, name) < 0)
      return;
   ObjectDelete(0, name);
}

void EngulfDeleteByPrefix(const string prefix)
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

// Same as EngulfDeleteByPrefix(), but never touches objects whose name starts
// with `keep`. Used for the stats panel: MT5 recalculates the indicator every
// time horizontal scrolling pulls older history in, and wiping the table on each
// of those recalcs made the whole frame blink out for the duration of the
// rebuild. EngulfDrawPanel() refreshes the panel in place, so the objects only
// have to be created once (and they are still removed by OnDeinit).
void EngulfDeleteByPrefixExcept(const string prefix, const string keep)
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, prefix) != 0)
         continue;
      if(keep != "" && StringFind(name, keep) == 0)
         continue;
      ObjectDelete(0, name);
   }
}

string EngulfPriceText(const double price)
{
   return DoubleToString(price, _Digits);
}

// .pine: f_prob(_wins, _closed) = closed > 0 ? str.tostring(v,"#.##") + "%" : "n/a"
string EngulfFormatProb(const int wins, const int closed)
{
   if(closed <= 0)
      return "n/a";

   double pct = (double)wins / (double)closed * 100.0;
   string text = DoubleToString(pct, 2);

   if(StringFind(text, ".") >= 0)
   {
      while(StringLen(text) > 0 && StringGetCharacter(text, StringLen(text) - 1) == '0')
         text = StringSubstr(text, 0, StringLen(text) - 1);
      if(StringLen(text) > 0 && StringGetCharacter(text, StringLen(text) - 1) == '.')
         text = StringSubstr(text, 0, StringLen(text) - 1);
   }

   return text + "%";
}

// Risk:reward label for the panel. Drops redundant trailing zeros the same way
// EngulfFormatProb() does so "2.0" renders as "1:2" like the mockup.
string EngulfFormatRatio(const double rr)
{
   string text = DoubleToString(rr, 2);

   if(StringFind(text, ".") >= 0)
   {
      while(StringLen(text) > 0 && StringGetCharacter(text, StringLen(text) - 1) == '0')
         text = StringSubstr(text, 0, StringLen(text) - 1);
      if(StringLen(text) > 0 && StringGetCharacter(text, StringLen(text) - 1) == '.')
         text = StringSubstr(text, 0, StringLen(text) - 1);
   }

   return "1:" + text;
}
