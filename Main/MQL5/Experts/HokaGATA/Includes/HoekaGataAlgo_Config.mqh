// Included by HoekaGataAlgo.mq5. Uses the parent EA globals.

bool ParseTimeOrDefault(const string text, const int fallbackMinutes, int &minutes)
{
   if(ParseTimeText(text, minutes))
      return true;
   minutes = fallbackMinutes;
   return false;
}

bool ParseTimeText(const string text, int &minutes)
{
   string value = text;
   StringTrimLeft(value);
   StringTrimRight(value);

   int colon = StringFind(value, ":");
   if(colon <= 0)
      return false;

   int hour = (int)StringToInteger(StringSubstr(value, 0, colon));
   int minute = (int)StringToInteger(StringSubstr(value, colon + 1));

   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;

   minutes = hour * 60 + minute;
   return true;
}

string FormatMinutes(const int minutes)
{
   int hour = minutes / 60;
   int minute = minutes % 60;
   return StringFormat("%02d:%02d", hour, minute);
}

string FormatMoney(const double value)
{
   return DoubleToString(value, 2);
}

string FormatBool(const bool value)
{
   return value ? "ON" : "OFF";
}

void LoadPanelConfig()
{
   g_allowBuy = ReadConfigBool("AllowBuy", g_allowBuy);
   g_allowSell = ReadConfigBool("AllowSell", g_allowSell);
   g_useExtendTP = ReadConfigBool("UseExtendTP", g_useExtendTP);
   g_useTradingTime = ReadConfigBool("UseTradingTime", g_useTradingTime);
   g_useSpreadFilter = ReadConfigBool("UseSpreadFilter", g_useSpreadFilter);
   g_useClosedBarSignal = ReadConfigBool("UseClosedBarSignal", g_useClosedBarSignal);
   g_recalculateSLTPFromActualEntry = ReadConfigBool("RecalculateSLTPFromActualEntry", g_recalculateSLTPFromActualEntry);

   g_riskBuyPercent = ClampDouble(ReadConfigDouble("RiskBuyPercent", g_riskBuyPercent), 0.01, 100.0);
   g_riskSellPercent = ClampDouble(ReadConfigDouble("RiskSellPercent", g_riskSellPercent), 0.01, 100.0);
   g_startMinutes = (int)ClampDouble(ReadConfigDouble("StartMinutes", g_startMinutes), 0.0, 1439.0);
   g_endMinutes = (int)ClampDouble(ReadConfigDouble("EndMinutes", g_endMinutes), 0.0, 1439.0);
   g_maxSpreadPoints = (int)ClampDouble(ReadConfigDouble("MaxSpreadPoints", g_maxSpreadPoints), 1.0, 10000.0);
   g_deviationPoints = (int)ClampDouble(ReadConfigDouble("DeviationPoints", g_deviationPoints), 0.0, 10000.0);
   g_minBarsBetweenEntry = (int)ClampDouble(ReadConfigDouble("MinBarsBetweenEntry", g_minBarsBetweenEntry), 0.0, 10000.0);
   g_maxConsecutiveLosses = (int)ClampDouble(ReadConfigDouble("MaxConsecutiveLosses", g_maxConsecutiveLosses), 0.0, 1000.0);
   g_magicNumber = (ulong)ReadConfigDouble("MagicNumber", (double)g_magicNumber);
   g_panelX = (int)ClampDouble(ReadConfigDouble("PanelX", g_panelX), 0.0, 10000.0);
   g_panelY = (int)ClampDouble(ReadConfigDouble("PanelY", g_panelY), 0.0, 10000.0);
   g_panelPage = (int)ClampDouble(ReadConfigDouble("PanelPage", g_panelPage), 0.0, 1.0);
   g_panelMinimized = ReadConfigBool("PanelMinimized", g_panelMinimized);
}

void SavePanelConfig()
{
   WriteConfigBool("AllowBuy", g_allowBuy);
   WriteConfigBool("AllowSell", g_allowSell);
   WriteConfigBool("UseExtendTP", g_useExtendTP);
   WriteConfigBool("UseTradingTime", g_useTradingTime);
   WriteConfigBool("UseSpreadFilter", g_useSpreadFilter);
   WriteConfigBool("UseClosedBarSignal", g_useClosedBarSignal);
   WriteConfigBool("RecalculateSLTPFromActualEntry", g_recalculateSLTPFromActualEntry);

   WriteConfigDouble("RiskBuyPercent", g_riskBuyPercent);
   WriteConfigDouble("RiskSellPercent", g_riskSellPercent);
   WriteConfigDouble("StartMinutes", g_startMinutes);
   WriteConfigDouble("EndMinutes", g_endMinutes);
   WriteConfigDouble("MaxSpreadPoints", g_maxSpreadPoints);
   WriteConfigDouble("DeviationPoints", g_deviationPoints);
   WriteConfigDouble("MinBarsBetweenEntry", g_minBarsBetweenEntry);
   WriteConfigDouble("MaxConsecutiveLosses", g_maxConsecutiveLosses);
   WriteConfigDouble("MagicNumber", (double)g_magicNumber);
   WriteConfigDouble("PanelX", g_panelX);
   WriteConfigDouble("PanelY", g_panelY);
   WriteConfigDouble("PanelPage", g_panelPage);
   WriteConfigBool("PanelMinimized", g_panelMinimized);
}

double ReadConfigDouble(const string key, const double defaultValue)
{
   string name = ConfigKey(key);
   if(!GlobalVariableCheck(name))
      return defaultValue;
   return GlobalVariableGet(name);
}

bool ReadConfigBool(const string key, const bool defaultValue)
{
   return ReadConfigDouble(key, defaultValue ? 1.0 : 0.0) >= 0.5;
}

void WriteConfigDouble(const string key, const double value)
{
   GlobalVariableSet(ConfigKey(key), value);
}

void WriteConfigBool(const string key, const bool value)
{
   WriteConfigDouble(key, value ? 1.0 : 0.0);
}

string ConfigKey(const string key)
{
   return "HokaGATA.AutoTrader." +
      IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "." +
      _Symbol + "." +
      IntegerToString((int)_Period) + "." +
      key;
}

double ClampDouble(const double value, const double minValue, const double maxValue)
{
   return MathMax(minValue, MathMin(maxValue, value));
}

bool IsPositiveDoubleText(const string text, double &value)
{
   string trimmed = text;
   StringTrimLeft(trimmed);
   StringTrimRight(trimmed);

   int len = StringLen(trimmed);
   if(len <= 0)
      return false;

   bool hasDigit = false;
   bool hasPoint = false;
   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(trimmed, i);
      if(i == 0 && ch == 43)
         continue;

      if(ch == 46)
      {
         if(hasPoint)
            return false;
         hasPoint = true;
         continue;
      }

      if(!IsDigitChar(ch))
         return false;

      hasDigit = true;
   }

   if(!hasDigit)
      return false;

   value = StringToDouble(trimmed);
   return value > 0.0 && MathIsValidNumber(value);
}

bool IsPositiveIntegerText(const string text, long &value)
{
   string trimmed = text;
   StringTrimLeft(trimmed);
   StringTrimRight(trimmed);

   int len = StringLen(trimmed);
   if(len <= 0)
      return false;

   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(trimmed, i);
      if(!IsDigitChar(ch))
         return false;
   }

   value = StringToInteger(trimmed);
   return value > 0;
}

bool IsNonNegativeIntegerText(const string text, long &value)
{
   string trimmed = text;
   StringTrimLeft(trimmed);
   StringTrimRight(trimmed);

   int len = StringLen(trimmed);
   if(len <= 0)
      return false;

   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(trimmed, i);
      if(!IsDigitChar(ch))
         return false;
   }

   value = StringToInteger(trimmed);
   return value >= 0;
}

bool IsPanelTimeText(const string text, int &minutes)
{
   string trimmed = text;
   StringTrimLeft(trimmed);
   StringTrimRight(trimmed);

   if(StringLen(trimmed) != 5)
      return false;

   if(StringGetCharacter(trimmed, 2) != 58)
      return false;

   if(!IsDigitChar(StringGetCharacter(trimmed, 0)) ||
      !IsDigitChar(StringGetCharacter(trimmed, 1)) ||
      !IsDigitChar(StringGetCharacter(trimmed, 3)) ||
      !IsDigitChar(StringGetCharacter(trimmed, 4)))
      return false;

   return ParseTimeText(trimmed, minutes);
}

bool IsDigitChar(const ushort ch)
{
   return ch >= 48 && ch <= 57;
}
