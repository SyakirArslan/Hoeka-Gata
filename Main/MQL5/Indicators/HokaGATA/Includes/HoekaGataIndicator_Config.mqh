// HokaGATA Engulfing Breakout MT5
// Shared inputs, constants, buffers, and lightweight data types.
// Mirrors Source/HoekaGata_Engulfing.pine 1:1.

enum LineStyleMode
{
   LineSolid  = 0,      // Solid
   LineDashed = 1       // Dashed
};

enum BodyBreakStyleMode
{
   BodyBreakDotted = 0, // Dotted
   BodyBreakDashed = 1, // Dashed
   BodyBreakSolid  = 2  // Solid
};

enum EngulfLabelSize
{
   EngulfTiny   = 0,    // Tiny
   EngulfSmall  = 1,    // Small
   EngulfNormal = 2,    // Normal
   EngulfLarge  = 3     // Large
};

input group "1. ENGULFING PATTERN"
input double             InpMinBodyX      = 1.2;            // Minimum Body
input double             InpMinBodyP      = 50.0;           // Candle Body (%)

input group "2. ENTRY"
input double             InpBufEntryX     = 0.10;           // Breakout Tolerance Entry (ATR)
input double             InpBufSLX        = 0.10;           // Breakout Tolerance SL (ATR)
input double             InpBodyBreakTol  = 0.00;           // Body-Break Tolerance (ATR)
input bool               InpCancelOpp     = true;           // Cancel on Opposite Signal

input group "3. RISK & REWARD"
input double             InpRrRatio       = 2.0;            // Risk : Reward 1 :

input group "4. DISPLAY (Entry / SL / TP)"
input bool               InpShowLines     = true;           // Entry / SL / TP Lines
input EngulfLabelSize    InpLabelSize     = EngulfSmall;    // Label Size
input LineStyleMode      InpLineStyle     = LineDashed;     // Line Style
input int                InpExtendB       = 3;              // Line Length
input int                InpKeepN         = 3;              // Displayed Setups

input group "4b. RESULTS SUMMARY"
input bool               InpShowTable     = true;           // Show Panel
input EngulfLabelSize    InpPanelSize     = EngulfSmall;    // Panel Text Size

input group "5. BODY-BREAK (TRIGGER)"
input BodyBreakStyleMode InpBodyBreakStyle = BodyBreakDotted; // Body-Break Line Style

input group "6. COLORS"
input color              InpCEntryLine    = C'120,123,134'; // Entry Line
input color              InpCSL           = C'239,83,80';   // Stop Loss
input color              InpCTP           = C'38,166,154';  // Take Profit
input color              InpCBodyBreak    = C'189,189,189'; // Body-Break
input color              InpCBuyText      = C'38,166,154';  // BUY Text
input color              InpCSellText     = C'239,83,80';   // SELL Text

// Signal buffers (contract with HoekaGataAlgo EA - MUST remain 4 buffers)
double BuyBuffer[];
double SellBuffer[];
double SignalSLBuffer[];
double SignalTPBuffer[];

// .pine: keepBodyHistory = keepN
const string PREFIX = "HoekaGATA_Engulf_";

// Setup state machine (.pine: state 0, 1, 2, 3, -1, -2, -3)
const int STATE_NONE          = 0;
const int STATE_BUY_SETUP     = 1;   // waiting for break-body trigger
const int STATE_BUY_ARMED     = 2;   // break-body touched, pending at wick
const int STATE_BUY_ACTIVE    = 3;   // pending filled
const int STATE_SELL_SETUP    = -1;
const int STATE_SELL_ARMED    = -2;
const int STATE_SELL_ACTIVE   = -3;


