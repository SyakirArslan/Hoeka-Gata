//+------------------------------------------------------------------+
//|                                          HoekaGataIndicator.mq5  |
//|               HokaGATA Engulfing Breakout - MT5 port              |
//+------------------------------------------------------------------+
#property copyright "HoekaGata conversion workspace"
#property link      ""
#property version   "2.01"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

#property indicator_label1  "Engulfing BUY"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrAqua
#property indicator_width1  2

#property indicator_label2  "Engulfing SELL"
#property indicator_type2   DRAW_NONE
#property indicator_color2  clrOrange
#property indicator_width2  2

#include "Includes\HoekaGataIndicator_Config.mqh"
#include "Includes\HoekaGataIndicator_Drawing.mqh"
#include "Includes\HoekaGataIndicator_Panel.mqh"
#include "Includes\HoekaGataIndicator_Engulf.mqh"
#include "Includes\HoekaGataIndicator_Core.mqh"

int OnInit()
{
   if(InpMinBodyX < 0.0 || InpMinBodyP < 0.0 || InpMinBodyP > 100.0)
   {
      Print("HoekaGataIndicator: invalid body filter. InpMinBodyX=", InpMinBodyX,
            " InpMinBodyP=", InpMinBodyP,
            ". Use MinBody >= 0 and 0 <= Body% <= 100.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpRrRatio <= 0.0)
   {
      Print("HoekaGataIndicator: invalid Risk-Reward. InpRrRatio=", InpRrRatio, ". Use > 0.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpKeepN < 1)
   {
      Print("HoekaGataIndicator: invalid InpKeepN=", InpKeepN, ". Use >= 1.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpExtendB < 0)
   {
      Print("HoekaGataIndicator: invalid InpExtendB=", InpExtendB, ". Use >= 0.");
      return INIT_PARAMETERS_INCORRECT;
   }

   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SignalSLBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SignalTPBuffer, INDICATOR_DATA);

   ArraySetAsSeries(BuyBuffer, false);
   ArraySetAsSeries(SellBuffer, false);
   ArraySetAsSeries(SignalSLBuffer, false);
   ArraySetAsSeries(SignalTPBuffer, false);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      "Engulfing Breakout " + _Symbol + " " + TimeframeShortName(_Period));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

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
   ClearPublishedSignalState();
   EngulfDeleteByPrefix(PREFIX);
}

//+------------------------------------------------------------------+
//| Per-tick change detection                                        |
//|                                                                  |
//| RecalculateEngulfing() is a full replay of every bar, i.e. the    |
//| most expensive thing this indicator does. Between two calls only  |
//| the forming bar can change, so rates_total plus that bar's OHLC   |
//| is a complete "did anything change?" signature: when it matches,  |
//| buffers, objects and the panel already describe exactly the same  |
//| history, and only the EA heartbeat still needs publishing.        |
//+------------------------------------------------------------------+
bool     SigValid      = false;
int      SigRatesTotal = 0;
datetime SigBarTime    = 0;
double   SigOpen       = 0.0;
double   SigHigh       = 0.0;
double   SigLow        = 0.0;
double   SigClose      = 0.0;

//+------------------------------------------------------------------+
//| Main calculation - full recalculation each call                  |
//+------------------------------------------------------------------+
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
   // Need at least the previous bar plus the ATR warm-up window.
   if(rates_total < 20)
      return 0;

   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(BuyBuffer, false);
   ArraySetAsSeries(SellBuffer, false);
   ArraySetAsSeries(SignalSLBuffer, false);
   ArraySetAsSeries(SignalTPBuffer, false);

   const datetime lastBarTime = time[rates_total - 1];
   const double   lastOpen    = open[rates_total - 1];
   const double   lastHigh    = high[rates_total - 1];
   const double   lastLow     = low[rates_total - 1];
   const double   lastClose   = close[rates_total - 1];

   // Nothing moved since the previous call -> everything on screen is already
   // correct. prev_calculated > 0 keeps fresh instances and history reloads on
   // the full path.
   if(prev_calculated > 0 && SigValid &&
      SigRatesTotal == rates_total && SigBarTime == lastBarTime &&
      SigOpen == lastOpen && SigHigh == lastHigh &&
      SigLow == lastLow && SigClose == lastClose)
   {
      PublishSignalState(rates_total, time);
      return rates_total;
   }

   for(int i = 0; i < rates_total; i++)
   {
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
      SignalSLBuffer[i] = EMPTY_VALUE;
      SignalTPBuffer[i] = EMPTY_VALUE;
   }

   EngulfDeleteByPrefixExcept(PREFIX, PREFIX + "PANEL_");

   // Pass 1 is a dry replay: pure arithmetic, it only counts how many setups the
   // history holds. Pass 2 then paints objects for the newest InpKeepN setups
   // only - exactly the ones the history trim inside the engine keeps - instead
   // of building and immediately destroying one set of objects per historical
   // setup on every recalculation.
   RecalculateEngulfing(1, rates_total, false, time, open, high, low, close);

   EngulfPaintFromOrdinal = EngulfTotalSetups - InpKeepN;

   if(EngulfPaintFromOrdinal < 0)
      EngulfPaintFromOrdinal = 0;

   RecalculateEngulfing(1, rates_total, true, time, open, high, low, close);
   PublishSignalState(rates_total, time);

   SigRatesTotal = rates_total;
   SigBarTime    = lastBarTime;
   SigOpen       = lastOpen;
   SigHigh       = lastHigh;
   SigLow        = lastLow;
   SigClose      = lastClose;
   SigValid      = true;

   ChartRedraw(0);
   return rates_total;
}

//+------------------------------------------------------------------+
//| Chart events - keep the corner-anchored panel on screen           |
//|                                                                  |
//| The stats table is built from OBJ_LABEL / OBJ_RECTANGLE_LABEL     |
//| objects pinned to CORNER_RIGHT_UPPER. MT5 only re-composites those |
//| corner offsets on a full chart redraw, and scrolling, zooming or  |
//| resizing the chart never calls OnCalculate (no tick -> no         |
//| recalculation). So the panel kept the frame painted for the last  |
//| tick, which is what made it look like it kept disappearing while  |
//| the chart was scrolled left/right. Re-applying the cached         |
//| snapshot plus ChartRedraw() puts it back immediately.             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_CHART_CHANGE && id != CHARTEVENT_MOUSE_WHEEL)
      return;

   EngulfPanelRepaintCached();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| GlobalVariable publication for HoekaGataAlgo EA                  |
//| Contract: HG_SIG_<chartid>_HB / _PMIN / _PMAX                    |
//|           HG_SIG_<chartid>_C_T|D|E|SL|TP  (current bar)          |
//|           HG_SIG_<chartid>_P_T|D|E|SL|TP  (previous bar)         |
//+------------------------------------------------------------------+
string SignalKey(const string suffix)
{
   return "HG_SIG_" + IntegerToString(ChartID()) + "_" + suffix;
}

bool PublishedSignalValue(const double value)
{
   return value != EMPTY_VALUE && value != 0.0 && MathIsValidNumber(value);
}

void SetPublishedSignalSlotData(const string slot, const datetime barTime, const int direction,
                                const double entry, const double sl, const double tp)
{
   GlobalVariableSet(SignalKey(slot + "_T"), (double)barTime);
   GlobalVariableSet(SignalKey(slot + "_D"), (double)direction);
   GlobalVariableSet(SignalKey(slot + "_E"), entry);
   GlobalVariableSet(SignalKey(slot + "_SL"), sl);
   GlobalVariableSet(SignalKey(slot + "_TP"), tp);
}

void ReadSignalAtIndex(const int index, const datetime &time[], datetime &barTime, int &direction,
                       double &entry, double &sl, double &tp)
{
   direction = 0;
   entry = 0.0;
   sl = 0.0;
   tp = 0.0;
   barTime = 0;

   if(index < 0)
      return;

   barTime = time[index];
   bool hasBuy = PublishedSignalValue(BuyBuffer[index]);
   bool hasSell = PublishedSignalValue(SellBuffer[index]);

   if(hasBuy || hasSell)
   {
      direction = hasBuy ? 1 : -1;
      entry = hasBuy ? BuyBuffer[index] : SellBuffer[index];
      sl = SignalSLBuffer[index];
      tp = SignalTPBuffer[index];
   }
}

void PublishSignalSlot(const string slot, const int index, const datetime &time[])
{
   datetime barTime = 0;
   int direction = 0;
   double entry = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   ReadSignalAtIndex(index, time, barTime, direction, entry, sl, tp);
   SetPublishedSignalSlotData(slot, barTime, direction, entry, sl, tp);
}

void PublishSignalState(const int rates_total, const datetime &time[])
{
   GlobalVariableSet(SignalKey("HB"), (double)TimeCurrent());
   // PMIN / PMAX have no equivalent in the Engulfing rules; keep the keys alive
   // for backward compatibility with any external reader.
   GlobalVariableSet(SignalKey("PMIN"), (double)InpKeepN);
   GlobalVariableSet(SignalKey("PMAX"), (double)InpKeepN);
   PublishSignalSlot("C", rates_total - 1, time);
   PublishSignalSlot("P", rates_total - 2, time);
}

void ClearPublishedSignalState()
{
   string keys[] = {
      "HB", "PMIN", "PMAX",
      "C_T", "C_D", "C_E", "C_SL", "C_TP",
      "P_T", "P_D", "P_E", "P_SL", "P_TP"
   };

   for(int i = 0; i < ArraySize(keys); i++)
      GlobalVariableDel(SignalKey(keys[i]));
}
