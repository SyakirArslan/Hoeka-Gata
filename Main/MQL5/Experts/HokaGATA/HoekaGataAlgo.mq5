#property copyright "HoekaGata conversion workspace"
#property link      ""
#property version   "1.00"
#property strict
#property tester_indicator "HokaGATA\\HoekaGataIndicator.ex5"

#include <Trade/Trade.mqh>

input bool   InpAlgoEnabled         = false;
input bool   InpAllowBuy            = true;
input bool   InpAllowSell           = true;
input bool   InpUseExtendTP         = false;
input double InpRiskBuyPercent      = 5;
input double InpRiskSellPercent     = 5;
input bool   InpUseTradingTime      = false;
input string InpStartTime           = "07:00";
input string InpEndTime             = "03:00";
input bool   InpUseSpreadFilter     = true;
input int    InpMaxSpreadPoints     = 25;
input ulong  InpMagicNumber         = 20260525;
input bool   InpUseClosedBarSignal  = false;
input int    InpMinBarsBetweenEntry = 30;
input int    InpDeviationPoints     = 20;
input bool   InpRecalculateSLTPFromActualEntry = true;
input int    InpMaxConsecutiveLosses = 0;
input bool   InpVpsMode             = true;
input bool   InpShowPanel           = true;
input int    InpPanelUpdateSeconds  = 1;

const string PANEL_PREFIX = "HGCP_";
const int    PANEL_MIN_WIDTH = 190;
const int    PANEL_FULL_WIDTH = 220;
const int    PANEL_HEADER_HEIGHT = 28;
const int    PANEL_ROW_HEIGHT = 25;
const int    PANEL_STATUS_HEIGHT = 48;
const long   PANEL_ZORDER = 1000;
const color  PANEL_BG = C'27,29,32';
const color  PANEL_BOX_BG = C'34,37,41';
const color  PANEL_HEADER_BG = C'19,21,24';
const color  PANEL_BORDER = C'75,80,86';
const color  PANEL_EDIT_BG = C'29,32,36';
const color  PANEL_ON_BG = C'0,145,145';
const color  PANEL_OFF_BG = C'139,66,46';
const color  PANEL_TEXT = C'232,236,240';
const color  PANEL_MUTED_TEXT = C'166,174,184';
const color  PANEL_ACCENT = C'0,210,210';
const color  PANEL_WARNING = C'236,112,72';
const color  PANEL_BUTTON_TEXT = C'245,248,250';

CTrade trade;

int      g_indicatorHandle = INVALID_HANDLE;
string   g_indicatorShortName = "";
bool     g_algoEnabled;
bool     g_allowBuy;
bool     g_allowSell;
bool     g_useExtendTP;
bool     g_useTradingTime;
bool     g_useSpreadFilter;
bool     g_useClosedBarSignal;
bool     g_recalculateSLTPFromActualEntry;
bool     g_vpsMode;
bool     g_showPanel;
double   g_riskBuyPercent;
double   g_riskSellPercent;
int      g_startMinutes = 0;
int      g_endMinutes = 0;
int      g_maxSpreadPoints;
int      g_minBarsBetweenEntry;
int      g_deviationPoints;
int      g_maxConsecutiveLosses;
int      g_consecutiveLosses = 0;
int      g_panelUpdateSeconds;
ulong    g_magicNumber;
datetime g_lastSignalTime = 0;
string   g_lastSignalText = "None";
string   g_reason = "Initializing";
ulong    g_lastTradeRetcode = 0;
double   g_lastSignalEntry = 0.0;
double   g_lastSignalSL = 0.0;
double   g_lastSignalTP = 0.0;
double   g_lastCalculatedLot = 0.0;
int      g_panelX = 8;
int      g_panelY = 18;
bool     g_panelMinimized = false;
bool     g_panelVisible = true;
bool     g_panelDragging = false;
int      g_panelPage = 0;
int      g_dragOffsetX = 0;
int      g_dragOffsetY = 0;
bool     g_mouseScrollStored = false;
bool     g_originalMouseScroll = true;
datetime g_lastPanelUpdateTime = 0;
bool     g_missingIndicatorWarningShown = false;
bool     g_indicatorLookupAttempted = false;

#include "Includes\HoekaGataAlgo_Config.mqh"
#include "Includes\HoekaGataAlgo_Trading.mqh"
#include "Includes\HoekaGataAlgo_Panel.mqh"

int OnInit()
{
   g_algoEnabled = InpAlgoEnabled;
   g_allowBuy = InpAllowBuy;
   g_allowSell = InpAllowSell;
   g_useExtendTP = InpUseExtendTP;
   g_useTradingTime = InpUseTradingTime;
   g_useSpreadFilter = InpUseSpreadFilter;
   g_useClosedBarSignal = InpUseClosedBarSignal;
   g_recalculateSLTPFromActualEntry = InpRecalculateSLTPFromActualEntry;
   g_vpsMode = InpVpsMode;
   g_showPanel = InpShowPanel;
   g_riskBuyPercent = InpRiskBuyPercent;
   g_riskSellPercent = InpRiskSellPercent;
   g_maxSpreadPoints = InpMaxSpreadPoints;
   g_minBarsBetweenEntry = MathMax(InpMinBarsBetweenEntry, 0);
   g_deviationPoints = MathMax(InpDeviationPoints, 0);
   g_maxConsecutiveLosses = MathMax(InpMaxConsecutiveLosses, 0);
   g_panelUpdateSeconds = MathMax(InpPanelUpdateSeconds, 1);
   g_magicNumber = InpMagicNumber;

   ParseTimeOrDefault(InpStartTime, 7 * 60, g_startMinutes);
   ParseTimeOrDefault(InpEndTime, 3 * 60, g_endMinutes);
   LoadPanelConfig();

   trade.SetExpertMagicNumber(g_magicNumber);
   trade.SetDeviationInPoints(g_deviationPoints);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, g_showPanel && !g_vpsMode);

   if(!EnsureIndicatorSignalSource())
   {
      g_reason = IndicatorMissingReason();
      if(g_showPanel)
         CreateControlPanel();
      EventSetTimer(1);
      return INIT_SUCCEEDED;
   }

   if(g_showPanel)
      CreateControlPanel();
   EventSetTimer(1);
   g_reason = "Ready";
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   StopPanelDrag();
   ReleaseIndicatorHandle();
   // Chart indicators are user-managed. Keep them attached when the EA is
   // reloaded because of input changes, recompiles, account changes, or restarts.
   DeleteControlPanel();
   ChartRedraw(0);
}

void OnTick()
{
   if(!g_vpsMode)
      ProcessSignal();
   if(g_showPanel && !g_vpsMode)
      UpdateControlPanel();
}

void OnTimer()
{
   ProcessSignal();
   if(g_showPanel)
      UpdateControlPanelIfDue();
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   HandleTradeTransaction(trans);
}

void UpdateControlPanelIfDue()
{
   if(!g_showPanel)
      return;

   if(!g_vpsMode)
   {
      UpdateControlPanel();
      return;
   }

   datetime now = ServerNow();
   if(g_lastPanelUpdateTime > 0 && (int)(now - g_lastPanelUpdateTime) < g_panelUpdateSeconds)
      return;

   g_lastPanelUpdateTime = now;
   UpdateControlPanel();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!g_showPanel)
      return;

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      HandlePanelClick(sparam);
      return;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      ReadPanelInputs(sparam);
      UpdateControlPanel();
      ChartRedraw(0);
      return;
   }

   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      HandleObjectDrag(sparam);
      return;
   }

   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      HandleMouseMove((int)lparam, (int)dparam, sparam);
      return;
   }
}
