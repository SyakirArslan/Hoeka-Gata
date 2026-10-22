// HokaGATA Engulfing Breakout MT5
// Core state machine: mirrors .pine state 0 / +/-1 / +/-2 / +/-3 flow.

// Forward declarations (MQL5 requires these when helpers are used before
// their definition further down in the same include).
void   PushEngulfName(string &names[], const string name);
void   RemoveEngulfName(string &names[], const int index);
string EngulfTimeframeText();

// ---- Two-pass replay bookkeeping -------------------------------------------
// RecalculateEngulfing() is a full replay of every bar, and it used to build the
// Entry/SL/TP/Body objects for EVERY historical setup before trimming the
// surplus away again inside the same loop. On a 5000-bar H4 chart that is
// hundreds of objects created and destroyed per recalculation, and each
// ObjectCreate/ObjectSet* is a call into the terminal.
//
// OnCalculate therefore replays twice:
//   pass 1  paint = false  -> pure arithmetic, only counts the setups
//   pass 2  paint = true   -> creates objects for the newest InpKeepN setups
//                             only, i.e. exactly the ones the history trim keeps
// EngulfTotalSetups is filled by pass 1, EngulfPaintFromOrdinal is what pass 2
// compares every setup ordinal against.
int EngulfTotalSetups      = 0;
int EngulfPaintFromOrdinal = 0;


struct EngulfAlertFlags
{
   bool armedNow;
   bool hitBuy;
   bool hitSell;
   bool tpHitNow;
   bool slHitNow;
   bool cancelledNow;
   int  cancelledDir;
   int  resultDir;
};

// Returns the "risk" distance used for the R:R target.
double EngulfRisk(const int dir, const double entry, const double sl)
{
   return MathAbs(entry - sl);
}

// .pine CREATE NEW SETUP level math, including the guards.
void EngulfComputeLevels(const int dir, const double o1, const double c1,
                         const double wickTop, const double wickBot,
                         const double bufEntry, const double bufSL, const double bufBodyBreak,
                         double &breakCalc, double &entryCalc, double &slCalc, double &tpCalc)
{
   double mintick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(mintick <= 0.0)
      mintick = MathPow(10.0, -_Digits);

   double bodyTopPrev = MathMax(o1, c1);
   double bodyBotPrev = MathMin(o1, c1);

   breakCalc = dir == 1 ? bodyTopPrev + bufBodyBreak : bodyBotPrev - bufBodyBreak;
   entryCalc = dir == 1 ? wickTop + bufEntry : wickBot - bufEntry;

   // guard: break body tidak boleh melewati level pending
   if(dir == 1 && breakCalc >= entryCalc)
      breakCalc = entryCalc - mintick;
   if(dir == -1 && breakCalc <= entryCalc)
      breakCalc = entryCalc + mintick;

   // SL dari wick berlawanan, TP dari entry (wick)
   slCalc = dir == 1 ? wickBot - bufSL : wickTop + bufSL;

   if(dir == 1 && slCalc >= entryCalc)
      slCalc = entryCalc - MathMax(bufSL, mintick * 2.0);

   if(dir == -1 && slCalc <= entryCalc)
      slCalc = entryCalc + MathMax(bufSL, mintick * 2.0);

   double risk = EngulfRisk(dir, entryCalc, slCalc);
   tpCalc = dir == 1 ? entryCalc + InpRrRatio * risk : entryCalc - InpRrRatio * risk;
}

// =====================================================
// MAIN ENGINE
// Mirrors .pine: STATE -> OPPOSITE CANCEL -> BREAK BODY -> PENDING FILL
//                -> ACTIVE RESULT -> FREEZE -> CREATE NEW SETUP
//
// paint = false  -> dry replay: no objects, no alerts (pass 1)
// paint = true   -> creates objects for setups with an ordinal above
//                   EngulfPaintFromOrdinal (pass 2)
// =====================================================
void RecalculateEngulfing(
   const int start,
   const int rates_total,
   const bool paint,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   EngulfStats stats;
   stats.nSig = 0;
   stats.nRun = 0;
   stats.nWin = 0;
   stats.nLos = 0;
   stats.nCancelled = 0;
   stats.nBuyRun = 0;
   stats.nSellRun = 0;
   stats.buyWins = 0;
   stats.buyLoss = 0;
   stats.sellWins = 0;
   stats.sellLoss = 0;
   stats.maxTPStreak = 0;
   stats.maxSLStreak = 0;
   stats.state = STATE_NONE;

   int curTPStreak = 0;
   int curSLStreak = 0;

   EngulfSetup setup;
   setup.dir = 0;
   setup.setupBar = -1;
   setup.entryBar = -1;
   setup.pBreak = 0.0;
   setup.pEntry = 0.0;
   setup.pSL = 0.0;
   setup.pTP = 0.0;
   setup.lnE = "";
   setup.lnS = "";
   setup.lnT = "";
   setup.lbE = "";
   setup.lbS = "";
   setup.lbT = "";
   setup.lnBody = "";
   setup.lbBody = "";

   int state = STATE_NONE;

   // 1-based counters over the setups the replay walks past, used to keep the
   // painted objects limited to the newest InpKeepN setups. attemptOrdinal
   // counts create-setup attempts (body-break line), setupOrdinal counts the
   // attempts that survived the level guards (Entry / SL / TP lines).
   int attemptOrdinal = 0;
   int setupOrdinal   = 0;

   // history of setup visual object names (keepN * 3 lines, keepN * 3 labels)
   string histLines[];
   string histLabels[];
   string histBodyLines[];
   string histBodyLabels[];

   int firstBar = start > 1 ? start : 1;

   for(int i = firstBar; i < rates_total; i++)
   {
      EngulfAlertFlags flags;
      flags.armedNow = false;
      flags.hitBuy = false;
      flags.hitSell = false;
      flags.tpHitNow = false;
      flags.slHitNow = false;
      flags.cancelledNow = false;
      flags.cancelledDir = 0;
      flags.resultDir = 0;

      // .pine EXTEND ACTIVE SETUP (state != 0): stretch visuals to bar_index + extendB
      if(state != STATE_NONE && InpShowLines)
      {
         int xRight = i + InpExtendB;
         EngulfSetLineX2(setup.lnE, xRight, setup.pEntry, rates_total, time);
         EngulfSetLineX2(setup.lnS, xRight, setup.pSL, rates_total, time);
         EngulfSetLineX2(setup.lnT, xRight, setup.pTP, rates_total, time);
         EngulfSetLineX2(setup.lnBody, xRight, setup.pBreak, rates_total, time);

         EngulfSetLabelX(setup.lbE, xRight, setup.pEntry, rates_total, time);
         EngulfSetLabelX(setup.lbS, xRight, setup.pSL, rates_total, time);
         EngulfSetLabelX(setup.lbT, xRight, setup.pTP, rates_total, time);
         EngulfSetLabelX(setup.lbBody, xRight, setup.pBreak, rates_total, time);
      }

      // .pine PATTERN DETECTION (barstate.isconfirmed -> closed bar)
      EngulfSignal sig = DetectEngulfing(i, open, high, low, close);

      if(sig.buy || sig.sell)
         stats.nSig++;

      // .pine OPPOSITE SIGNAL CANCELLATION
      bool oppositeToBuy = (state == STATE_BUY_SETUP || state == STATE_BUY_ARMED) && sig.sell;
      bool oppositeToSell = (state == STATE_SELL_SETUP || state == STATE_SELL_ARMED) && sig.buy;

      if(InpCancelOpp && (oppositeToBuy || oppositeToSell))
      {
         flags.cancelledDir = state > 0 ? 1 : -1;
         stats.nCancelled++;
         flags.cancelledNow = true;
         state = STATE_NONE;

         EngulfDeleteObject(setup.lnE);
         EngulfDeleteObject(setup.lnS);
         EngulfDeleteObject(setup.lnT);
         EngulfDeleteObject(setup.lbE);
         EngulfDeleteObject(setup.lbS);
         EngulfDeleteObject(setup.lbT);
         EngulfDeleteObject(setup.lnBody);
         EngulfDeleteObject(setup.lbBody);

         setup.lnE = "";
         setup.lnS = "";
         setup.lnT = "";
         setup.lbE = "";
         setup.lbS = "";
         setup.lbT = "";
         setup.lnBody = "";
         setup.lbBody = "";
      }

      // .pine BREAK BODY TRIGGER (BUY)
      if(state == STATE_BUY_SETUP && i > setup.setupBar)
      {
         if(high[i] >= setup.pBreak)
         {
            state = STATE_BUY_ARMED;
            flags.armedNow = true;
         }
      }

      // .pine PENDING FILL (BUY)
      if(state == STATE_BUY_ARMED)
      {
         if(high[i] >= setup.pEntry)
         {
            state = STATE_BUY_ACTIVE;
            setup.entryBar = i;
            stats.nRun++;
            stats.nBuyRun++;
            flags.hitBuy = true;

            EngulfSetLineStyle(setup.lnE, STYLE_SOLID);
            EngulfSetLineColor(setup.lnE, InpCBuyText);
            EngulfSetLabelText(setup.lbE, "BUY " + EngulfPriceText(setup.pEntry), InpCBuyText, InpLabelSize);
         }
      }

      // .pine BREAK BODY TRIGGER (SELL)
      if(state == STATE_SELL_SETUP && i > setup.setupBar)
      {
         if(low[i] <= setup.pBreak)
         {
            state = STATE_SELL_ARMED;
            flags.armedNow = true;
         }
      }

      // .pine PENDING FILL (SELL)
      if(state == STATE_SELL_ARMED)
      {
         if(low[i] <= setup.pEntry)
         {
            state = STATE_SELL_ACTIVE;
            setup.entryBar = i;
            stats.nRun++;
            stats.nSellRun++;
            flags.hitSell = true;

            EngulfSetLineStyle(setup.lnE, STYLE_SOLID);
            EngulfSetLineColor(setup.lnE, InpCSellText);
            EngulfSetLabelText(setup.lbE, "SELL " + EngulfPriceText(setup.pEntry), InpCSellText, InpLabelSize);
         }
      }

      // .pine ACTIVE BUY RESULT (SL checked first)
      if(state == STATE_BUY_ACTIVE && i > setup.entryBar)
      {
         if(low[i] <= setup.pSL)
         {
            stats.nLos++;
            stats.buyLoss++;
            curSLStreak++;
            curTPStreak = 0;
            if(curSLStreak > stats.maxSLStreak)
               stats.maxSLStreak = curSLStreak;

            flags.slHitNow = true;
            flags.resultDir = 1;
            state = STATE_NONE;

            EngulfSetLabelText(setup.lbE, "BUY SL " + EngulfPriceText(setup.pEntry), InpCSL, InpLabelSize);
            EngulfSetLabelText(setup.lbS, "SL HIT " + EngulfPriceText(setup.pSL), InpCSL, InpLabelSize);
         }
         else if(high[i] >= setup.pTP)
         {
            stats.nWin++;
            stats.buyWins++;
            curTPStreak++;
            curSLStreak = 0;
            if(curTPStreak > stats.maxTPStreak)
               stats.maxTPStreak = curTPStreak;

            flags.tpHitNow = true;
            flags.resultDir = 1;
            state = STATE_NONE;

            EngulfSetLabelText(setup.lbE, "BUY TP " + EngulfPriceText(setup.pEntry), InpCTP, InpLabelSize);
            EngulfSetLabelText(setup.lbT, "TP HIT " + EngulfPriceText(setup.pTP), InpCTP, InpLabelSize);
         }
      }

      // .pine ACTIVE SELL RESULT (SL checked first)
      if(state == STATE_SELL_ACTIVE && i > setup.entryBar)
      {
         if(high[i] >= setup.pSL)
         {
            stats.nLos++;
            stats.sellLoss++;
            curSLStreak++;
            curTPStreak = 0;
            if(curSLStreak > stats.maxSLStreak)
               stats.maxSLStreak = curSLStreak;

            flags.slHitNow = true;
            flags.resultDir = -1;
            state = STATE_NONE;

            EngulfSetLabelText(setup.lbE, "SELL SL " + EngulfPriceText(setup.pEntry), InpCSL, InpLabelSize);
            EngulfSetLabelText(setup.lbS, "SL HIT " + EngulfPriceText(setup.pSL), InpCSL, InpLabelSize);
         }
         else if(low[i] <= setup.pTP)
         {
            stats.nWin++;
            stats.sellWins++;
            curTPStreak++;
            curSLStreak = 0;
            if(curTPStreak > stats.maxTPStreak)
               stats.maxTPStreak = curTPStreak;

            flags.tpHitNow = true;
            flags.resultDir = -1;
            state = STATE_NONE;

            EngulfSetLabelText(setup.lbE, "SELL TP " + EngulfPriceText(setup.pEntry), InpCTP, InpLabelSize);
            EngulfSetLabelText(setup.lbT, "TP HIT " + EngulfPriceText(setup.pTP), InpCTP, InpLabelSize);
         }
      }

      // .pine FREEZE COMPLETED SETUP
      if(flags.tpHitNow || flags.slHitNow)
      {
         int xFinal = i + InpExtendB;
         EngulfSetLineX2(setup.lnE, xFinal, setup.pEntry, rates_total, time);
         EngulfSetLineX2(setup.lnS, xFinal, setup.pSL, rates_total, time);
         EngulfSetLineX2(setup.lnT, xFinal, setup.pTP, rates_total, time);
         EngulfSetLineX2(setup.lnBody, xFinal, setup.pBreak, rates_total, time);
         EngulfSetLabelX(setup.lbE, xFinal, setup.pEntry, rates_total, time);
         EngulfSetLabelX(setup.lbS, xFinal, setup.pSL, rates_total, time);
         EngulfSetLabelX(setup.lbT, xFinal, setup.pTP, rates_total, time);
         EngulfSetLabelX(setup.lbBody, xFinal, setup.pBreak, rates_total, time);

         // clear active references; history copies remain
         setup.lnBody = "";
         setup.lbBody = "";
      }

      // =====================================================
      // .pine CREATE NEW SETUP
      // =====================================================
      if(state == STATE_NONE && (sig.buy || sig.sell))
      {
         int dir = sig.buy ? 1 : -1;

         setup.lnE = "";
         setup.lnS = "";
         setup.lnT = "";
         setup.lbE = "";
         setup.lbS = "";
         setup.lbT = "";
         setup.lnBody = "";
         setup.lbBody = "";

         // Count every attempt (the body-break line is drawn per attempt, and the
         // history trim works in lines), but only paint the newest InpKeepN -
         // older ones would be created and deleted again within this same loop.
         attemptOrdinal++;
         const bool drawAttempt = paint && (attemptOrdinal > EngulfPaintFromOrdinal);

         setup.dir = dir;
         setup.setupBar = i;
         setup.entryBar = -1;

         double atr = EngulfAtrAt(i, high, low, close, 14);
         double bufEntry = InpBufEntryX * atr;
         double bufSL = InpBufSLX * atr;
         double bufBodyBreak = InpBodyBreakTol * atr;

         double o1 = open[i - 1];
         double c1 = close[i - 1];
         double wickTop = high[i - 1];
         double wickBot = low[i - 1];

         double breakCalc;
         double entryCalc;
         double slCalc;
         double tpCalc;
         EngulfComputeLevels(dir, o1, c1, wickTop, wickBot, bufEntry, bufSL, bufBodyBreak,
                             breakCalc, entryCalc, slCalc, tpCalc);

         double mintick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(mintick <= 0.0)
            mintick = MathPow(10.0, -_Digits);

         // .pine: draw body-break line (trigger level) when master display is on
         if(InpShowLines && drawAttempt)
         {
            int xStartBody = i - 1;
            int xRightBody = i + InpExtendB;
            string bodyKey = IntegerToString(i);

            setup.lnBody = PREFIX + "BODYLINE_" + bodyKey;
            setup.lbBody = PREFIX + "BODYLABEL_" + bodyKey;

            EngulfMakeLine(setup.lnBody, xStartBody, breakCalc, xRightBody, breakCalc,
                           InpCBodyBreak, EngulfBodyBreakStyle(), rates_total, time);
            EngulfMakeLabel(setup.lbBody, xRightBody, breakCalc, "BREAK BODY",
                            InpCBodyBreak, InpLabelSize, rates_total, time);

            PushEngulfName(histBodyLines, setup.lnBody);
            PushEngulfName(histBodyLabels, setup.lbBody);

            // limit history arrays to keepBodyHistory (= keepN)
            while(ArraySize(histBodyLines) > InpKeepN)
            {
               EngulfDeleteObject(histBodyLines[0]);
               RemoveEngulfName(histBodyLines, 0);
            }
            while(ArraySize(histBodyLabels) > InpKeepN)
            {
               EngulfDeleteObject(histBodyLabels[0]);
               RemoveEngulfName(histBodyLabels, 0);
            }
         }

         if(EngulfRisk(dir, entryCalc, slCalc) > mintick &&
            MathAbs(tpCalc - entryCalc) > mintick)
         {
            setup.pBreak = breakCalc;
            setup.pEntry = entryCalc;
            setup.pSL = slCalc;
            setup.pTP = tpCalc;
            state = dir;

            // Only a setup that survives the level guards counts towards the
            // painted Entry / SL / TP window.
            setupOrdinal++;
            const bool drawThis = paint && (setupOrdinal > EngulfPaintFromOrdinal);

            int xEntryStart = i;
            int xSLStart = i - 1;
            int xRight = i + InpExtendB;
            string setupKey = IntegerToString(i) + "_" + IntegerToString(dir);

            if(InpShowLines && drawThis)
            {
               setup.lnE = PREFIX + "ENTRYLINE_" + setupKey;
               setup.lnS = PREFIX + "SLLINE_" + setupKey;
               setup.lnT = PREFIX + "TPLINE_" + setupKey;
               setup.lbE = PREFIX + "ENTRYLABEL_" + setupKey;
               setup.lbS = PREFIX + "SLLABEL_" + setupKey;
               setup.lbT = PREFIX + "TPLABEL_" + setupKey;

               EngulfMakeLine(setup.lnE, xEntryStart, setup.pEntry, xRight, setup.pEntry,
                              InpCEntryLine, STYLE_DASH, rates_total, time);
               EngulfMakeLine(setup.lnS, xSLStart, setup.pSL, xRight, setup.pSL,
                              InpCSL, EngulfLineStyle(), rates_total, time);
               EngulfMakeLine(setup.lnT, xEntryStart, setup.pTP, xRight, setup.pTP,
                              InpCTP, EngulfLineStyle(), rates_total, time);

               PushEngulfName(histLines, setup.lnE);
               PushEngulfName(histLines, setup.lnS);
               PushEngulfName(histLines, setup.lnT);

               string side = dir == 1 ? "BUY" : "SELL";
               color entryColor = dir == 1 ? InpCBuyText : InpCSellText;

               EngulfMakeLabel(setup.lbE, xRight, setup.pEntry,
                               "PENDING " + side + " " + EngulfPriceText(setup.pEntry),
                               entryColor, InpLabelSize, rates_total, time);
               EngulfMakeLabel(setup.lbS, xRight, setup.pSL,
                               "SL " + EngulfPriceText(setup.pSL),
                               InpCSL, InpLabelSize, rates_total, time);
               EngulfMakeLabel(setup.lbT, xRight, setup.pTP,
                               "TP " + EngulfPriceText(setup.pTP),
                               InpCTP, InpLabelSize, rates_total, time);

               PushEngulfName(histLabels, setup.lbE);
               PushEngulfName(histLabels, setup.lbS);
               PushEngulfName(histLabels, setup.lbT);

               while(ArraySize(histLines) > InpKeepN * 3)
               {
                  EngulfDeleteObject(histLines[0]);
                  RemoveEngulfName(histLines, 0);
               }
               while(ArraySize(histLabels) > InpKeepN * 3)
               {
                  EngulfDeleteObject(histLabels[0]);
                  RemoveEngulfName(histLabels, 0);
               }
            }
         }
      }

      // =====================================================
      // SIGNAL BUFFERS (EA contract) + ALERTS
      // =====================================================
      if(flags.hitBuy || flags.hitSell)
      {
         if(flags.hitBuy)
            BuyBuffer[i] = setup.pEntry;
         else
            SellBuffer[i] = setup.pEntry;

         SignalSLBuffer[i] = setup.pSL;
         SignalTPBuffer[i] = setup.pTP;
      }

      if(paint && i == rates_total - 1)
      {
         if(flags.armedNow)
         {
            string armedSide = state == STATE_BUY_ARMED ? "BUY" : "SELL";
            Alert(_Symbol + " " + EngulfTimeframeText() + " | BREAK BODY TRIGGERED " + armedSide +
                  " | PENDING @ " + EngulfPriceText(setup.pEntry));
         }
         if(flags.hitBuy || flags.hitSell)
         {
            string entrySide = flags.hitBuy ? "BUY" : "SELL";
            Alert(_Symbol + " " + EngulfTimeframeText() + " | ENTRY " + entrySide +
                  " @ " + EngulfPriceText(setup.pEntry) +
                  " | SL " + EngulfPriceText(setup.pSL) +
                  " | TP " + EngulfPriceText(setup.pTP));
         }
         if(flags.tpHitNow)
         {
            string tpSide = flags.resultDir == 1 ? "BUY" : "SELL";
            Alert(_Symbol + " " + EngulfTimeframeText() + " | TP HIT " + tpSide +
                  " @ " + EngulfPriceText(setup.pTP));
         }
         if(flags.slHitNow)
         {
            string slSide = flags.resultDir == 1 ? "BUY" : "SELL";
            Alert(_Symbol + " " + EngulfTimeframeText() + " | SL HIT " + slSide +
                  " @ " + EngulfPriceText(setup.pSL));
         }
         if(flags.cancelledNow)
         {
            string cancelSide = flags.cancelledDir == 1 ? "BUY" : "SELL";
            Alert(_Symbol + " " + EngulfTimeframeText() + " | CANCELLED " + cancelSide +
                  " | SL " + EngulfPriceText(setup.pSL));
         }
      }
   }

   // final accumulated stats for the panel
   stats.state = state;

   // Publish the live level on the last bar so the EA sees BUY / SELL activation
   if(state == STATE_BUY_ACTIVE)
   {
      BuyBuffer[rates_total - 1] = setup.pEntry;
      SignalSLBuffer[rates_total - 1] = setup.pSL;
      SignalTPBuffer[rates_total - 1] = setup.pTP;
   }
   else if(state == STATE_SELL_ACTIVE)
   {
      SellBuffer[rates_total - 1] = setup.pEntry;
      SignalSLBuffer[rates_total - 1] = setup.pSL;
      SignalTPBuffer[rates_total - 1] = setup.pTP;
   }

   // Cache the snapshot so OnChartEvent() can repaint the panel after a scroll,
   // zoom or resize without recomputing the whole history.
   EngulfTotalSetups = setupOrdinal;
   LastPanelStats = stats;
   HasLastPanelStats = true;

   EngulfDrawPanel(stats);
}

// Small helpers used by Core / Panel
void PushEngulfName(string &names[], const string name)
{
   int size = ArraySize(names);
   ArrayResize(names, size + 1);
   names[size] = name;
}

void RemoveEngulfName(string &names[], const int index)
{
   int size = ArraySize(names);
   if(index < 0 || index >= size)
      return;

   for(int i = index; i < size - 1; i++)
      names[i] = names[i + 1];

   ArrayResize(names, size - 1);
}

string EngulfTimeframeText()
{
   return EnumToString((ENUM_TIMEFRAMES)_Period);
}
