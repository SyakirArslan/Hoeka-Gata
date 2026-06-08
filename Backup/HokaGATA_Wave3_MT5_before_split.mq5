#property copyright "HokaGATA conversion workspace"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "HokaGATA BUY"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrAqua
#property indicator_width1  2

#property indicator_label2  "HokaGATA SELL"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrange
#property indicator_width2  2

enum DisplayMode
{
   DisplayLatestOnly = 0,
   DisplayHistory    = 1
};

input group "HokaGATA | Developed by Syakir Arslan"
input int         InpPivotMin             = 8;
input int         InpPivotMax             = 100;
input DisplayMode InpDisplayMode          = DisplayLatestOnly;
input bool        InpShowWave3            = true;
input bool        InpShowWaveLines        = true;
input bool        InpShowFibLines         = true;
input bool        InpShowTrendLines       = true;
input int         InpDrawingLineWidth     = 1;
input bool        InpEnableWave3Alerts    = true;
input bool        InpEnableBuyAlerts      = true;
input bool        InpEnableSellAlerts     = true;
input bool        InpEnablePushNotify     = false;
input bool        InpUseParallelSlopeRule = true;
input double      InpParallelTolerance    = 0.15;
input double      InpWave2FibTolerance    = 0.05;
input int         InpMinBarsBetweenEntry  = 30;
input int         InpMaxBarsToProcess     = 3000;
input bool        InpShowProbabilityPanel = true;
input bool        InpPublicZoneLabels     = true;

input color       InpDownColor            = clrRed;
input color       InpUpColor              = clrLime;
input color       InpEntryBuyColor        = clrAqua;
input color       InpEntrySellColor       = clrOrange;
input color       InpNormalLabelColor     = clrGray;
input color       InpFib618Color          = clrYellow;
input color       InpFib50Color           = clrTeal;
input color       InpFib1618Color         = clrMagenta;
input color       InpFibNeg027Color       = clrBlue;
input color       InpFib4Color            = clrPurple;
input color       InpTrendLineColor       = clrWhite;
input color       InpTextColor            = clrWhite;

double BuyBuffer[];
double SellBuffer[];

const int    RAW_PIVOT_LEN    = 2;
const double WAVE2_FIB_LEVEL  = 0.618;
const double WAVE2_FIB_LEVEL2 = 0.500;
const double ENTRY_FIB_LEVEL  = 1.618;
const double ENTRY_NEG_LEVEL  = -0.270;
const double WAVE4_FIB_LEVEL  = 0.619;
const double WAVE4_FIB_LEVEL2 = 0.786;
const string PREFIX           = "HokaGATA_MT5_";

datetime g_lastAlertTime = 0;
string   g_lastAlertSide = "";

struct SwingPoint
{
   int    type;
   int    index;
   double price;
};

struct OpenTrade
{
   string key;
   int    dir;
   int    entryIndex;
   double entry;
   double sl;
   double tp;
};

struct ClosedTrade
{
   int dir;
   int result;
};

int OnInit()
{
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);

   ArraySetAsSeries(BuyBuffer, false);
   ArraySetAsSeries(SellBuffer, false);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "HokaGATA");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(PREFIX);
}

int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
{
   if(rates_total < RAW_PIVOT_LEN * 2 + InpPivotMin + 10)
      return rates_total;

   ArraySetAsSeries(time, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(BuyBuffer, false);
   ArraySetAsSeries(SellBuffer, false);

   for(int i = 0; i < rates_total; i++)
   {
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
   }

   DeleteObjectsByPrefix(PREFIX);

   int start = 0;
   if(InpMaxBarsToProcess > 0 && rates_total > InpMaxBarsToProcess)
      start = rates_total - InpMaxBarsToProcess;

   RecalculateHokaGata(start, rates_total, time, high, low, close);

   ChartRedraw(0);
   return rates_total;
}

void RecalculateHokaGata(
   const int start,
   const int rates_total,
   const datetime &time[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   SwingPoint swings[];
   OpenTrade  openTrades[];
   ClosedTrade closedTrades[];
   string tradeKeys[];
   int allDirs[];

   int lastBearEntry3 = -1;
   int lastBullEntry3 = -1;
   int lastEntry3     = -1;

   bool activeBear012       = false;
   bool activeBull012       = false;
   bool activeBearTriggered = false;
   bool activeBullTriggered = false;
   int invalidBearI1        = -1;
   int invalidBullI1        = -1;
   int triggeredBearI1      = -1;
   int triggeredBullI1      = -1;

   int activeBearI0 = -1;
   int activeBearI1 = -1;
   int activeBearI2 = -1;
   double activeBearP0 = 0.0;
   double activeBearP1 = 0.0;
   double activeBearP2 = 0.0;

   int activeBullI0 = -1;
   int activeBullI1 = -1;
   int activeBullI2 = -1;
   double activeBullP0 = 0.0;
   double activeBullP1 = 0.0;
   double activeBullP2 = 0.0;

   int firstBar = start > RAW_PIVOT_LEN * 2 ? start : RAW_PIVOT_LEN * 2;
   for(int i = firstBar; i < rates_total; i++)
   {
      bool swingChanged = false;
      int center = i - RAW_PIVOT_LEN;

      if(IsPivotHigh(high, center, RAW_PIVOT_LEN, rates_total))
         swingChanged = AddSwing(swings, 1, center, high[center]) || swingChanged;

      if(IsPivotLow(low, center, RAW_PIVOT_LEN, rates_total))
         swingChanged = AddSwing(swings, -1, center, low[center]) || swingChanged;

      bool bearWave3EntrySignal = false;
      bool bullWave3EntrySignal = false;
      string wave3AlertSide = "";
      double wave3AlertEntry = 0.0;
      double wave3AlertSL = 0.0;
      double wave3AlertTP = 0.0;

      if(swingChanged && ArraySize(swings) >= 3)
      {
         int b3 = ArraySize(swings) - 3;
         int t0 = swings[b3].type;
         int t1 = swings[b3 + 1].type;
         int t2 = swings[b3 + 2].type;
         double p0 = swings[b3].price;
         double p1 = swings[b3 + 1].price;
         double p2 = swings[b3 + 2].price;
         int i0 = swings[b3].index;
         int i1 = swings[b3 + 1].index;
         int i2 = swings[b3 + 2].index;

         bool wave2Valid = Wave2InZone(p2, p0, p1);
         bool wave2DownBreached = Wave2BreachedBetween(i1, i2, p0, p1, false, high, low, rates_total);
         bool wave2UpBreached = Wave2BreachedBetween(i1, i2, p0, p1, true, high, low, rates_total);

         bool down012 =
            t0 == 1 &&
            t1 == -1 &&
            t2 == 1 &&
            p2 < p0 &&
            invalidBearI1 != i1 &&
            triggeredBearI1 != i1 &&
            !wave2DownBreached &&
            wave2Valid;

         bool up012 =
            t0 == -1 &&
            t1 == 1 &&
            t2 == -1 &&
            p2 > p0 &&
            invalidBullI1 != i1 &&
            triggeredBullI1 != i1 &&
            !wave2UpBreached &&
            wave2Valid;

         if(down012)
         {
            activeBear012 = true;
            activeBearTriggered = false;
            activeBearI0 = i0;
            activeBearI1 = i1;
            activeBearI2 = i2;
            activeBearP0 = p0;
            activeBearP1 = p1;
            activeBearP2 = p2;
         }

         if(up012)
         {
            activeBull012 = true;
            activeBullTriggered = false;
            activeBullI0 = i0;
            activeBullI1 = i1;
            activeBullI2 = i2;
            activeBullP0 = p0;
            activeBullP1 = p1;
            activeBullP2 = p2;
         }
      }

      if(InpShowWave3 && ArraySize(swings) >= 2)
      {
         int b2 = ArraySize(swings) - 2;
         int t0 = swings[b2].type;
         int t1 = swings[b2 + 1].type;
         double p0 = swings[b2].price;
         double p1 = swings[b2 + 1].price;
         int i0 = swings[b2].index;
         int i1 = swings[b2 + 1].index;

         bool down01 = t0 == 1 && t1 == -1;
         bool up01 = t0 == -1 && t1 == 1;

         bool bearWave2Breached = down01 && Wave2BreachedAt(i, p0, p1, false, high, low);
         bool bullWave2Breached = up01 && Wave2BreachedAt(i, p0, p1, true, high, low);
         bool bearPairValid = invalidBearI1 != i1;
         bool bullPairValid = invalidBullI1 != i1;
         bool bearPairNotTriggered = triggeredBearI1 != i1;
         bool bullPairNotTriggered = triggeredBullI1 != i1;

         if(bearWave2Breached)
         {
            invalidBearI1 = i1;
            if(activeBearI1 == i1)
               activeBear012 = false;
         }

         if(bullWave2Breached)
         {
            invalidBullI1 = i1;
            if(activeBullI1 == i1)
               activeBull012 = false;
         }

         double realtimeBearP2 = EMPTY_VALUE;
         double realtimeBullP2 = EMPTY_VALUE;

         if(down01 && bearPairValid && bearPairNotTriggered && !bearWave2Breached)
            realtimeBearP2 = RealtimeWave2Price(i, p0, p1, false, high, low);

         if(up01 && bullPairValid && bullPairNotTriggered && !bullWave2Breached)
            realtimeBullP2 = RealtimeWave2Price(i, p0, p1, true, high, low);

         if(realtimeBearP2 != EMPTY_VALUE)
         {
            activeBear012 = true;
            activeBearTriggered = false;
            activeBearI0 = i0;
            activeBearI1 = i1;
            activeBearI2 = i;
            activeBearP0 = p0;
            activeBearP1 = p1;
            activeBearP2 = realtimeBearP2;
         }

         if(realtimeBullP2 != EMPTY_VALUE)
         {
            activeBull012 = true;
            activeBullTriggered = false;
            activeBullI0 = i0;
            activeBullI1 = i1;
            activeBullI2 = i;
            activeBullP0 = p0;
            activeBullP1 = p1;
            activeBullP2 = realtimeBullP2;
         }
      }

      if(InpShowWave3)
      {
         int i3 = i;
         bool entryDistanceOK = lastEntry3 < 0 || i3 - lastEntry3 >= InpMinBarsBetweenEntry;

         if(activeBear012 && !activeBearTriggered)
         {
            if(Wave2BreachedAt(i, activeBearP0, activeBearP1, false, high, low) ||
               Wave2BreachedBetween(activeBearI1, i3, activeBearP0, activeBearP1, false, high, low, rates_total))
            {
               invalidBearI1 = activeBearI1;
               activeBear012 = false;
            }
            else
            {
               double wave3Price = low[i];
               bool touchEntry = low[i] <= activeBearP1;
               int wave3Distance = i3 - activeBearI2;
               bool wave3DistanceOK = wave3Distance >= InpPivotMin && wave3Distance <= InpPivotMax;
               bool parallelValid = ParallelValid(activeBearI0, activeBearP0, activeBearI1, activeBearP1, activeBearI2, activeBearP2, i3, wave3Price);

               if(touchEntry && wave3DistanceOK && parallelValid && entryDistanceOK)
               {
                  double statsSL = StatsSL(activeBearP2, wave3Price);
                  double statsTP = StatsTP(activeBearP2, wave3Price);
                  Draw03Down(activeBearI0, activeBearP0, activeBearI1, activeBearP1, activeBearI2, activeBearP2, i3, wave3Price, true, rates_total, time);
                  AddStatsTrade(openTrades, closedTrades, tradeKeys, allDirs, "BUY_" + IntegerToString(activeBearI1) + "_" + IntegerToString(i3), 1, i3, i, wave3Price, statsSL, statsTP, high, low, rates_total);
                  if(InpDisplayMode == DisplayLatestOnly)
                     ClearSignalBuffers(rates_total);
                  BuyBuffer[i3] = wave3Price;
                  wave3AlertSide = "BUY";
                  wave3AlertEntry = wave3Price;
                  wave3AlertSL = statsSL;
                  wave3AlertTP = statsTP;
                  lastBearEntry3 = i3;
                  lastEntry3 = i3;
                  triggeredBearI1 = activeBearI1;
                  activeBearTriggered = true;
                  activeBear012 = false;
                  bearWave3EntrySignal = true;
               }
            }
         }

         if(activeBull012 && !activeBullTriggered)
         {
            if(Wave2BreachedAt(i, activeBullP0, activeBullP1, true, high, low) ||
               Wave2BreachedBetween(activeBullI1, i3, activeBullP0, activeBullP1, true, high, low, rates_total))
            {
               invalidBullI1 = activeBullI1;
               activeBull012 = false;
            }
            else
            {
               double wave3Price = high[i];
               bool touchEntry = high[i] >= activeBullP1;
               int wave3Distance = i3 - activeBullI2;
               bool wave3DistanceOK = wave3Distance >= InpPivotMin && wave3Distance <= InpPivotMax;
               bool parallelValid = ParallelValid(activeBullI0, activeBullP0, activeBullI1, activeBullP1, activeBullI2, activeBullP2, i3, wave3Price);

               if(touchEntry && wave3DistanceOK && parallelValid && entryDistanceOK)
               {
                  double statsSL = StatsSL(activeBullP2, wave3Price);
                  double statsTP = StatsTP(activeBullP2, wave3Price);
                  Draw03Up(activeBullI0, activeBullP0, activeBullI1, activeBullP1, activeBullI2, activeBullP2, i3, wave3Price, true, rates_total, time);
                  AddStatsTrade(openTrades, closedTrades, tradeKeys, allDirs, "SELL_" + IntegerToString(activeBullI1) + "_" + IntegerToString(i3), -1, i3, i, wave3Price, statsSL, statsTP, high, low, rates_total);
                  if(InpDisplayMode == DisplayLatestOnly)
                     ClearSignalBuffers(rates_total);
                  SellBuffer[i3] = wave3Price;
                  wave3AlertSide = "SELL";
                  wave3AlertEntry = wave3Price;
                  wave3AlertSL = statsSL;
                  wave3AlertTP = statsTP;
                  lastBullEntry3 = i3;
                  lastEntry3 = i3;
                  triggeredBullI1 = activeBullI1;
                  activeBullTriggered = true;
                  activeBull012 = false;
                  bullWave3EntrySignal = true;
               }
            }
         }
      }

      UpdateOpenTrades(openTrades, closedTrades, i, high, low);

      if(InpEnableWave3Alerts && i == rates_total - 1)
      {
         bool buyAllowed = bearWave3EntrySignal && InpEnableBuyAlerts;
         bool sellAllowed = bullWave3EntrySignal && InpEnableSellAlerts;
         if((buyAllowed || sellAllowed) && g_lastAlertTime != time[i])
         {
            string message = wave3AlertSide + " | Entry: " + PriceText(wave3AlertEntry) +
               " | SL: " + PriceText(wave3AlertSL) +
               " | TP: " + PriceText(wave3AlertTP) +
               " | " + _Symbol + " | TF " + EnumToString(_Period);

            Alert(message);
            if(InpEnablePushNotify)
               SendNotification(message);

            g_lastAlertTime = time[i];
            g_lastAlertSide = wave3AlertSide;
         }
      }
   }

   if(InpShowProbabilityPanel)
      DrawStatsPanel(allDirs, openTrades, closedTrades);
}

void ClearSignalBuffers(const int rates_total)
{
   for(int i = 0; i < rates_total; i++)
   {
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
   }
}

bool IsPivotHigh(const double &high[], const int center, const int len, const int rates_total)
{
   if(center - len < 0 || center + len >= rates_total)
      return false;

   double value = high[center];
   for(int j = center - len; j <= center + len; j++)
   {
      if(j == center)
         continue;
      if(high[j] >= value)
         return false;
   }
   return true;
}

bool IsPivotLow(const double &low[], const int center, const int len, const int rates_total)
{
   if(center - len < 0 || center + len >= rates_total)
      return false;

   double value = low[center];
   for(int j = center - len; j <= center + len; j++)
   {
      if(j == center)
         continue;
      if(low[j] <= value)
         return false;
   }
   return true;
}

bool AddSwing(SwingPoint &swings[], const int type, const int index, const double price)
{
   bool changed = false;
   int sz = ArraySize(swings);

   if(sz == 0)
   {
      ArrayResize(swings, 1);
      swings[0].type = type;
      swings[0].index = index;
      swings[0].price = price;
      return true;
   }

   int lastType = swings[sz - 1].type;
   int lastIndex = swings[sz - 1].index;
   double lastPrice = swings[sz - 1].price;

   if(type == lastType)
   {
      bool replaceHigh = type == 1 && price > lastPrice;
      bool replaceLow = type == -1 && price < lastPrice;
      if(replaceHigh || replaceLow)
      {
         swings[sz - 1].price = price;
         swings[sz - 1].index = index;
         swings[sz - 1].type = type;
         changed = true;
      }
   }
   else
   {
      int swingDistance = index >= lastIndex ? index - lastIndex : lastIndex - index;
      bool distanceOK = swingDistance >= InpPivotMin && swingDistance <= InpPivotMax;
      if(distanceOK)
      {
         ArrayResize(swings, sz + 1);
         swings[sz].type = type;
         swings[sz].index = index;
         swings[sz].price = price;
         changed = true;
      }
   }

   while(ArraySize(swings) > 50)
      RemoveFirstSwing(swings);

   return changed;
}

void RemoveFirstSwing(SwingPoint &swings[])
{
   int n = ArraySize(swings);
   if(n <= 0)
      return;
   for(int i = 1; i < n; i++)
      swings[i - 1] = swings[i];
   ArrayResize(swings, n - 1);
}

double FibPrice(const double p1, const double p0, const double level)
{
   return p0 + (p1 - p0) * level;
}

bool Wave2InZone(const double p2, const double p0, const double p1)
{
   double fib50 = FibPrice(p0, p1, WAVE2_FIB_LEVEL2);
   double fib618 = FibPrice(p0, p1, WAVE2_FIB_LEVEL);
   double tolerancePrice = MathAbs(p0 - p1) * InpWave2FibTolerance;
   double zoneLow = MathMin(fib50, fib618) - (p0 < p1 ? tolerancePrice : 0.0);
   double zoneHigh = MathMax(fib50, fib618) + (p0 > p1 ? tolerancePrice : 0.0);
   return p2 >= zoneLow && p2 <= zoneHigh;
}

double RealtimeWave2Price(const int index, const double p0, const double p1, const bool isUptrend, const double &high[], const double &low[])
{
   double fib50 = FibPrice(p0, p1, WAVE2_FIB_LEVEL2);
   double fib618 = FibPrice(p0, p1, WAVE2_FIB_LEVEL);
   double tolerancePrice = MathAbs(p0 - p1) * InpWave2FibTolerance;
   double zoneLow = MathMin(fib50, fib618) - (p0 < p1 ? tolerancePrice : 0.0);
   double zoneHigh = MathMax(fib50, fib618) + (p0 > p1 ? tolerancePrice : 0.0);
   double candidate = isUptrend ? low[index] : high[index];

   if(candidate >= zoneLow && candidate <= zoneHigh)
      return candidate;

   return EMPTY_VALUE;
}

bool Wave2BreachedAt(const int index, const double p0, const double p1, const bool isUptrend, const double &high[], const double &low[])
{
   double fib618 = FibPrice(p0, p1, WAVE2_FIB_LEVEL);
   double tolerancePrice = MathAbs(p0 - p1) * InpWave2FibTolerance;
   return isUptrend ? low[index] < fib618 - tolerancePrice : high[index] > fib618 + tolerancePrice;
}

bool Wave2BreachedBetween(const int i1, const int i2, const double p0, const double p1, const bool isUptrend, const double &high[], const double &low[], const int rates_total)
{
   double fib618 = FibPrice(p0, p1, WAVE2_FIB_LEVEL);
   double tolerancePrice = MathAbs(p0 - p1) * InpWave2FibTolerance;
   int minIndex = i1 < i2 ? i1 : i2;
   int maxIndex = i1 > i2 ? i1 : i2;
   int startIndex = minIndex > 0 ? minIndex : 0;
   int endIndex = maxIndex < rates_total - 1 ? maxIndex : rates_total - 1;

   for(int i = startIndex; i <= endIndex; i++)
   {
      if(isUptrend && low[i] < fib618 - tolerancePrice)
         return true;
      if(!isUptrend && high[i] > fib618 + tolerancePrice)
         return true;
   }
   return false;
}

double Entry1618Price(const double p1, const double p2)
{
   return FibPrice(p1, p2, ENTRY_FIB_LEVEL);
}

double Wave3Neg027Price(const double p2, const double p3)
{
   return FibPrice(p2, p3, ENTRY_NEG_LEVEL);
}

double Wave4FibPrice(const double p2, const double p3)
{
   return FibPrice(p2, p3, WAVE4_FIB_LEVEL);
}

double Wave4Fib2Price(const double p2, const double p3)
{
   return FibPrice(p2, p3, WAVE4_FIB_LEVEL2);
}

double StatsSL(const double p2, const double p3)
{
   return Wave3Neg027Price(p2, p3);
}

double StatsTP(const double p2, const double p3)
{
   return Wave4FibPrice(p2, p3);
}

bool ParallelValid(const int i0, const double p0, const int i1, const double p1, const int i2, const double p2, const int i3, const double p3)
{
   double dx02 = MathMax(MathAbs((double)(i2 - i0)), 1.0);
   double dx13 = MathMax(MathAbs((double)(i3 - i1)), 1.0);
   double slope02 = (p2 - p0) / dx02;
   double slope13 = (p3 - p1) / dx13;
   bool sameDirection = slope02 * slope13 > 0.0;
   double baseSlope = MathMax(MathAbs(slope02), MathAbs(slope13));
   bool closeSlope = baseSlope <= 0.0 ? false : MathAbs(slope02 - slope13) / baseSlope <= InpParallelTolerance;

   return !InpUseParallelSlopeRule || (sameDirection && closeSlope);
}

double ProjectY(const int x1, const double y1, const int x2, const double y2, const int xEnd)
{
   double dx = MathMax(MathAbs((double)(x2 - x1)), 1.0);
   double slope = (y2 - y1) / dx;
   return y1 + slope * (double)(xEnd - x1);
}

void AddStatsTrade(
   OpenTrade &openTrades[],
   ClosedTrade &closedTrades[],
   string &tradeKeys[],
   int &allDirs[],
   const string key,
   const int dir,
   const int entryIndex,
   const int currentIndex,
   const double entryPrice,
   const double slPrice,
   const double tpPrice,
   const double &high[],
   const double &low[],
   const int rates_total
)
{
   if(!InpShowProbabilityPanel || StringKeyExists(tradeKeys, key))
      return;

   PushString(tradeKeys, key);
   PushInt(allDirs, dir);

   int initialResult = TradeResultSinceEntry(entryIndex, currentIndex, dir, slPrice, tpPrice, high, low, rates_total);
   if(initialResult == 0)
      PushOpenTrade(openTrades, key, dir, entryIndex, entryPrice, slPrice, tpPrice);
   else
      PushClosedTrade(closedTrades, dir, initialResult);
}

int TradeResultSinceEntry(const int entryIndex, const int currentIndex, const int dir, const double sl, const double tp, const double &high[], const double &low[], const int rates_total)
{
   int endIndex = currentIndex < rates_total - 1 ? currentIndex : rates_total - 1;
   for(int i = entryIndex + 1; i <= endIndex; i++)
   {
      bool tpHit = dir == 1 ? high[i] >= tp : low[i] <= tp;
      bool slHit = dir == 1 ? low[i] <= sl : high[i] >= sl;
      if(slHit || tpHit)
         return slHit ? -1 : 1;
   }
   return 0;
}

void UpdateOpenTrades(OpenTrade &openTrades[], ClosedTrade &closedTrades[], const int index, const double &high[], const double &low[])
{
   for(int tradeIdx = ArraySize(openTrades) - 1; tradeIdx >= 0; tradeIdx--)
   {
      if(index <= openTrades[tradeIdx].entryIndex)
         continue;

      int dir = openTrades[tradeIdx].dir;
      double sl = openTrades[tradeIdx].sl;
      double tp = openTrades[tradeIdx].tp;
      bool tpHit = dir == 1 ? high[index] >= tp : low[index] <= tp;
      bool slHit = dir == 1 ? low[index] <= sl : high[index] >= sl;

      if(tpHit || slHit)
      {
         PushClosedTrade(closedTrades, dir, slHit ? -1 : 1);
         RemoveOpenTrade(openTrades, tradeIdx);
      }
   }
}

void PushOpenTrade(OpenTrade &arr[], const string key, const int dir, const int entryIndex, const double entry, const double sl, const double tp)
{
   int n = ArraySize(arr);
   ArrayResize(arr, n + 1);
   arr[n].key = key;
   arr[n].dir = dir;
   arr[n].entryIndex = entryIndex;
   arr[n].entry = entry;
   arr[n].sl = sl;
   arr[n].tp = tp;
}

void PushClosedTrade(ClosedTrade &arr[], const int dir, const int result)
{
   int n = ArraySize(arr);
   ArrayResize(arr, n + 1);
   arr[n].dir = dir;
   arr[n].result = result;
}

void RemoveOpenTrade(OpenTrade &arr[], const int index)
{
   int n = ArraySize(arr);
   if(index < 0 || index >= n)
      return;

   for(int i = index + 1; i < n; i++)
      arr[i - 1] = arr[i];
   ArrayResize(arr, n - 1);
}

void PushString(string &arr[], const string value)
{
   int n = ArraySize(arr);
   ArrayResize(arr, n + 1);
   arr[n] = value;
}

void PushInt(int &arr[], const int value)
{
   int n = ArraySize(arr);
   ArrayResize(arr, n + 1);
   arr[n] = value;
}

bool StringKeyExists(string &arr[], const string key)
{
   for(int i = 0; i < ArraySize(arr); i++)
   {
      if(arr[i] == key)
         return true;
   }
   return false;
}

void Draw03Down(const int i0, const double p0, const int i1, const double p1, const int i2, const double p2, const int i3, const double p3, const bool showNeg027, const int rates_total, const datetime &time[])
{
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
   DrawEntryPriceLine(i3, p3, true, rates_total, time);
   if(showNeg027)
      DrawWave3Neg027(i2, i3, p2, p3, true, rates_total, time);
   DrawWave4ZoneRight(i2, i3, p2, p3, true, rates_total, time);

   DrawText("WAVE_0_" + IntegerToString(i0), i0, p0, "0", InpNormalLabelColor, rates_total, time);
   DrawText("WAVE_1_" + IntegerToString(i1), i1, p1, "1", InpNormalLabelColor, rates_total, time);
   DrawText("WAVE_2_" + IntegerToString(i2), i2, p2, "2", InpNormalLabelColor, rates_total, time);
}

void Draw03Up(const int i0, const double p0, const int i1, const double p1, const int i2, const double p2, const int i3, const double p3, const bool showNeg027, const int rates_total, const datetime &time[])
{
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
   DrawEntryPriceLine(i3, p3, false, rates_total, time);
   if(showNeg027)
      DrawWave3Neg027(i2, i3, p2, p3, false, rates_total, time);
   DrawWave4ZoneRight(i2, i3, p2, p3, false, rates_total, time);

   DrawText("WAVE_0_" + IntegerToString(i0), i0, p0, "0", InpNormalLabelColor, rates_total, time);
   DrawText("WAVE_1_" + IntegerToString(i1), i1, p1, "1", InpNormalLabelColor, rates_total, time);
   DrawText("WAVE_2_" + IntegerToString(i2), i2, p2, "2", InpNormalLabelColor, rates_total, time);
}

void DrawParallelTrendlines(const int i0, const double p0, const int i1, const double p1, const int i2, const double p2, const int i3, const double p3, const int endX, const int rates_total, const datetime &time[])
{
   if(!InpShowTrendLines)
      return;

   double y02End = ProjectY(i0, p0, i2, p2, endX);
   double y13End = ProjectY(i1, p1, i3, p3, endX);
   DrawLine("TL02_" + IntegerToString(i0) + "_" + IntegerToString(i2), i0, p0, endX, y02End, InpTrendLineColor, STYLE_SOLID, rates_total, time);
   DrawLine("TL13_" + IntegerToString(i1) + "_" + IntegerToString(i3), i1, p1, endX, y13End, InpTrendLineColor, STYLE_SOLID, rates_total, time);
}

void DrawWave2Zone(const int i0, const int i1, const int i2, const double p0, const double p1, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines)
      return;

   double fib618 = FibPrice(p0, p1, WAVE2_FIB_LEVEL);
   double fib50 = FibPrice(p0, p1, WAVE2_FIB_LEVEL2);
   string key = IntegerToString(i0) + "_" + IntegerToString(i1);
   DrawLine("FIB2_0618_LINE_" + key, i0, fib618, i2, fib618, InpFib618Color, STYLE_DASH, rates_total, time);
   DrawLine("FIB2_050_LINE_" + key, i0, fib50, i2, fib50, InpFib50Color, STYLE_DASH, rates_total, time);

   int labelX = (int)MathRound((i0 + i2) / 2.0);
   double labelY = (fib50 + fib618) / 2.0;
   DrawText("FIB2_ZONE_LABEL_" + key, labelX, labelY, InpPublicZoneLabels ? "WAVE 2 ZONE" : "0.5 - 0.618", InpNormalLabelColor, rates_total, time);
}

void DrawEntryFib(const int i1, const int i3, const double p1, const double p2, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines)
      return;

   double fib1618 = Entry1618Price(p1, p2);
   int labelX = (int)MathRound((i1 + i3) / 2.0);
   string directionKey = isDowntrend ? "D_" : "U_";
   DrawLine("FIB3_LINE_" + directionKey + IntegerToString(i3), i1, fib1618, i3, fib1618, InpFib1618Color, STYLE_DASH, rates_total, time);
   DrawText("FIB3_LABEL_" + directionKey + IntegerToString(i3), labelX, fib1618, (InpPublicZoneLabels ? "ENTRY ZONE\n" : "1.618\n") + PriceText(fib1618), InpNormalLabelColor, rates_total, time);
}

void DrawWave3Neg027(const int i2, const int i3, const double p2, const double p3, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines)
      return;

   double fibNeg027 = Wave3Neg027Price(p2, p3);
   int endX = i3 + 30;
   int labelX = (int)MathRound((i3 + endX) / 2.0);
   double labelY = isDowntrend ? fibNeg027 - AtrOffset(p3) : fibNeg027 + AtrOffset(p3);
   string directionKey = isDowntrend ? "D_" : "U_";
   DrawLine("FIB3_NEG027_LINE_" + directionKey + IntegerToString(i3), i3, fibNeg027, endX, fibNeg027, InpFibNeg027Color, STYLE_DASH, rates_total, time);
   DrawText("FIB3_NEG027_LABEL_" + directionKey + IntegerToString(i3), labelX, labelY, (InpPublicZoneLabels ? "SL\n" : "-0.27\n") + PriceText(fibNeg027), InpNormalLabelColor, rates_total, time);
}

void DrawWave4ZoneRight(const int i2, const int i3, const double p2, const double p3, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   if(!InpShowFibLines)
      return;

   double fib4A = Wave4FibPrice(p2, p3);
   double fib4B = Wave4Fib2Price(p2, p3);
   int endX = i3 + 30;
   int labelX = (int)MathRound((i3 + endX) / 2.0);
   double labelYA = isDowntrend ? fib4A + AtrOffset(p3) : fib4A - AtrOffset(p3);
   double labelYB = isDowntrend ? fib4B + AtrOffset(p3) : fib4B - AtrOffset(p3);
   string directionKey = isDowntrend ? "D_" : "U_";
   string waveKey = directionKey + IntegerToString(i2);

   DrawLine("FIB4R_0619_LINE_" + waveKey, i3, fib4A, endX, fib4A, InpFib4Color, STYLE_DASH, rates_total, time);
   DrawLine("FIB4R_0786_LINE_" + waveKey, i3, fib4B, endX, fib4B, InpFib4Color, STYLE_DASH, rates_total, time);
   DrawText("FIB4R_0619_LABEL_" + waveKey, labelX, labelYA, (InpPublicZoneLabels ? "TP\n" : "0.619\n") + PriceText(fib4A), InpNormalLabelColor, rates_total, time);
   DrawText("FIB4R_0786_LABEL_" + waveKey, labelX, labelYB, (InpPublicZoneLabels ? "ZONE\n" : "0.786\n") + PriceText(fib4B), InpNormalLabelColor, rates_total, time);
}

void DrawEntryPriceLine(const int i3, const double entryPrice, const bool isDowntrend, const int rates_total, const datetime &time[])
{
   int endX = i3 + 30;
   int labelX = (int)MathRound((i3 + endX) / 2.0);
   string directionKey = isDowntrend ? "D_" : "U_";
   color entryColor = isDowntrend ? InpEntryBuyColor : InpEntrySellColor;
   string entryText = (isDowntrend ? "BUY ENTRY\n" : "SELL ENTRY\n") + PriceText(entryPrice);
   DrawLine("ENTRY_PRICE_LINE_" + directionKey + IntegerToString(i3), i3, entryPrice, endX, entryPrice, entryColor, STYLE_SOLID, rates_total, time);
   DrawText("ENTRY_PRICE_LABEL_" + directionKey + IntegerToString(i3), labelX, entryPrice, entryText, InpNormalLabelColor, rates_total, time);
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
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr == clrNONE ? InpTextColor : clr);
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

string PriceText(const double price)
{
   return DoubleToString(price, _Digits);
}

void DrawStatsPanel(int &allDirs[], OpenTrade &openTrades[], ClosedTrade &closedTrades[])
{
   int totalBuy = 0;
   int totalSell = 0;
   int buyWins = 0;
   int buyLosses = 0;
   int sellWins = 0;
   int sellLosses = 0;
   int currentTPStreak = 0;
   int currentSLStreak = 0;
   int maxTPStreak = 0;
   int maxSLStreak = 0;

   for(int i = 0; i < ArraySize(allDirs); i++)
   {
      totalBuy += allDirs[i] == 1 ? 1 : 0;
      totalSell += allDirs[i] == -1 ? 1 : 0;
   }

   for(int i = 0; i < ArraySize(closedTrades); i++)
   {
      int dir = closedTrades[i].dir;
      int result = closedTrades[i].result;
      buyWins += dir == 1 && result == 1 ? 1 : 0;
      buyLosses += dir == 1 && result == -1 ? 1 : 0;
      sellWins += dir == -1 && result == 1 ? 1 : 0;
      sellLosses += dir == -1 && result == -1 ? 1 : 0;

      if(result == 1)
      {
         currentTPStreak++;
         currentSLStreak = 0;
         if(currentTPStreak > maxTPStreak)
            maxTPStreak = currentTPStreak;
      }
      if(result == -1)
      {
         currentSLStreak++;
         currentTPStreak = 0;
         if(currentSLStreak > maxSLStreak)
            maxSLStreak = currentSLStreak;
      }
   }

   int totalWins = buyWins + sellWins;
   int totalLosses = buyLosses + sellLosses;
   int closedTradesCount = ArraySize(closedTrades);
   int openTradesCount = ArraySize(openTrades);
   int closedBuy = buyWins + buyLosses;
   int closedSell = sellWins + sellLosses;

   DrawPanelRow(0, "Trading System by Syakir Arslan");
   DrawPanelRow(1, "Pivot Range: " + IntegerToString(InpPivotMin) + " / " + IntegerToString(InpPivotMax));
   DrawPanelRow(2, "Trades: " + IntegerToString(ArraySize(allDirs)));
   DrawPanelRow(3, "Closed / Open: " + IntegerToString(closedTradesCount) + " / " + IntegerToString(openTradesCount));
   DrawPanelRow(4, "Buy: " + FormatProbability(buyWins, closedBuy) + " (" + IntegerToString(totalBuy) + ")");
   DrawPanelRow(5, "Sell: " + FormatProbability(sellWins, closedSell) + " (" + IntegerToString(totalSell) + ")");
   DrawPanelRow(6, "TP Hits: " + IntegerToString(totalWins));
   DrawPanelRow(7, "SL Hits: " + IntegerToString(totalLosses));
   DrawPanelRow(8, "TP Streak: " + IntegerToString(maxTPStreak));
   DrawPanelRow(9, "SL Streak: " + IntegerToString(maxSLStreak));
   DrawPanelRow(10, "Overall: " + FormatProbability(totalWins, closedTradesCount));
}

void DrawPanelRow(const int row, const string text)
{
   string name = PREFIX + "PANEL_" + IntegerToString(row);
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 18 + row * 16);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

string FormatProbability(const int wins, const int closed)
{
   if(closed <= 0)
      return "n/a";
   return DoubleToString((double)wins / (double)closed * 100.0, 2) + "%";
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
