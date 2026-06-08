# HokaGATA Pine to MT5 Mapping

Source reference:

- `MT5_Conversion/01_pine_source/HokaGATA_NZDUSD_H1_17May.pine`

MT5 output:

- `MT5_Conversion/03_mql5_indicator/MQL5/Indicators/HokaGATA/HokaGATA_Wave3_MT5.mq5`

## Converted Rules

- Raw pivot detection uses `RAW_PIVOT_LEN = 2`, matching `ta.pivothigh/high` and `ta.pivotlow/low` confirmation delay.
- Swing sequence follows the Pine alternating high/low storage with `Pivot Min` and `Pivot Max` distance filters.
- Wave 2 validation keeps the internal `0.5` to `0.618` zone plus tolerance.
- Aggressive Wave 3 signal is triggered when active 0-1-2 breaks Wave 1.
- BUY signal comes from downtrend sequence.
- SELL signal comes from uptrend sequence.
- SL uses Wave 3 `-0.27`.
- TP uses Wave 4 helper level `0.619`.
- Parallel slope validation follows the Pine `0-2` and `1-3` slope comparison.
- Probability panel tracks virtual TP/SL outcomes after entry. If TP and SL hit in the same bar, SL is counted first, matching the Pine logic.

## MT5-Specific Adjustments

- TradingView `table` is converted into MT5 `OBJ_LABEL` rows in the top-right chart corner.
- TradingView labels and lines are converted into MT5 chart objects using prefix `HokaGATA_MT5_`.
- `Latest only` clears previous HokaGATA chart objects and signal buffers before drawing the newest setup.
- Public labels default to generic names such as `ZONE`, `ENTRY`, `SL`, and `TP`; internal calculations still use the original Fibonacci levels.
- MT5 push notifications require terminal configuration. Enable `InpEnablePushNotify` only after MetaTrader notifications are set up.

