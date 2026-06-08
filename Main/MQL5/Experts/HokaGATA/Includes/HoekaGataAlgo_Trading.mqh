// Included by HoekaGataAlgo.mq5. Uses the parent EA globals.

void ProcessSignal()
{
   if(!EnsureIndicatorSignalSource())
   {
      g_reason = IndicatorMissingReason();
      return;
   }

   if(!g_algoEnabled)
   {
      g_reason = "Manual mode";
      return;
   }

   int shift = g_useClosedBarSignal ? 1 : 0;
   datetime signalTime = iTime(_Symbol, _Period, shift);
   if(signalTime <= 0 || signalTime == g_lastSignalTime)
      return;

   int direction = 0;
   double signalEntry = 0.0;
   double signalSL = 0.0;
   double signalTP = 0.0;
   if(!ReadSignalAtShift(shift, direction, signalEntry, signalSL, signalTP))
   {
      g_reason = "Waiting signal";
      return;
   }

   if(direction == 0)
   {
      g_reason = "Ready";
      return;
   }

   g_lastSignalEntry = signalEntry;
   g_lastSignalSL = signalSL;
   g_lastSignalTP = signalTP;
   g_lastSignalText = direction == 1 ? "BUY" : "SELL";

   ExecuteSignal(signalTime, direction, signalEntry, signalSL, signalTP);
}

void ExecuteSignal(const datetime signalTime, const int direction, const double signalEntry, const double signalSL, const double signalTP)
{
   if(direction == 1 && !g_allowBuy)
   {
      g_reason = "Buy disabled";
      LogSignalDecision("blocked: buy disabled", signalTime, direction, signalEntry, signalSL, signalTP, 0.0);
      return;
   }

   if(direction == -1 && !g_allowSell)
   {
      g_reason = "Sell disabled";
      LogSignalDecision("blocked: sell disabled", signalTime, direction, signalEntry, signalSL, signalTP, 0.0);
      return;
   }

   int barsSinceLastEntry = 0;
   if(!IsMinBarsBetweenEntryAllowed(signalTime, barsSinceLastEntry))
   {
      g_reason = "Entry distance " + IntegerToString(barsSinceLastEntry) + "/" + IntegerToString(g_minBarsBetweenEntry);
      LogSignalDecision("blocked: entry distance", signalTime, direction, signalEntry, signalSL, signalTP, 0.0);
      return;
   }

   if(!IsTradingTimeAllowed())
   {
      g_reason = "Outside time";
      LogSignalDecision("blocked: outside trading time", signalTime, direction, signalEntry, signalSL, signalTP, 0.0);
      return;
   }

   if(!IsSpreadAllowed())
   {
      g_reason = "Spread high " + IntegerToString(CurrentSpreadPoints()) + "/" + IntegerToString(g_maxSpreadPoints);
      LogSignalDecision("blocked: spread high", signalTime, direction, signalEntry, signalSL, signalTP, 0.0);
      return;
   }

   double orderEntry = CurrentMarketEntryPrice(direction);
   if(orderEntry <= 0.0)
      orderEntry = signalEntry;

   double orderSL = signalSL;
   double orderTP = signalTP;
   if(g_recalculateSLTPFromActualEntry &&
      !RecalculateSLTPFromActualEntry(direction, signalEntry, signalTP, orderEntry, orderSL, orderTP))
   {
      g_reason = "Invalid recalculated SLTP";
      LogSignalDecision("blocked: invalid recalculated SL/TP", signalTime, direction, orderEntry, orderSL, orderTP, 0.0);
      return;
   }

   double lot = CalculateRiskLot(direction, orderEntry, orderSL, orderTP);
   g_lastCalculatedLot = lot;
   if(lot <= 0.0)
   {
      g_reason = "Invalid risk";
      LogSignalDecision("blocked: invalid risk or SL/TP", signalTime, direction, orderEntry, orderSL, orderTP, lot);
      return;
   }

   bool sent = false;
   if(direction == 1)
      sent = trade.Buy(lot, _Symbol, 0.0, NormalizeDouble(orderSL, _Digits), NormalizeDouble(orderTP, _Digits), "HG-Buy");
   else
      sent = trade.Sell(lot, _Symbol, 0.0, NormalizeDouble(orderSL, _Digits), NormalizeDouble(orderTP, _Digits), "HG-Sell");

   g_lastTradeRetcode = trade.ResultRetcode();
   g_reason = sent ? "Order sent" : "Order failed " + IntegerToString((int)g_lastTradeRetcode);
   if(sent)
   {
      g_lastSignalTime = signalTime;
   }
   LogSignalDecision(sent ? "order sent" : "order failed", signalTime, direction, orderEntry, orderSL, orderTP, lot);
}

void HandleTradeTransaction(const MqlTradeTransaction &trans)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;

   if(!HistoryDealSelect(trans.deal))
      return;

   string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   if(symbol != _Symbol)
      return;

   if((ulong)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != g_magicNumber)
      return;

   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
      return;

   double netProfit =
      HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
      HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
      HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(netProfit < 0.0)
      g_consecutiveLosses++;
   else if(netProfit > 0.0)
      g_consecutiveLosses = 0;

   if(g_maxConsecutiveLosses > 0 && g_consecutiveLosses >= g_maxConsecutiveLosses)
   {
      g_algoEnabled = false;
      g_reason = "Loss limit " + IntegerToString(g_consecutiveLosses) + "/" + IntegerToString(g_maxConsecutiveLosses);
      Print("HoekaGataAlgo EA: algo stopped after consecutive losses",
            " | losses=", IntegerToString(g_consecutiveLosses),
            " | limit=", IntegerToString(g_maxConsecutiveLosses));
   }
}

bool EnsureIndicatorSignalSource()
{
   if(GlobalVariableCheck(SignalKey("HB")))
   {
      g_missingIndicatorWarningShown = false;
      return true;
   }

   return EnsureIndicatorHandle();
}

bool EnsureIndicatorHandle()
{
   if(g_indicatorHandle != INVALID_HANDLE)
      return true;

   if(g_indicatorLookupAttempted)
      return false;

   g_indicatorLookupAttempted = true;

   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      g_indicatorHandle = CreateTesterIndicatorHandle();
      if(g_indicatorHandle != INVALID_HANDLE)
      {
         g_indicatorShortName = "HokaGATA\\HoekaGataIndicator";
         g_missingIndicatorWarningShown = false;
         return true;
      }

      WarnMissingTesterIndicator();
      return false;
   }

   g_indicatorHandle = FindChartIndicatorHandle();
   if(g_indicatorHandle != INVALID_HANDLE)
   {
      g_missingIndicatorWarningShown = false;
      return true;
   }

   WarnMissingChartIndicator();
   return false;
}

int CreateTesterIndicatorHandle()
{
   ResetLastError();
   int handle = iCustom(_Symbol, _Period, "HokaGATA\\HoekaGataIndicator");
   if(handle != INVALID_HANDLE)
      Print("HoekaGataAlgo: reading tester indicator file: HokaGATA\\HoekaGataIndicator");

   return handle;
}

int FindChartIndicatorHandle()
{
   int windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int window = 0; window < windows; window++)
   {
      int total = ChartIndicatorsTotal(0, window);
      for(int i = 0; i < total; i++)
      {
         string shortName = ChartIndicatorName(0, window, i);
         if(!IsHoekaGataIndicatorShortName(shortName))
            continue;

         int handle = ChartIndicatorGet(0, window, shortName);
         if(handle != INVALID_HANDLE)
         {
            g_indicatorShortName = shortName;
            Print("HoekaGataAlgo: reading chart indicator: ", shortName);
            return handle;
         }
      }
   }

   g_indicatorShortName = "";
   return INVALID_HANDLE;
}

string IndicatorMissingReason()
{
   return (bool)MQLInfoInteger(MQL_TESTER) ? "Indicator not loaded" : "Indicator not attached";
}

bool IsHoekaGataIndicatorShortName(const string shortName)
{
   return StringFind(shortName, "HoekaGataIndicator") >= 0 ||
          StringFind(shortName, "HokaGATA") >= 0;
}

void DeleteChartSignalIndicators()
{
   int windows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int window = windows - 1; window >= 0; window--)
   {
      int total = ChartIndicatorsTotal(0, window);
      for(int i = total - 1; i >= 0; i--)
      {
         string shortName = ChartIndicatorName(0, window, i);
         if(!IsHoekaGataIndicatorShortName(shortName))
            continue;

         ResetLastError();
         if(ChartIndicatorDelete(0, window, shortName))
            Print("HoekaGataAlgo EA: removed chart indicator: ", shortName);
         else
            Print("HoekaGataAlgo EA: failed to remove chart indicator: ", shortName,
                  " | error=", IntegerToString(GetLastError()));
      }
   }
}

void WarnMissingChartIndicator()
{
   if(g_missingIndicatorWarningShown)
      return;

   Print("HoekaGataAlgo EA: indicator is not attached to this chart. Attach HoekaGataIndicator before enabling algo.");
   g_missingIndicatorWarningShown = true;
}

void WarnMissingTesterIndicator()
{
   if(g_missingIndicatorWarningShown)
      return;

   Print("HoekaGataAlgo EA: tester could not load indicator file HokaGATA\\HoekaGataIndicator. Compile/install it in MQL5\\Indicators\\HokaGATA first. error=",
         IntegerToString(GetLastError()));
   g_missingIndicatorWarningShown = true;
}

void ReleaseIndicatorHandle()
{
   if(g_indicatorHandle != INVALID_HANDLE)
      IndicatorRelease(g_indicatorHandle);
   g_indicatorHandle = INVALID_HANDLE;
   g_indicatorShortName = "";
}

string SignalKey(const string suffix)
{
   return "HG_SIG_" + IntegerToString(ChartID()) + "_" + suffix;
}

bool ReadSignalAtShift(const int shift, int &direction, double &entry, double &sl, double &tp)
{
   direction = 0;
   entry = 0.0;
   sl = 0.0;
   tp = 0.0;

   if(shift < 0 || shift > 1)
      return false;

   if(GlobalVariableCheck(SignalKey("HB")) &&
      ReadPublishedSignalAtShift(shift, direction, entry, sl, tp))
      return true;

   if(!EnsureIndicatorHandle())
      return false;

   return ReadSignalFromIndicatorHandle(shift, direction, entry, sl, tp);
}

bool ReadPublishedSignalAtShift(const int shift, int &direction, double &entry, double &sl, double &tp)
{
   string slot = shift == 0 ? "C" : "P";
   string timeKey = SignalKey(slot + "_T");
   string directionKey = SignalKey(slot + "_D");
   string entryKey = SignalKey(slot + "_E");
   string slKey = SignalKey(slot + "_SL");
   string tpKey = SignalKey(slot + "_TP");
   string extendTPKey = SignalKey(slot + "_TX");

   if(!GlobalVariableCheck(timeKey) ||
      !GlobalVariableCheck(directionKey) ||
      !GlobalVariableCheck(entryKey) ||
      !GlobalVariableCheck(slKey) ||
      !GlobalVariableCheck(tpKey) ||
      !GlobalVariableCheck(extendTPKey))
      return false;

   datetime expectedTime = iTime(_Symbol, _Period, shift);
   datetime publishedTime = (datetime)(long)GlobalVariableGet(timeKey);
   if(expectedTime <= 0 || publishedTime != expectedTime)
      return false;

   direction = (int)GlobalVariableGet(directionKey);
   if(direction == 0)
      return true;

   entry = GlobalVariableGet(entryKey);
   sl = GlobalVariableGet(slKey);
   tp = g_useExtendTP ? GlobalVariableGet(extendTPKey) : GlobalVariableGet(tpKey);
   if(!IsValidSignalValue(entry) || !MathIsValidNumber(sl) || !MathIsValidNumber(tp))
   {
      direction = 0;
      entry = 0.0;
      sl = 0.0;
      tp = 0.0;
   }

   return true;
}

bool ReadSignalFromIndicatorHandle(const int shift, int &direction, double &entry, double &sl, double &tp)
{
   if(g_indicatorHandle == INVALID_HANDLE)
      return false;

   double buyBuffer[1];
   double sellBuffer[1];
   double slBuffer[1];
   double tpBuffer[1];
   double extendTPBuffer[1];

   if(CopyBuffer(g_indicatorHandle, 0, shift, 1, buyBuffer) <= 0 ||
      CopyBuffer(g_indicatorHandle, 1, shift, 1, sellBuffer) <= 0 ||
      CopyBuffer(g_indicatorHandle, 2, shift, 1, slBuffer) <= 0 ||
      CopyBuffer(g_indicatorHandle, 3, shift, 1, tpBuffer) <= 0 ||
      CopyBuffer(g_indicatorHandle, 4, shift, 1, extendTPBuffer) <= 0)
   {
      ReleaseIndicatorHandle();
      return false;
   }

   bool hasBuy = IsValidSignalValue(buyBuffer[0]);
   bool hasSell = IsValidSignalValue(sellBuffer[0]);
   if(!hasBuy && !hasSell)
      return true;

   direction = hasBuy ? 1 : -1;
   entry = hasBuy ? buyBuffer[0] : sellBuffer[0];
   sl = slBuffer[0];
   tp = g_useExtendTP ? extendTPBuffer[0] : tpBuffer[0];
   return true;
}

bool IsValidSignalValue(const double value)
{
   return value != EMPTY_VALUE && value != 0.0 && MathIsValidNumber(value);
}

double CurrentMarketEntryPrice(const int direction)
{
   return direction == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

bool RecalculateSLTPFromActualEntry(const int direction, const double signalEntry, const double signalTP, const double actualEntry, double &sl, double &tp)
{
   if(!IsValidSignalValue(signalEntry) || !MathIsValidNumber(signalTP) || !MathIsValidNumber(actualEntry) || actualEntry <= 0.0)
      return false;

   double tpLevel = g_useExtendTP ? 0.786 : 0.618;
   double anchorP2 = signalEntry + (signalTP - signalEntry) / tpLevel;
   if(!MathIsValidNumber(anchorP2) || anchorP2 <= 0.0)
      return false;

   double range = anchorP2 - actualEntry;
   sl = actualEntry + range * -0.270;
   tp = actualEntry + range * tpLevel;

   if(!MathIsValidNumber(sl) || !MathIsValidNumber(tp))
      return false;

   if(direction == 1)
      return sl < actualEntry && tp > actualEntry;

   if(direction == -1)
      return sl > actualEntry && tp < actualEntry;

   return false;
}

double CalculateRiskLot(const int direction, const double signalEntry, const double signalSL, const double signalTP)
{
   double marketPrice = CurrentMarketEntryPrice(direction);
   if(marketPrice <= 0.0)
      marketPrice = signalEntry;

   if(signalSL == EMPTY_VALUE || signalTP == EMPTY_VALUE || !MathIsValidNumber(signalSL) || !MathIsValidNumber(signalTP))
      return 0.0;

   if(direction == 1 && (signalSL >= marketPrice || signalTP <= marketPrice))
      return 0.0;
   if(direction == -1 && (signalSL <= marketPrice || signalTP >= marketPrice))
      return 0.0;

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercentForDirection(direction) / 100.0;
   double slDistance = MathAbs(marketPrice - signalSL);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(riskMoney <= 0.0 || slDistance <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;

   double lossPerLot = slDistance / tickSize * tickValue;
   if(lossPerLot <= 0.0)
      return 0.0;

   double rawLot = riskMoney / lossPerLot;
   double lot = NormalizeVolume(rawLot);

   return lot;
}

double RiskPercentForDirection(const int direction)
{
   return direction == -1 ? g_riskSellPercent : g_riskBuyPercent;
}

double NormalizeVolume(const double volume)
{
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double lower = minVolume;
   double upper = maxVolume;
   if(step <= 0.0 || lower <= 0.0 || upper < lower)
      return 0.0;

   double adjusted = MathMax(lower, MathMin(upper, volume));
   adjusted = MathFloor(adjusted / step) * step;
   if(adjusted < lower)
      adjusted = lower;
   if(adjusted > upper)
      adjusted = upper;

   return NormalizeDouble(adjusted, VolumeDigits(step));
}

int VolumeDigits(const double step)
{
   int digits = 0;
   double value = step;
   while(digits < 8 && MathAbs(value - MathRound(value)) > 0.00000001)
   {
      value *= 10.0;
      digits++;
   }
   return digits;
}

bool IsTradingTimeAllowed()
{
   if(!g_useTradingTime)
      return true;

   MqlDateTime dt;
   TimeToStruct(ServerNow(), dt);
   int nowMinutes = dt.hour * 60 + dt.min;

   if(g_startMinutes == g_endMinutes)
      return true;

   if(g_startMinutes < g_endMinutes)
      return nowMinutes >= g_startMinutes && nowMinutes < g_endMinutes;

   return nowMinutes >= g_startMinutes || nowMinutes < g_endMinutes;
}

bool IsSpreadAllowed()
{
   if(!g_useSpreadFilter)
      return true;
   return CurrentSpreadPoints() <= g_maxSpreadPoints;
}

bool IsMinBarsBetweenEntryAllowed(const datetime signalTime, int &barsSinceLastEntry)
{
   barsSinceLastEntry = 0;
   if(g_minBarsBetweenEntry <= 0 || g_lastSignalTime <= 0)
      return true;

   int lastEntryShift = iBarShift(_Symbol, _Period, g_lastSignalTime, true);
   int signalShift = iBarShift(_Symbol, _Period, signalTime, true);
   if(lastEntryShift < 0 || signalShift < 0)
      return true;

   barsSinceLastEntry = lastEntryShift - signalShift;
   if(barsSinceLastEntry < 0)
      barsSinceLastEntry = 0;

   return barsSinceLastEntry >= g_minBarsBetweenEntry;
}

void LogSignalDecision(const string decision, const datetime signalTime, const int direction, const double entry, const double sl, const double tp, const double lot)
{
   Print("HoekaGataAlgo EA: ", decision,
         " | signal=", direction == 1 ? "BUY" : "SELL",
         " | bar=", TimeToString(signalTime, TIME_DATE | TIME_MINUTES),
         " | entry=", DoubleToString(entry, _Digits),
         " | sl=", DoubleToString(sl, _Digits),
         " | tp=", DoubleToString(tp, _Digits),
         " | lot=", DoubleToString(lot, 2),
         " | spread=", IntegerToString(CurrentSpreadPoints()),
         " | reason=", g_reason);
}

int CurrentSpreadPoints()
{
   return (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
}

datetime ServerNow()
{
   datetime serverTime = TimeTradeServer();
   if(serverTime <= 0)
      serverTime = TimeCurrent();
   return serverTime;
}
