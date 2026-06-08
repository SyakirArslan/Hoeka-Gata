// HokaGATA Wave 3 MT5
// Included by HoekaGataIndicator.mq5.

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
