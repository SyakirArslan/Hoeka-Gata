// HokaGATA Wave 3 MT5
// Included by HoekaGataIndicator.mq5.

void Draw03Down(const int i0, const double p0, const int i1, const double p1, const int i2, const double p2, const int i3, const double p3, const bool showNeg027, const int rates_total, const datetime &time[])
{
   if(!InpEnableDrawing)
      return;

   if(InpDisplayMode == DisplayLatestOnly)
      DeleteObjectsByPrefix(PREFIX);

   if(InpShowWaveLines)
   {
      DrawLine("SEG_" + IntegerToString(i0) + "_" + IntegerToString(i1), i0, p0, i1, p1, InpDownColor, STYLE_SOLID, rates_total, time);
      DrawLine("SEG_" + IntegerToString(i1) + "_" + IntegerToString(i2), i1, p1, i2, p2, InpDownColor, STYLE_SOLID, rates_total, time);
      DrawLine("SEG_" + IntegerToString(i2) + "_" + IntegerToString(i3), i2, p2, i3, p3, InpDownColor, STYLE_SOLID, rates_total, time);
   }

   DrawParallelTrendlines(i0, p0, i1, p1, i2, p2, i3, p3, i3, rates_total, time);
   DrawWave2Zone(i0, i1, i2, p0, p1, true, rates_total, time);
   DrawEntryFib(i1, i3, p1, p2, true, rates_total, time);
   DrawEntryTriggerFib(i1, i3, p1, p2, true, rates_total, time);
   if(InpShowEntryPriceLine)
      DrawEntryPriceLine(i3, p3, true, rates_total, time);
   if(showNeg027)
      DrawWave3Neg027(i2, i3, p2, p3, true, rates_total, time);
   DrawWave4ZoneRight(i2, i3, p2, p3, true, rates_total, time);

   if(InpShowWaveLabels)
   {
      DrawText("WAVE_0_" + IntegerToString(i0), i0, p0, "0", InpNormalLabelColor, rates_total, time);
      DrawText("WAVE_1_" + IntegerToString(i1), i1, p1, "1", InpNormalLabelColor, rates_total, time);
      DrawText("WAVE_2_" + IntegerToString(i2), i2, p2, "2", InpNormalLabelColor, rates_total, time);
   }
}

void Draw03Up(const int i0, const double p0, const int i1, const double p1, const int i2, const double p2, const int i3, const double p3, const bool showNeg027, const int rates_total, const datetime &time[])
{
   if(!InpEnableDrawing)
      return;

   if(InpDisplayMode == DisplayLatestOnly)
      DeleteObjectsByPrefix(PREFIX);

   if(InpShowWaveLines)
   {
      DrawLine("SEG_" + IntegerToString(i0) + "_" + IntegerToString(i1), i0, p0, i1, p1, InpUpColor, STYLE_SOLID, rates_total, time);
      DrawLine("SEG_" + IntegerToString(i1) + "_" + IntegerToString(i2), i1, p1, i2, p2, InpUpColor, STYLE_SOLID, rates_total, time);
      DrawLine("SEG_" + IntegerToString(i2) + "_" + IntegerToString(i3), i2, p2, i3, p3, InpUpColor, STYLE_SOLID, rates_total, time);
   }

   DrawParallelTrendlines(i0, p0, i1, p1, i2, p2, i3, p3, i3, rates_total, time);
   DrawWave2Zone(i0, i1, i2, p0, p1, false, rates_total, time);
   DrawEntryFib(i1, i3, p1, p2, false, rates_total, time);
   DrawEntryTriggerFib(i1, i3, p1, p2, false, rates_total, time);
   if(InpShowEntryPriceLine)
      DrawEntryPriceLine(i3, p3, false, rates_total, time);
   if(showNeg027)
      DrawWave3Neg027(i2, i3, p2, p3, false, rates_total, time);
   DrawWave4ZoneRight(i2, i3, p2, p3, false, rates_total, time);

   if(InpShowWaveLabels)
   {
      DrawText("WAVE_0_" + IntegerToString(i0), i0, p0, "0", InpNormalLabelColor, rates_total, time);
      DrawText("WAVE_1_" + IntegerToString(i1), i1, p1, "1", InpNormalLabelColor, rates_total, time);
      DrawText("WAVE_2_" + IntegerToString(i2), i2, p2, "2", InpNormalLabelColor, rates_total, time);
   }
}

void DrawParallelTrendlines(const int i0, const double p0, const int i1, const double p1, const int i2, const double p2, const int i3, const double p3, const int endX, const int rates_total, const datetime &time[])
{
   if(!InpShowTrendLines)
      return;

   double y02End = ProjectY(i0, p0, i2, p2, endX);
   double y13End = ProjectY(i1, p1, i3, p3, endX);
   DrawLine("TL02_" + IntegerToString(i0) + "_" + IntegerToString(i2), i0, p0, endX, y02End, InpNeutralColor, STYLE_SOLID, rates_total, time);
   DrawLine("TL13_" + IntegerToString(i1) + "_" + IntegerToString(i3), i1, p1, endX, y13End, InpNeutralColor, STYLE_SOLID, rates_total, time);
}

void DrawWave2Zone(const int i0, const int i1, const int i2, const double p0, const double p1, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines)
      return;

   double fib618 = FibPrice(p0, p1, WAVE2_FIB_LEVEL);
   double fib50 = FibPrice(p0, p1, WAVE2_FIB_LEVEL2);
   string key = IntegerToString(i0) + "_" + IntegerToString(i1);
   DrawLine("FIB2_0618_LINE_" + key, i0, fib618, i2, fib618, InpWave2FibColor, STYLE_DASH, rates_total, time);
   DrawLine("FIB2_050_LINE_" + key, i0, fib50, i2, fib50, InpWave2FibColor, STYLE_DASH, rates_total, time);

   int labelX = (int)MathRound((i0 + i2) / 2.0);
   double labelY = (fib50 + fib618) / 2.0;
   DrawText("FIB2_ZONE_LABEL_" + key, labelX, labelY, InpPublicZoneLabels ? "Confirm Zone" : "0.5 - 0.618", InpNormalLabelColor, rates_total, time);
}

void DrawEntryFib(const int i1, const int i3, const double p1, const double p2, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines || !InpShowEntryFib1618)
      return;

   double fib1618 = Entry1618Price(p1, p2);
   int labelX = (int)MathRound((i1 + i3) / 2.0);
   double labelY = fib1618 + (isDowntrend ? LabelOffset(p2) : -LabelOffset(p2));
   string directionKey = isDowntrend ? "D_" : "U_";
   DrawLine("FIB3_LINE_" + directionKey + IntegerToString(i3), i1, fib1618, i3, fib1618, InpFib1618Color, STYLE_DASH, rates_total, time);
   DrawText("FIB3_LABEL_" + directionKey + IntegerToString(i3), labelX, labelY, (InpPublicZoneLabels ? "Area Fibo 1.618 - " : "1.618\n") + PriceText(fib1618), InpNormalLabelColor, rates_total, time);
}

void DrawEntryTriggerFib(const int i1, const int i3, const double p1, const double p2, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines || !InpUseEntryFibBarrier)
      return;

   double triggerPrice = EntryTriggerPrice(p1, p2);
   int labelX = (int)MathRound((i1 + i3) / 2.0);
   double labelY = triggerPrice + (isDowntrend ? LabelOffset(p2) : -LabelOffset(p2));
   string directionKey = isDowntrend ? "D_" : "U_";
   string triggerText = "TRIGGER " + DoubleToString(InpEntryTriggerFibLevel, 3) + "\n" + PriceText(triggerPrice);

   DrawLine("ENTRY_TRIGGER_LINE_" + directionKey + IntegerToString(i3), i1, triggerPrice, i3, triggerPrice, InpFib1618Color, STYLE_DASH, rates_total, time);
   DrawText("ENTRY_TRIGGER_LABEL_" + directionKey + IntegerToString(i3), labelX, labelY, triggerText, InpNormalLabelColor, rates_total, time);
}

void DrawWave3Neg027(const int i2, const int i3, const double p2, const double p3, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines)
      return;

   double fibNeg027 = Wave3Neg027Price(p2, p3);
   int endX = i3 + 30;
   int labelX = i3 + 26;
   double labelY = isDowntrend ? fibNeg027 - LabelOffset(p3) : fibNeg027 + LabelOffset(p3);
   string directionKey = isDowntrend ? "D_" : "U_";
   DrawLine("FIB3_NEG027_LINE_" + directionKey + IntegerToString(i3), i3, fibNeg027, endX, fibNeg027, InpTargetFibColor, STYLE_DASH, rates_total, time);
   DrawText("FIB3_NEG027_LABEL_" + directionKey + IntegerToString(i3), labelX, labelY, (InpPublicZoneLabels ? "SL - " : "-0.27\n") + PriceText(fibNeg027), InpNormalLabelColor, rates_total, time);
}

void DrawWave4ZoneRight(const int i2, const int i3, const double p2, const double p3, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines)
      return;

   double fib4A = Wave4FibPrice(p2, p3);
   double fib4B = Wave4Fib2Price(p2, p3);
   int endX = i3 + 30;
   int labelX = i3 + 26;
   double labelYA = isDowntrend ? fib4A + LabelOffset(p3) : fib4A - LabelOffset(p3);
   double labelYB = isDowntrend ? fib4B + LabelOffset(p3) : fib4B - LabelOffset(p3);
   string directionKey = isDowntrend ? "D_" : "U_";
   string waveKey = directionKey + IntegerToString(i2);

   DrawLine("FIB4R_0618_LINE_" + waveKey, i3, fib4A, endX, fib4A, InpTargetFibColor, STYLE_DASH, rates_total, time);
   DrawLine("FIB4R_0786_LINE_" + waveKey, i3, fib4B, endX, fib4B, InpTargetFibColor, STYLE_DASH, rates_total, time);
   DrawText("FIB4R_0618_LABEL_" + waveKey, labelX, labelYA, (InpPublicZoneLabels ? "TP - " : "0.618\n") + PriceText(fib4A), InpNormalLabelColor, rates_total, time);
   DrawText("FIB4R_0786_LABEL_" + waveKey, labelX, labelYB, (InpPublicZoneLabels ? "Extend TP - " : "0.786\n") + PriceText(fib4B), InpNormalLabelColor, rates_total, time);
}

void DrawEntryPriceLine(const int i3, const double entryPrice, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   int endX = i3 + 30;
   int labelX = i3 + 22;
   string directionKey = isDowntrend ? "D_" : "U_";
   color entryColor = isDowntrend ? InpEntryBuyColor : InpEntrySellColor;
   string entryText = (isDowntrend ? "Buy - " : "Sell - ") + PriceText(entryPrice);
   double labelY = entryPrice + (isDowntrend ? LabelOffset(entryPrice) : -LabelOffset(entryPrice));
   DrawLine("ENTRY_PRICE_LINE_" + directionKey + IntegerToString(i3), i3, entryPrice, endX, entryPrice, entryColor, STYLE_SOLID, rates_total, time);
   DrawText("ENTRY_PRICE_LABEL_" + directionKey + IntegerToString(i3), labelX, labelY, entryText, InpNormalLabelColor, rates_total, time);
}

void DrawLine(const string key, const int x1, const double y1, const int x2, const double y2, const color clr, const ENUM_LINE_STYLE style, const int rates_total, const datetime &time[])
{
   string name = PREFIX + key;
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_TREND, 0, TimeAt(time, rates_total, x1), y1, TimeAt(time, rates_total, x2), y2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpDrawingLineWidth > 1 ? InpDrawingLineWidth : 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void DrawText(const string key, const int index, const double price, const string text, const color clr, const int rates_total, const datetime &time[])
{
   string name = PREFIX + key;
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_TEXT, 0, TimeAt(time, rates_total, index), price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr == clrNONE ? InpNeutralColor : clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

datetime TimeAt(const datetime &time[], const int rates_total, const int index)
{
   if(index <= 0)
      return time[0];

   if(index < rates_total)
      return time[index];

   int sec = PeriodSeconds(_Period);
   if(sec <= 0)
      sec = 60;

   return (datetime)(time[rates_total - 1] + (index - (rates_total - 1)) * sec);
}

double AtrOffset(const double fallbackPrice)
{
   double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(points <= 0.0)
      points = fallbackPrice * 0.0001;
   return points * 30.0;
}

double LabelOffset(const double fallbackPrice)
{
   double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(points <= 0.0)
      points = fallbackPrice * 0.0001;
   return points * 12.0;
}

string PriceText(const double price)
{
   return DoubleToString(price, _Digits);
}
void DeleteObjectsByPrefix(const string prefix)
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}
