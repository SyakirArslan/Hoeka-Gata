// HokaGATA Wave 3 MT5
// Included by HoekaGataIndicator.mq5.

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
   if(StringKeyExists(tradeKeys, key))
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
