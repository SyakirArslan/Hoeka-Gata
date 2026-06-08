// HokaGATA Wave 3 MT5
// Included by HoekaGataIndicator.mq5.

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

   DrawPanelRow(0, "HoekaGata Wave3 Pro");
   DrawPanelRow(1, "by Syakir Arslan", 8);
   DrawPanelRow(2, "Pivot Range: " + IntegerToString(InpPivotMin) + " / " + IntegerToString(InpPivotMax));
   DrawPanelRow(3, "Trades: " + IntegerToString(ArraySize(allDirs)));
   DrawPanelRow(4, "Closed / Open: " + IntegerToString(closedTradesCount) + " / " + IntegerToString(openTradesCount));
   DrawPanelRow(5, "Buy: " + FormatProbability(buyWins, closedBuy) + " (" + IntegerToString(totalBuy) + ")");
   DrawPanelRow(6, "Sell: " + FormatProbability(sellWins, closedSell) + " (" + IntegerToString(totalSell) + ")");
   DrawPanelRow(7, "TP Hits: " + IntegerToString(totalWins));
   DrawPanelRow(8, "SL Hits: " + IntegerToString(totalLosses));
   DrawPanelRow(9, "TP Streak: " + IntegerToString(maxTPStreak));
   DrawPanelRow(10, "SL Streak: " + IntegerToString(maxSLStreak));
   DrawPanelRow(11, "Overall: " + FormatProbability(totalWins, closedTradesCount));
}

void DrawPanelRow(const int row, const string text, const int fontSize = 9)
{
   string name = PREFIX + "PANEL_" + IntegerToString(row);
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 18 + row * 16);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpNeutralColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

string FormatProbability(const int wins, const int closed)
{
   if(closed <= 0)
      return "n/a";
   return DoubleToString((double)wins / (double)closed * 100.0, 2) + "%";
}
