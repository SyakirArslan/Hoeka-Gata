// HokaGATA Wave 3 MT5
// Included by HoekaGataIndicator.mq5.

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

double EntryTriggerPrice(const double p1, const double p2)
{
   return InpUseEntryFibBarrier ? FibPrice(p1, p2, InpEntryTriggerFibLevel) : p1;
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
