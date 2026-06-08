// HoekaGataIndicator MT5
// Shared inputs, constants, buffers, and lightweight data types.

enum DisplayMode
{
   DisplayLatestOnly = 0,
   DisplayHistory    = 1
};

input group "Config / Rules"
input int         InpPivotMin             = 3;
input int         InpPivotMax             = 20;
input double      InpWave2FibTolerance    = 0.05;
input bool        InpUseEntryFibBarrier   = false;
input double      InpEntryTriggerFibLevel = 1.272;
input bool        InpUseParallelSlopeRule = true;
input double      InpParallelTolerance    = 0.14;
input int         InpMinBarsBetweenEntry  = 20;

input group "Alerts"
input bool        InpEnableBuyAlerts      = true;
input bool        InpEnableSellAlerts     = true;
input bool        InpEnablePushNotify     = false;

input group "Display"
input bool        InpShowWaveLines        = true;
input bool        InpShowTrendLines       = true;
input bool        InpShowFibLines         = true;
input bool        InpShowEntryFib1618     = true;
input bool        InpShowEntryPriceLine   = true;
input bool        InpShowWaveLabels       = true;

input group "General"
input DisplayMode InpDisplayMode          = DisplayLatestOnly;
input bool        InpEnableDrawing        = true;
input bool        InpSuppressSignalsWhileTradeOpen = true;
input int         InpSignalConfirmDelaySeconds = 1;
input int         InpMaxBarsToProcess     = 300;
input int         InpDrawingLineWidth     = 1;
input bool        InpShowProbabilityPanel = true;
input bool        InpPublicZoneLabels     = true;

input group "Style"
input color       InpDownColor            = clrRed;
input color       InpUpColor              = clrLime;
input color       InpEntryBuyColor        = clrAqua;
input color       InpEntrySellColor       = clrOrange;
input color       InpNormalLabelColor     = clrGray;
input color       InpWave2FibColor        = clrYellow;
input color       InpFib1618Color         = clrMagenta;
input color       InpTargetFibColor       = clrBlue;
input color       InpNeutralColor         = clrWhite;

double BuyBuffer[];
double SellBuffer[];
double SignalSLBuffer[];
double SignalTPBuffer[];
double SignalExtendTPBuffer[];

const int    RAW_PIVOT_LEN    = 2;
const double WAVE2_FIB_LEVEL  = 0.618;
const double WAVE2_FIB_LEVEL2 = 0.500;
const double ENTRY_FIB_LEVEL  = 1.618;
const double ENTRY_NEG_LEVEL  = -0.270;
const double WAVE4_FIB_LEVEL  = 0.618;
const double WAVE4_FIB_LEVEL2 = 0.786;
const string PREFIX           = "HoekaGataIndicator_MT5_";

datetime g_lastAlertTime = 0;
string   g_lastAlertSide = "";

datetime g_pendingSignalFirstSeenTime = 0;
datetime g_pendingSignalBarTime = 0;
int      g_pendingSignalDirection = 0;
double   g_pendingSignalEntry = 0.0;
double   g_pendingSignalSL = 0.0;
double   g_pendingSignalTP = 0.0;
double   g_pendingSignalExtendTP = 0.0;

datetime g_confirmedSignalBarTime = 0;
int      g_confirmedSignalDirection = 0;
double   g_confirmedSignalEntry = 0.0;
double   g_confirmedSignalSL = 0.0;
double   g_confirmedSignalTP = 0.0;
double   g_confirmedSignalExtendTP = 0.0;

struct SwingPoint
{
   int    type;
   int    index;
   double price;
};

struct OpenTrade
{
   string key;
   int    dir;
   int    entryIndex;
   double entry;
   double sl;
   double tp;
};

struct ClosedTrade
{
   int dir;
   int result;
};
