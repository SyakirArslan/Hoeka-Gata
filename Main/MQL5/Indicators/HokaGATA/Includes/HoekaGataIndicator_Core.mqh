// HoekaGataIndicator MT5
// Included by HoekaGataIndicator.mq5.

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
         bool tradeSlotAvailable = !InpSuppressSignalsWhileTradeOpen || ArraySize(openTrades) == 0;

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

               if(touchEntry && wave3DistanceOK && parallelValid && entryDistanceOK && tradeSlotAvailable)
               {
                  double statsSL = StatsSL(activeBearP2, wave3Price);
                  double statsTP = StatsTP(activeBearP2, wave3Price);
                  double statsExtendTP = Wave4Fib2Price(activeBearP2, wave3Price);
                  Draw03Down(activeBearI0, activeBearP0, activeBearI1, activeBearP1, activeBearI2, activeBearP2, i3, wave3Price, true, rates_total, time);
                  AddStatsTrade(openTrades, closedTrades, tradeKeys, allDirs, "BUY_" + IntegerToString(activeBearI1) + "_" + IntegerToString(i3), 1, i3, i, wave3Price, statsSL, statsTP, high, low, rates_total);
                  if(InpDisplayMode == DisplayLatestOnly)
                     ClearSignalBuffers(rates_total);
                  BuyBuffer[i3] = wave3Price;
                  SignalSLBuffer[i3] = statsSL;
                  SignalTPBuffer[i3] = statsTP;
                  SignalExtendTPBuffer[i3] = statsExtendTP;
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

               if(touchEntry && wave3DistanceOK && parallelValid && entryDistanceOK && tradeSlotAvailable)
               {
                  double statsSL = StatsSL(activeBullP2, wave3Price);
                  double statsTP = StatsTP(activeBullP2, wave3Price);
                  double statsExtendTP = Wave4Fib2Price(activeBullP2, wave3Price);
                  Draw03Up(activeBullI0, activeBullP0, activeBullI1, activeBullP1, activeBullI2, activeBullP2, i3, wave3Price, true, rates_total, time);
                  AddStatsTrade(openTrades, closedTrades, tradeKeys, allDirs, "SELL_" + IntegerToString(activeBullI1) + "_" + IntegerToString(i3), -1, i3, i, wave3Price, statsSL, statsTP, high, low, rates_total);
                  if(InpDisplayMode == DisplayLatestOnly)
                     ClearSignalBuffers(rates_total);
                  SellBuffer[i3] = wave3Price;
                  SignalSLBuffer[i3] = statsSL;
                  SignalTPBuffer[i3] = statsTP;
                  SignalExtendTPBuffer[i3] = statsExtendTP;
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

   if(InpEnableDrawing && InpShowProbabilityPanel)
      DrawStatsPanel(allDirs, openTrades, closedTrades);
}

void ClearSignalBuffers(const int rates_total)
{
   for(int i = 0; i < rates_total; i++)
   {
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
      SignalSLBuffer[i] = EMPTY_VALUE;
      SignalTPBuffer[i] = EMPTY_VALUE;
      SignalExtendTPBuffer[i] = EMPTY_VALUE;
   }
}
