#property copyright "HoekaGata conversion workspace"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   2

#property indicator_label1  "HoekaGataIndicator BUY"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrAqua
#property indicator_width1  2

#property indicator_label2  "HoekaGataIndicator SELL"
#property indicator_type2   DRAW_NONE
#property indicator_color2  clrOrange
#property indicator_width2  2

#include "Includes\HoekaGataIndicator_Config.mqh"
#include "Includes\HoekaGataIndicator_License.mqh"
#include "Includes\HoekaGataIndicator_Swing.mqh"
#include "Includes\HoekaGataIndicator_WaveRules.mqh"
#include "Includes\HoekaGataIndicator_Stats.mqh"
#include "Includes\HoekaGataIndicator_Drawing.mqh"
#include "Includes\HoekaGataIndicator_Panel.mqh"
#include "Includes\HoekaGataIndicator_Core.mqh"

int OnInit()
{
   if(InpPivotMin <= 0 || InpPivotMax <= 0 || InpPivotMin > InpPivotMax)
   {
      Print("HoekaGataIndicator: invalid pivot range. InpPivotMin=", InpPivotMin,
            " InpPivotMax=", InpPivotMax,
            ". Use values where Min > 0 and Max >= Min.");
      return INIT_PARAMETERS_INCORRECT;
   }

   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SignalSLBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SignalTPBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SignalExtendTPBuffer, INDICATOR_DATA);

   ArraySetAsSeries(BuyBuffer, false);
   ArraySetAsSeries(SellBuffer, false);
   ArraySetAsSeries(SignalSLBuffer, false);
   ArraySetAsSeries(SignalTPBuffer, false);
   ArraySetAsSeries(SignalExtendTPBuffer, false);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "HoekaGataIndicator " + _Symbol + " " + TimeframeShortName(_Period));
   EventSetTimer(1);
   EnforceIndicatorLicense(true);
   return INIT_SUCCEEDED;
}

string TimeframeShortName(const ENUM_TIMEFRAMES timeframe)
{
   string text = EnumToString(timeframe);
   StringReplace(text, "PERIOD_", "");
   return text;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ClearPublishedSignalState();
   DeleteObjectsByPrefix(PREFIX);
}

void OnTimer()
{
   if(!EnforceIndicatorLicense(true))
      return;

   PublishConfirmedSignalFromState();
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
   if(!EnforceIndicatorLicense(true))
   {
      if(rates_total > 0)
      {
         ArraySetAsSeries(BuyBuffer, false);
         ArraySetAsSeries(SellBuffer, false);
         ArraySetAsSeries(SignalSLBuffer, false);
         ArraySetAsSeries(SignalTPBuffer, false);
         ArraySetAsSeries(SignalExtendTPBuffer, false);
         ClearSignalBuffers(rates_total);
      }
      return rates_total;
   }

   if(rates_total < RAW_PIVOT_LEN * 2 + InpPivotMin + 10)
      return rates_total;

   ArraySetAsSeries(time, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(BuyBuffer, false);
   ArraySetAsSeries(SellBuffer, false);
   ArraySetAsSeries(SignalSLBuffer, false);
   ArraySetAsSeries(SignalTPBuffer, false);
   ArraySetAsSeries(SignalExtendTPBuffer, false);

   for(int i = 0; i < rates_total; i++)
   {
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
      SignalSLBuffer[i] = EMPTY_VALUE;
      SignalTPBuffer[i] = EMPTY_VALUE;
      SignalExtendTPBuffer[i] = EMPTY_VALUE;
   }

   if(InpEnableDrawing)
      DeleteObjectsByPrefix(PREFIX);

   int start = 0;
   if(InpMaxBarsToProcess > 0 && rates_total > InpMaxBarsToProcess)
      start = rates_total - InpMaxBarsToProcess;

   RecalculateHokaGata(start, rates_total, time, high, low, close);
   PublishSignalState(rates_total, time);

   if(InpEnableDrawing)
      ChartRedraw(0);
   return rates_total;
}

string SignalKey(const string suffix)
{
   return "HG_SIG_" + IntegerToString(ChartID()) + "_" + suffix;
}

bool PublishedSignalValue(const double value)
{
   return value != EMPTY_VALUE && value != 0.0 && MathIsValidNumber(value);
}

void SetPublishedSignalSlotData(const string slot, const datetime barTime, const int direction, const double entry, const double sl, const double tp, const double extendTP)
{
   GlobalVariableSet(SignalKey(slot + "_T"), (double)barTime);
   GlobalVariableSet(SignalKey(slot + "_D"), (double)direction);
   GlobalVariableSet(SignalKey(slot + "_E"), entry);
   GlobalVariableSet(SignalKey(slot + "_SL"), sl);
   GlobalVariableSet(SignalKey(slot + "_TP"), tp);
   GlobalVariableSet(SignalKey(slot + "_TX"), extendTP);
}

bool ReadSignalAtIndex(const int index, const datetime &time[], datetime &barTime, int &direction, double &entry, double &sl, double &tp, double &extendTP)
{
   direction = 0;
   entry = 0.0;
   sl = 0.0;
   tp = 0.0;
   extendTP = 0.0;
   barTime = 0;
   if(index >= 0)
   {
      barTime = time[index];
      bool hasBuy = PublishedSignalValue(BuyBuffer[index]);
      bool hasSell = PublishedSignalValue(SellBuffer[index]);
      if(hasBuy || hasSell)
      {
         direction = hasBuy ? 1 : -1;
         entry = hasBuy ? BuyBuffer[index] : SellBuffer[index];
         sl = SignalSLBuffer[index];
         tp = SignalTPBuffer[index];
         extendTP = SignalExtendTPBuffer[index];
      }
   }

   return direction != 0;
}

bool SamePendingSignal(const datetime barTime, const int direction, const double entry, const double sl, const double tp, const double extendTP)
{
   return g_pendingSignalBarTime == barTime &&
      g_pendingSignalDirection == direction &&
      MathAbs(g_pendingSignalEntry - entry) <= _Point / 2.0 &&
      MathAbs(g_pendingSignalSL - sl) <= _Point / 2.0 &&
      MathAbs(g_pendingSignalTP - tp) <= _Point / 2.0 &&
      MathAbs(g_pendingSignalExtendTP - extendTP) <= _Point / 2.0;
}

void ClearPendingSignal()
{
   g_pendingSignalFirstSeenTime = 0;
   g_pendingSignalBarTime = 0;
   g_pendingSignalDirection = 0;
   g_pendingSignalEntry = 0.0;
   g_pendingSignalSL = 0.0;
   g_pendingSignalTP = 0.0;
   g_pendingSignalExtendTP = 0.0;
}

void ClearConfirmedSignal()
{
   g_confirmedSignalBarTime = 0;
   g_confirmedSignalDirection = 0;
   g_confirmedSignalEntry = 0.0;
   g_confirmedSignalSL = 0.0;
   g_confirmedSignalTP = 0.0;
   g_confirmedSignalExtendTP = 0.0;
}

void SetPendingSignal(const datetime barTime, const int direction, const double entry, const double sl, const double tp, const double extendTP)
{
   g_pendingSignalFirstSeenTime = TimeCurrent();
   g_pendingSignalBarTime = barTime;
   g_pendingSignalDirection = direction;
   g_pendingSignalEntry = entry;
   g_pendingSignalSL = sl;
   g_pendingSignalTP = tp;
   g_pendingSignalExtendTP = extendTP;
}

void ConfirmPendingSignal()
{
   g_confirmedSignalBarTime = g_pendingSignalBarTime;
   g_confirmedSignalDirection = g_pendingSignalDirection;
   g_confirmedSignalEntry = g_pendingSignalEntry;
   g_confirmedSignalSL = g_pendingSignalSL;
   g_confirmedSignalTP = g_pendingSignalTP;
   g_confirmedSignalExtendTP = g_pendingSignalExtendTP;
}

void PublishCurrentEmpty(const datetime barTime)
{
   SetPublishedSignalSlotData("C", barTime, 0, 0.0, 0.0, 0.0, 0.0);
}

void PublishConfirmedCurrent()
{
   SetPublishedSignalSlotData("C",
      g_confirmedSignalBarTime,
      g_confirmedSignalDirection,
      g_confirmedSignalEntry,
      g_confirmedSignalSL,
      g_confirmedSignalTP,
      g_confirmedSignalExtendTP);
}

void PublishConfirmedSignalFromState()
{
   GlobalVariableSet(SignalKey("HB"), (double)TimeCurrent());
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime <= 0)
      return;

   if(g_confirmedSignalDirection != 0 && g_confirmedSignalBarTime == currentBarTime)
   {
      PublishConfirmedCurrent();
      return;
   }

   if(g_confirmedSignalBarTime != currentBarTime)
      ClearConfirmedSignal();

   if(g_pendingSignalDirection == 0 || g_pendingSignalBarTime != currentBarTime)
   {
      PublishCurrentEmpty(currentBarTime);
      return;
   }

   int delaySeconds = MathMax(InpSignalConfirmDelaySeconds, 0);
   if(delaySeconds <= 0 || (int)(TimeCurrent() - g_pendingSignalFirstSeenTime) >= delaySeconds)
   {
      ConfirmPendingSignal();
      PublishConfirmedCurrent();
      return;
   }

   PublishCurrentEmpty(currentBarTime);
}

void PublishSignalSlot(const string slot, const int index, const datetime &time[])
{
   datetime barTime = 0;
   int direction = 0;
   double entry = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   double extendTP = 0.0;
   ReadSignalAtIndex(index, time, barTime, direction, entry, sl, tp, extendTP);
   SetPublishedSignalSlotData(slot, barTime, direction, entry, sl, tp, extendTP);
}

void PublishConfirmedCurrentSlot(const int index, const datetime &time[])
{
   datetime barTime = 0;
   int direction = 0;
   double entry = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   double extendTP = 0.0;
   bool hasSignal = ReadSignalAtIndex(index, time, barTime, direction, entry, sl, tp, extendTP);

   if(barTime <= 0)
   {
      PublishCurrentEmpty(0);
      return;
   }

   if(g_confirmedSignalDirection != 0 && g_confirmedSignalBarTime == barTime)
   {
      PublishConfirmedCurrent();
      return;
   }

   if(g_confirmedSignalBarTime != barTime)
      ClearConfirmedSignal();

   if(!hasSignal)
   {
      ClearPendingSignal();
      PublishCurrentEmpty(barTime);
      return;
   }

   if(!SamePendingSignal(barTime, direction, entry, sl, tp, extendTP))
      SetPendingSignal(barTime, direction, entry, sl, tp, extendTP);

   int delaySeconds = MathMax(InpSignalConfirmDelaySeconds, 0);
   if(delaySeconds <= 0 || (int)(TimeCurrent() - g_pendingSignalFirstSeenTime) >= delaySeconds)
   {
      ConfirmPendingSignal();
      PublishConfirmedCurrent();
      return;
   }

   PublishCurrentEmpty(barTime);
}

void PublishSignalState(const int rates_total, const datetime &time[])
{
   GlobalVariableSet(SignalKey("HB"), (double)TimeCurrent());
   GlobalVariableSet(SignalKey("PMIN"), (double)InpPivotMin);
   GlobalVariableSet(SignalKey("PMAX"), (double)InpPivotMax);
   PublishConfirmedCurrentSlot(rates_total - 1, time);
   PublishSignalSlot("P", rates_total - 2, time);
}

void ClearPublishedSignalState()
{
   string keys[] = {
      "HB", "PMIN", "PMAX",
      "C_T", "C_D", "C_E", "C_SL", "C_TP", "C_TX",
      "P_T", "P_D", "P_E", "P_SL", "P_TP", "P_TX"
   };

   for(int i = 0; i < ArraySize(keys); i++)
      GlobalVariableDel(SignalKey(keys[i]));
}
