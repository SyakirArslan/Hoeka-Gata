// HokaGATA Engulfing Breakout MT5
// Pattern detection + ATR helpers.
// Mirrors .pine: BASE CALCULATION + PATTERN DETECTION.

// .pine: atr = ta.atr(14)
// Simple average of True Range over "period" closed bars ending at "index".
// (ta.atr uses RMA; the average is used here so the value is deterministic for
//  a given bar regardless of how much history MT5 has downloaded.)
double EngulfAtrAt(const int index, const double &high[], const double &low[], const double &close[], const int period = 14)
{
   if(index < 1)
      return 0.0;

   int from = index - period + 1;
   if(from < 1)
      from = 1;

   double sum = 0.0;
   int counted = 0;

   for(int i = from; i <= index; i++)
   {
      double prevClose = close[i - 1];
      double tr = MathMax(high[i], prevClose) - MathMin(low[i], prevClose);
      if(tr < 0.0)
         tr = 0.0;
      sum += tr;
      counted++;
   }

   if(counted <= 0)
      return 0.0;

   return sum / (double)counted;
}

// .pine PATTERN DETECTION
// o1 = open[1]; c1 = close[1]; pTopRef = high[1]; pBotRef = low[1]
// rgPrev = high[1] - low[1]; bdCur = |close - open|
struct EngulfSignal
{
   bool buy;
   bool sell;
   bool okBodyX;
   bool okBodyP;
};

// Evaluates the engulfing pattern on the bar at "index" using the previous bar
// at "index-1". Returns buy/sell flags exactly like .pine sigBuy / sigSell
// (barstate.isconfirmed is guaranteed because we only evaluate closed bars).
EngulfSignal DetectEngulfing(const int index, const double &open[], const double &high[], const double &low[], const double &close[])
{
   EngulfSignal sig;
   sig.buy = false;
   sig.sell = false;
   sig.okBodyX = false;
   sig.okBodyP = false;

   if(index < 1)
      return sig;

   double o_cur = open[index];
   double c_cur = close[index];
   double o1 = open[index - 1];
   double c1 = close[index - 1];
   double pTopRef = high[index - 1];
   double pBotRef = low[index - 1];

   double rgPrev = high[index - 1] - low[index - 1];
   double bdCur = MathAbs(c_cur - o_cur);

   // engBull / engBear -- always LOOSE mode (close-beyond-wick only).
   // The Strict mode (open-beyond + close-beyond wick) was removed; Loose is the default.
   bool engBull = (c_cur > pTopRef);
   bool engBear = (c_cur < pBotRef);

   // okBodyX / okBodyP per .pine
   sig.okBodyX = rgPrev > 0.0 ? (bdCur >= rgPrev * InpMinBodyX) : (bdCur > 0.0);
   sig.okBodyP = (rgPrev > 0.0) && ((bdCur / rgPrev * 100.0) >= InpMinBodyP);

   bool okAll = sig.okBodyX && sig.okBodyP;

   // .pine sigBuy  = barstate.isconfirmed and close > open and c1 < o1 and engBull and okAll
   // .pine sigSell = barstate.isconfirmed and close < open and c1 > o1 and engBear and okAll
   sig.buy  = (c_cur > o_cur) && (c1 < o1) && engBull && okAll;
   sig.sell = (c_cur < o_cur) && (c1 > o1) && engBear && okAll;

   // a bar can only be one direction; .pine would evaluate both but a body
   // cannot be bullish and bearish at the same time.
   return sig;
}
