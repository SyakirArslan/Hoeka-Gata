// Included by HoekaGataAlgo.mq5. Uses the parent EA globals.

int PanelWidth()
{
   return g_panelMinimized ? PANEL_MIN_WIDTH : PANEL_FULL_WIDTH;
}

int PanelHeight()
{
   if(g_panelMinimized)
      return PANEL_HEADER_HEIGHT + 2;

   return g_panelPage == 0 ? 484 : 510;
}

void CreateControlPanel()
{
   DeleteControlPanel();

   if(!g_panelVisible)
      return;

   int x = g_panelX;
   int y = g_panelY;
   int w = PanelWidth();
   int h = PanelHeight();

   CreateRect("BG", x, y, w, h, PANEL_BG, PANEL_BORDER);
   CreateTitleBar(x, y, w);

   if(g_panelMinimized)
   {
      UpdateControlPanel();
      return;
   }

   int margin = 8;
   int gap = 8;
   int tabY = y + PANEL_HEADER_HEIGHT + 6;
   CreateButton("BTN_PAGE_TRADING", x + margin, tabY, 72, 20, "Trading");
   CreateButton("BTN_PAGE_SETUP", x + margin + 78, tabY, 72, 20, "Setup");

   int reasonY = tabY + 26;
   int reasonH = 34;
   CreateReasonPanel(x + margin, reasonY, w - margin * 2, reasonH);

   int topY = reasonY + reasonH + gap;
   int sectionW = w - margin * 2;
   int sectionX = x + margin;
   int statusY = topY;

   if(g_panelPage == 0)
   {
      int mainH = 112;
      int riskH = 88;
      int tradeH = 112;

      CreateSection("SEC_MAIN", sectionX, topY, sectionW, mainH, "Main");

      int row = topY + 31;
      int labelX = sectionX + 10;
      int valueX = sectionX + 126;
      CreateLabel("LBL_ALGO", labelX, row + 3, "Algo", PANEL_TEXT, 8);
      CreateButton("BTN_ALGO", valueX, row, 52, 20, FormatBool(g_algoEnabled));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_MAX_LOSSES", labelX, row + 3, "Max Losses", PANEL_TEXT, 8);
      CreateEdit("EDIT_MAX_LOSSES", valueX, row, 52, 20, IntegerToString(g_maxConsecutiveLosses));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_LOSS_STREAK", labelX, row + 3, "Loss Streak", PANEL_TEXT, 8);
      CreateLabel("VAL_LOSS_STREAK", valueX, row + 3, "", PANEL_TEXT, 8);

      int riskY = topY + mainH + gap;
      CreateSection("SEC_RISK", sectionX, riskY, sectionW, riskH, "Risk");

      row = riskY + 31;
      labelX = sectionX + 10;
      valueX = sectionX + 126;
      int riskValueW = 52;
      CreateLabel("LBL_RISK_BUY_PERCENT", labelX, row + 3, "Buy %", PANEL_TEXT, 8);
      CreateRightLabel("VAL_RISK_BUY_USD", valueX - 8, row + 3, "", PANEL_TEXT, 8);
      CreateEdit("EDIT_RISK_BUY_PERCENT", valueX, row, riskValueW, 20, DoubleToString(g_riskBuyPercent, 2));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_RISK_SELL_PERCENT", labelX, row + 3, "Sell %", PANEL_TEXT, 8);
      CreateRightLabel("VAL_RISK_SELL_USD", valueX - 8, row + 3, "", PANEL_TEXT, 8);
      CreateEdit("EDIT_RISK_SELL_PERCENT", valueX, row, riskValueW, 20, DoubleToString(g_riskSellPercent, 2));

      int tradeY = riskY + riskH + gap;
      CreateSection("SEC_TRADE", sectionX, tradeY, sectionW, tradeH, "Trade");

      row = tradeY + 31;
      labelX = sectionX + 10;
      valueX = sectionX + 126;
      CreateLabel("LBL_BUY_ENABLED", labelX, row + 3, "Buy", PANEL_TEXT, 8);
      CreateButton("BTN_BUY", valueX, row, 52, 20, FormatBool(g_allowBuy));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_SELL_ENABLED", labelX, row + 3, "Sell", PANEL_TEXT, 8);
      CreateButton("BTN_SELL", valueX, row, 52, 20, FormatBool(g_allowSell));

      statusY = tradeY + tradeH + 10;
   }
   else
   {
      int execH = 138;
      int spreadH = 88;
      int timeH = 112;

      CreateSection("SEC_EXEC", sectionX, topY, sectionW, execH, "Execution");

      int row = topY + 31;
      int labelX = sectionX + 10;
      int valueX = sectionX + 126;
      int valueW = 52;
      CreateLabel("LBL_CLOSED_BAR", labelX, row + 3, "Closed Bar", PANEL_TEXT, 8);
      CreateButton("BTN_CLOSED_BAR", valueX, row, valueW, 20, FormatBool(g_useClosedBarSignal));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_RECALC_SLTP", labelX, row + 3, "Recalc SLTP", PANEL_TEXT, 8);
      CreateButton("BTN_RECALC_SLTP", valueX, row, valueW, 20, FormatBool(g_recalculateSLTPFromActualEntry));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_DEVIATION_POINTS", labelX, row + 3, "Deviation", PANEL_TEXT, 8);
      CreateEdit("EDIT_DEVIATION_POINTS", valueX, row, valueW, 20, IntegerToString(g_deviationPoints));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_MIN_BARS_ENTRY", labelX, row + 3, "Min Bars", PANEL_TEXT, 8);
      CreateEdit("EDIT_MIN_BARS_ENTRY", valueX, row, valueW, 20, IntegerToString(g_minBarsBetweenEntry));

      int spreadY = topY + execH + gap;
      CreateSection("SEC_SPREAD", sectionX, spreadY, sectionW, spreadH, "Spread");
      CreateRightLabel("VAL_SPREAD_HEADER", valueX + valueW, spreadY + 8, "", PANEL_TEXT, 9);

      row = spreadY + 31;
      labelX = sectionX + 10;
      valueX = sectionX + 126;
      CreateLabel("LBL_SPREAD_FILTER", labelX, row + 3, "Filter", PANEL_TEXT, 8);
      CreateButton("BTN_SPREAD_FILTER", valueX, row, valueW, 20, FormatBool(g_useSpreadFilter));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_MAX_SPREAD", labelX, row + 3, "Max", PANEL_TEXT, 8);
      CreateEdit("EDIT_MAX_SPREAD", valueX, row, valueW, 20, IntegerToString(g_maxSpreadPoints));

      int timeY = spreadY + spreadH + gap;
      CreateSection("SEC_TIME", sectionX, timeY, sectionW, timeH, "Time");
      CreateRightLabel("VAL_TIME_HEADER", valueX + valueW, timeY + 8, "", PANEL_TEXT, 9);

      row = timeY + 31;
      labelX = sectionX + 10;
      valueX = sectionX + 126;
      CreateLabel("LBL_TRADING_TIME", labelX, row + 3, "Trading", PANEL_TEXT, 8);
      CreateButton("BTN_TRADING_TIME", valueX, row, valueW, 20, FormatBool(g_useTradingTime));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_START_TIME", labelX, row + 3, "Start", PANEL_TEXT, 8);
      CreateEdit("EDIT_START_TIME", valueX, row, valueW, 20, FormatMinutes(g_startMinutes));
      row += PANEL_ROW_HEIGHT;
      CreateLabel("LBL_END_TIME", labelX, row + 3, "End", PANEL_TEXT, 8);
      CreateEdit("EDIT_END_TIME", valueX, row, valueW, 20, FormatMinutes(g_endMinutes));

      statusY = timeY + timeH + 10;
   }

   CreateCreditPanel(x + margin, statusY, w - margin * 2, PANEL_STATUS_HEIGHT - 16);

   UpdateControlPanel();
}

void CreateTitleBar(const int x, const int y, const int width)
{
   CreateRect("TITLE_BAR", x, y, width, PANEL_HEADER_HEIGHT, PANEL_HEADER_BG, PANEL_BORDER);
   if(!g_panelMinimized)
      CreateRect("TITLE_ACCENT", x, y + PANEL_HEADER_HEIGHT - 1, width, 1, PANEL_BORDER, PANEL_BORDER);
   string titleText = g_panelMinimized ? "HoekaGata" : "HoekaGata Control";
   CreateLabel("TITLE", x + 10, y + 7, titleText, PANEL_TEXT, 9);
   CreateButton("BTN_MIN", x + width - 52, y + 5, 20, 18, g_panelMinimized ? "+" : "-");
   CreateButton("BTN_CLOSE", x + width - 28, y + 5, 20, 18, "x");
   ObjectSetInteger(0, Obj("TITLE_BAR"), OBJPROP_SELECTABLE, false);
}

void UpdateControlPanel()
{
   if(!g_panelVisible)
      return;

   SetObjectText("BTN_ALGO", FormatBool(g_algoEnabled));
   SetObjectText("BTN_TRADING_TIME", FormatBool(g_useTradingTime));
   SetObjectText("BTN_SPREAD_FILTER", FormatBool(g_useSpreadFilter));
   SetObjectText("BTN_BUY", FormatBool(g_allowBuy));
   SetObjectText("BTN_SELL", FormatBool(g_allowSell));
   SetObjectText("BTN_CLOSED_BAR", FormatBool(g_useClosedBarSignal));
   SetObjectText("BTN_RECALC_SLTP", FormatBool(g_recalculateSLTPFromActualEntry));
   SetObjectText("TITLE", g_panelMinimized ? "HoekaGata" : "HoekaGata Control");
   SetObjectText("BTN_PAGE_TRADING", "Trading");
   SetObjectText("BTN_PAGE_SETUP", "Setup");

   SetObjectBg("BTN_MIN", PANEL_HEADER_BG);
   SetObjectBg("BTN_CLOSE", PANEL_HEADER_BG);
   SetObjectColor("BTN_MIN", clrWhite);
   SetObjectColor("BTN_CLOSE", clrWhite);
   SetObjectBorder("BTN_MIN", PANEL_HEADER_BG);
   SetObjectBorder("BTN_CLOSE", PANEL_HEADER_BG);
   SetTabStyle("BTN_PAGE_TRADING", g_panelPage == 0);
   SetTabStyle("BTN_PAGE_SETUP", g_panelPage == 1);
   SetToggleStyle("BTN_ALGO", g_algoEnabled);
   SetToggleStyle("BTN_TRADING_TIME", g_useTradingTime);
   SetToggleStyle("BTN_SPREAD_FILTER", g_useSpreadFilter);
   SetToggleStyle("BTN_BUY", g_allowBuy);
   SetToggleStyle("BTN_SELL", g_allowSell);
   SetToggleStyle("BTN_CLOSED_BAR", g_useClosedBarSignal);
   SetToggleStyle("BTN_RECALC_SLTP", g_recalculateSLTPFromActualEntry);

   if(g_panelMinimized)
      return;

   UpdateMainSection();
   UpdateRiskSection();
   UpdateExecutionSection();
   UpdateTimeSection();
   UpdateSpreadSection();
   UpdateTradeSection();
}

void UpdateMainSection()
{
   SetText("VAL_LOSS_STREAK", IntegerToString(g_consecutiveLosses) + "/" + IntegerToString(g_maxConsecutiveLosses));
   SetText("VAL_REASON", g_reason);
   SetObjectColor("VAL_LOSS_STREAK", g_maxConsecutiveLosses > 0 && g_consecutiveLosses >= g_maxConsecutiveLosses ? PANEL_WARNING : PANEL_TEXT);
   SetObjectColor("VAL_REASON", ReasonColor(g_reason));
}

void UpdateRiskSection()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   SetText("VAL_RISK_BUY_USD", FormatMoney(balance * g_riskBuyPercent / 100.0));
   SetText("VAL_RISK_SELL_USD", FormatMoney(balance * g_riskSellPercent / 100.0));
   SetObjectColor("VAL_RISK_BUY_USD", PANEL_TEXT);
   SetObjectColor("VAL_RISK_SELL_USD", PANEL_TEXT);
}

void UpdateTimeSection()
{
   MqlDateTime dt;
   TimeToStruct(ServerNow(), dt);
   bool allowed = IsTradingTimeAllowed();
   SetText("VAL_TIME_HEADER", StringFormat("%02d:%02d %s", dt.hour, dt.min, allowed ? "Allowed" : "Blocked"));
   SetObjectColor("VAL_TIME_HEADER", allowed ? PANEL_ACCENT : PANEL_WARNING);
}

void UpdateSpreadSection()
{
   int spread = CurrentSpreadPoints();
   bool allowed = IsSpreadAllowed();
   SetText("VAL_SPREAD_HEADER", IntegerToString(spread) + " " + (allowed ? "OK" : "High"));
   SetObjectColor("VAL_SPREAD_HEADER", allowed ? PANEL_ACCENT : PANEL_WARNING);
}

void UpdateTradeSection()
{
}

void UpdateExecutionSection()
{
}

void HandlePanelClick(const string name)
{
   if(StringFind(name, PANEL_PREFIX) != 0)
      return;

   ResetButtonState(name);

   if(name == Obj("BTN_CLOSE"))
   {
      g_panelVisible = false;
      DeleteControlPanel();
      ChartRedraw(0);
      return;
   }
   else if(name == Obj("BTN_MIN"))
   {
      g_panelMinimized = !g_panelMinimized;
      SavePanelConfig();
      CreateControlPanel();
      ChartRedraw(0);
      return;
   }
   else if(name == Obj("BTN_PAGE_TRADING"))
   {
      g_panelPage = 0;
      SavePanelConfig();
      CreateControlPanel();
      ChartRedraw(0);
      return;
   }
   else if(name == Obj("BTN_PAGE_SETUP"))
   {
      g_panelPage = 1;
      SavePanelConfig();
      CreateControlPanel();
      ChartRedraw(0);
      return;
   }
   else if(name == Obj("BTN_ALGO"))
      g_algoEnabled = !g_algoEnabled;
   else if(name == Obj("BTN_TRADING_TIME"))
      g_useTradingTime = !g_useTradingTime;
   else if(name == Obj("BTN_SPREAD_FILTER"))
      g_useSpreadFilter = !g_useSpreadFilter;
   else if(name == Obj("BTN_BUY"))
      g_allowBuy = !g_allowBuy;
   else if(name == Obj("BTN_SELL"))
      g_allowSell = !g_allowSell;
   else if(name == Obj("BTN_CLOSED_BAR"))
      g_useClosedBarSignal = !g_useClosedBarSignal;
   else if(name == Obj("BTN_RECALC_SLTP"))
      g_recalculateSLTPFromActualEntry = !g_recalculateSLTPFromActualEntry;

   SavePanelConfig();
   UpdateControlPanel();
   ChartRedraw(0);
}

void HandleObjectDrag(const string name)
{
   if(name == Obj("BG"))
   {
      g_panelX = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
      g_panelY = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
      SavePanelConfig();
      CreateControlPanel();
   }
   else if(name == Obj("TITLE"))
   {
      g_panelX = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE) - 10;
      g_panelY = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE) - 7;
      SavePanelConfig();
      CreateControlPanel();
   }
   else if(name == Obj("TITLE_BAR"))
   {
      g_panelX = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
      g_panelY = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
      SavePanelConfig();
      CreateControlPanel();
   }
}

void HandleMouseMove(const int mouseX, const int mouseY, const string state)
{
   bool leftDown = (StringToInteger(state) & 1) == 1;
   if(!leftDown)
   {
      StopPanelDrag();
      return;
   }

   if(!g_panelVisible)
      return;

   if(!g_panelDragging)
   {
      if(IsPointerOnPanelControl(mouseX, mouseY))
         return;

      if(!IsPanelDragZone(mouseX, mouseY))
         return;

      g_panelDragging = true;
      g_dragOffsetX = mouseX - g_panelX;
      g_dragOffsetY = mouseY - g_panelY;
      BeginPanelDrag();
   }

   int newX = mouseX - g_dragOffsetX;
   int newY = mouseY - g_dragOffsetY;
   MovePanelTo(newX, newY);
}

bool IsPanelDragZone(const int mouseX, const int mouseY)
{
   int panelW = PanelWidth();
   int headerH = PANEL_HEADER_HEIGHT;

   bool insideHeader =
      mouseX >= g_panelX &&
      mouseX <= g_panelX + panelW &&
      mouseY >= g_panelY &&
      mouseY <= g_panelY + headerH;

   bool onControls = mouseX >= g_panelX + panelW - 60 && mouseY <= g_panelY + headerH;
   return insideHeader && !onControls;
}

void BeginPanelDrag()
{
   if(!g_mouseScrollStored)
   {
      g_originalMouseScroll = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL);
      g_mouseScrollStored = true;
   }

   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
}

void StopPanelDrag()
{
   if(!g_panelDragging && !g_mouseScrollStored)
      return;

   if(g_panelDragging)
      SavePanelConfig();
   g_panelDragging = false;
   if(g_mouseScrollStored)
   {
      ChartSetInteger(0, CHART_MOUSE_SCROLL, g_originalMouseScroll);
      g_mouseScrollStored = false;
   }
}

bool IsPointerOnPanelControl(const int mouseX, const int mouseY)
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PANEL_PREFIX) != 0)
         continue;

      if(StringFind(name, Obj("BTN_")) == 0 ||
         StringFind(name, Obj("EDIT_")) == 0)
      {
         int x = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
         int y = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
         int w = (int)ObjectGetInteger(0, name, OBJPROP_XSIZE);
         int h = (int)ObjectGetInteger(0, name, OBJPROP_YSIZE);

         if(mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h)
            return true;
      }
   }

   return false;
}

void MovePanelTo(const int newX, const int newY)
{
   int boundedX = MathMax(0, newX);
   int boundedY = MathMax(0, newY);
   int dx = boundedX - g_panelX;
   int dy = boundedY - g_panelY;
   if(dx == 0 && dy == 0)
      return;

   g_panelX = boundedX;
   g_panelY = boundedY;

   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PANEL_PREFIX) != 0)
         continue;

      int x = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
      int y = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x + dx);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + dy);
   }

   ChartRedraw(0);
}

void ReadPanelInputs(const string name)
{
   if(StringFind(name, PANEL_PREFIX) != 0)
      return;

   string text = ObjectGetString(0, name, OBJPROP_TEXT);

   if(name == Obj("EDIT_RISK_BUY_PERCENT"))
   {
      double value = 0.0;
      if(IsPositiveDoubleText(text, value))
         g_riskBuyPercent = ClampDouble(value, 0.01, 100.0);
   }
   else if(name == Obj("EDIT_RISK_SELL_PERCENT"))
   {
      double value = 0.0;
      if(IsPositiveDoubleText(text, value))
         g_riskSellPercent = ClampDouble(value, 0.01, 100.0);
   }
   else if(name == Obj("EDIT_MAX_SPREAD"))
   {
      long value = 0;
      if(IsPositiveIntegerText(text, value))
         g_maxSpreadPoints = (int)ClampDouble((double)value, 1.0, 10000.0);
   }
   else if(name == Obj("EDIT_DEVIATION_POINTS"))
   {
      long value = 0;
      if(IsNonNegativeIntegerText(text, value))
      {
         g_deviationPoints = (int)ClampDouble((double)value, 0.0, 10000.0);
         trade.SetDeviationInPoints(g_deviationPoints);
      }
   }
   else if(name == Obj("EDIT_MIN_BARS_ENTRY"))
   {
      long value = 0;
      if(IsNonNegativeIntegerText(text, value))
         g_minBarsBetweenEntry = (int)ClampDouble((double)value, 0.0, 10000.0);
   }
   else if(name == Obj("EDIT_MAX_LOSSES"))
   {
      long value = 0;
      if(IsNonNegativeIntegerText(text, value))
         g_maxConsecutiveLosses = (int)ClampDouble((double)value, 0.0, 1000.0);
   }
   else if(name == Obj("EDIT_START_TIME"))
   {
      int minutes = 0;
      if(IsPanelTimeText(text, minutes))
         g_startMinutes = minutes;
   }
   else if(name == Obj("EDIT_END_TIME"))
   {
      int minutes = 0;
      if(IsPanelTimeText(text, minutes))
         g_endMinutes = minutes;
   }

   SyncEditValues();
   SavePanelConfig();
}

void SyncEditValues()
{
   SetObjectText("EDIT_RISK_BUY_PERCENT", DoubleToString(g_riskBuyPercent, 2));
   SetObjectText("EDIT_RISK_SELL_PERCENT", DoubleToString(g_riskSellPercent, 2));
   SetObjectText("EDIT_START_TIME", FormatMinutes(g_startMinutes));
   SetObjectText("EDIT_END_TIME", FormatMinutes(g_endMinutes));
   SetObjectText("EDIT_MAX_SPREAD", IntegerToString(g_maxSpreadPoints));
   SetObjectText("EDIT_DEVIATION_POINTS", IntegerToString(g_deviationPoints));
   SetObjectText("EDIT_MIN_BARS_ENTRY", IntegerToString(g_minBarsBetweenEntry));
   SetObjectText("EDIT_MAX_LOSSES", IntegerToString(g_maxConsecutiveLosses));
}

color SignalColor(const string signal)
{
   if(signal == "BUY")
      return PANEL_ACCENT;
   if(signal == "SELL")
      return PANEL_WARNING;
   return PANEL_MUTED_TEXT;
}

color ReasonColor(const string reason)
{
   if(reason == "Ready" || reason == "Order sent")
      return PANEL_ACCENT;

   if(StringFind(reason, "Spread high") >= 0 ||
      StringFind(reason, "failed") >= 0)
      return PANEL_WARNING;

   if(reason == "Manual mode" ||
      reason == "Buy disabled" ||
      reason == "Sell disabled" ||
      StringFind(reason, "Loss limit") >= 0 ||
      reason == "Outside time" ||
      reason == "Spread high" ||
      reason == "Invalid risk" ||
      reason == "Indicator not attached" ||
      reason == "Indicator not found" ||
      reason == "Indicator not loaded")
      return PANEL_WARNING;

   return PANEL_MUTED_TEXT;
}

void CreateRect(const string key, const int x, const int y, const int width, const int height, const color bg, const color border)
{
   string name = Obj(key);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER);
}

void CreatePanelBox(const string key, const int x, const int y, const int width, const int height)
{
   string name = Obj(key);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, PANEL_BOX_BG);
   ObjectSetInteger(0, name, OBJPROP_COLOR, PANEL_BORDER);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER);
}

void CreateSection(const string key, const int x, const int y, const int width, const int height, const string text)
{
   CreatePanelBox(key, x, y, width, height);
   CreateLabel(key + "_TITLE", x + 10, y + 8, text, PANEL_ACCENT, 9);
}

void CreateReasonPanel(const int x, const int y, const int width, const int height)
{
   CreatePanelBox("REASON_BG", x, y, width, height);
   CreateLabel("LBL_REASON", x + 10, y + 8, "Reason:", PANEL_MUTED_TEXT, 8);
   CreateLabel("VAL_REASON", x + 68, y + 8, "", PANEL_TEXT, 8);
}

void CreateCreditPanel(const int x, const int y, const int width, const int height)
{
   CreatePanelBox("CREDIT_BG", x, y, width, height);
   CreateCenteredLabel("LBL_CREDIT", x + width / 2, y + height / 2, "by Syakir Arslan", PANEL_MUTED_TEXT, 8);
}

void CreateLabel(const string key, const int x, const int y, const string text, const color clr, const int fontSize)
{
   string name = Obj(key);
   color labelColor = clr;
   if(StringFind(key, "LBL_") == 0 && clr == PANEL_TEXT)
      labelColor = PANEL_MUTED_TEXT;

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER);
}

void CreateCenteredLabel(const string key, const int x, const int y, const string text, const color clr, const int fontSize)
{
   string name = Obj(key);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER);
}

void CreateRightLabel(const string key, const int x, const int y, const string text, const color clr, const int fontSize)
{
   string name = Obj(key);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER);
}

void CreateReadout(const string key, const int x, const int y, const int width, const int height, const string text)
{
   string boxName = Obj(key + "_BOX");
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, PANEL_BOX_BG);
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, PANEL_BOX_BG);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, boxName, OBJPROP_ZORDER, PANEL_ZORDER);

   CreateLabel(key, x + 2, y + 3, text, PANEL_TEXT, 9);
}

void CreateEdit(const string key, const int x, const int y, const int width, const int height, const string text)
{
   string name = Obj(key);
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, PANEL_EDIT_BG);
   ObjectSetInteger(0, name, OBJPROP_COLOR, PANEL_TEXT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, PANEL_BORDER);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER);
}

void CreateButton(const string key, const int x, const int y, const int width, const int height, const string text)
{
   string name = Obj(key);
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, PANEL_OFF_BG);
   ObjectSetInteger(0, name, OBJPROP_COLOR, PANEL_BUTTON_TEXT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, PANEL_BORDER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Tahoma");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_ZORDER);
}

void SetText(const string key, const string text)
{
   SetObjectText(key, text);
}

void SetObjectText(const string key, const string text)
{
   string name = Obj(key);
   if(ObjectFind(0, name) >= 0)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void SetObjectBg(const string key, const color bg)
{
   string name = Obj(key);
   if(ObjectFind(0, name) >= 0)
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
}

void SetObjectColor(const string key, const color clr)
{
   string name = Obj(key);
   if(ObjectFind(0, name) >= 0)
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void SetObjectBorder(const string key, const color clr)
{
   string name = Obj(key);
   if(ObjectFind(0, name) >= 0)
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clr);
}

void SetTabStyle(const string key, const bool active)
{
   SetObjectBg(key, active ? PANEL_ON_BG : PANEL_BOX_BG);
   SetObjectColor(key, active ? PANEL_BUTTON_TEXT : PANEL_MUTED_TEXT);
   SetObjectBorder(key, active ? PANEL_ACCENT : PANEL_BORDER);
}

void SetToggleStyle(const string key, const bool enabled)
{
   SetObjectBg(key, enabled ? PANEL_ON_BG : PANEL_OFF_BG);
   SetObjectColor(key, PANEL_BUTTON_TEXT);
   SetObjectBorder(key, enabled ? PANEL_ACCENT : PANEL_WARNING);
}

void ResetButtonState(const string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

string Obj(const string key)
{
   return PANEL_PREFIX + key;
}

void DeleteControlPanel()
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PANEL_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}
