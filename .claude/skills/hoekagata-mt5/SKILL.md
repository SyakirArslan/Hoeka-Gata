---
name: hoekagata-mt5
description: Build, compile, and deploy the HoekaGata MT5 indicator and EA. Use when working on Source/*.pine, Main/MQL5/Indicators/HokaGATA, or Main/MQL5/Experts/HokaGATA — covers the Pine-to-MQL5 rules, the 4-buffer + HG_SIG_* contract, the MetaEditor CLI compile loop, and deployment into the local MT5 terminal.
---

# HoekaGata MT5 — build / compile / deploy

## 1. What this project is

Two MT5 programs that must stay in sync:

| Program | Path | Role |
| --- | --- | --- |
| Indicator | `Main/MQL5/Indicators/HokaGATA/HoekaGataIndicator.mq5` | Signal engine. Detects setups, draws Entry/SL/TP/BreakBody lines + stats panel, publishes signals. |
| EA | `Main/MQL5/Experts/HokaGATA/HoekaGataAlgo.mq5` | Reads the indicator's signal and executes market orders. |

The indicator is a **1:1 port of the Pine script in `Source/`**. Pine is the single source of
truth — when Pine and MQL5 disagree, MQL5 is wrong.

**Current strategy: `Engulfing Breakout` (v2.00).** The old Wave3 Pro / Fibonacci logic
(waves 0-1-2-3, fib -0.270 / 0.618 / 0.786) was fully removed. Do not reintroduce it.

There is **no pattern-mode input**. The pattern is hardcoded to **Loose**
(close beyond the previous wick only). The old `PatternMode` enum, the `PatternStrict` /
`PatternLoose` values and `InpPatMode` were all deleted; do not add them back.

## 2. The contract between indicator and EA (do not break)

The EA has **two** independent ways to read a signal. Both must keep working.

### A. GlobalVariables — preferred path

```
HG_SIG_<ChartID()>_HB          heartbeat: (double)TimeCurrent()
HG_SIG_<ChartID()>_PMIN        = InpKeepN   (compat only, EA does not read it)
HG_SIG_<ChartID()>_PMAX        = InpKeepN   (compat only, EA does not read it)

HG_SIG_<ChartID()>_C_T|_D|_E|_SL|_TP     current bar  (shift 0)
HG_SIG_<ChartID()>_P_T|_D|_E|_SL|_TP     previous bar (shift 1)
```

`_T` is the bar time and **must equal `iTime(symbol, period, shift)`** or the EA rejects the
signal. There is **no `_TX` / ExtendTP key any more** — it was removed together with the
Fibonacci logic.

### B. Indicator buffers — fallback path (`iCustom`)

Exactly **4** buffers, in this order:

| Index | Buffer | Meaning |
| --- | --- | --- |
| 0 | `BuyBuffer` | BUY entry price, else `EMPTY_VALUE` |
| 1 | `SellBuffer` | SELL entry price, else `EMPTY_VALUE` |
| 2 | `SignalSLBuffer` | stop loss |
| 3 | `SignalTPBuffer` | take profit |

`#property indicator_buffers 4` and four `SetIndexBuffer(...)` calls must match.

**Signals are published when the pending order is FILLED** (state `±3`), not when the setup is
created. The EA uses market orders, so firing at fill time makes the entry price match.

## 3. Strategy rules (mirror these exactly)

State machine, from `Includes/HoekaGataIndicator_Core.mqh`:

```
 0      idle
 ±1     setup created, waiting for break-body trigger
 ±2     break body touched, pending armed at wick
 ±3     pending filled, position active
```

Order of evaluation inside the bar loop — **this order matters**:

```
EXTEND active setup  ->  pattern detect  ->  opposite cancel
  -> break-body trigger  ->  pending fill  ->  active result
  -> freeze on TP/SL  ->  create new setup
```

Reference values, all taken from the **previous** bar:

```
o1 = open[i-1], c1 = close[i-1]
pTopRef = high[i-1], pBotRef = low[i-1]
rgPrev  = high[i-1] - low[i-1]
bdCur   = |close[i] - open[i]|

engBull = close[i] > pTopRef        // Loose, hardcoded
engBear = close[i] < pBotRef        // Loose, hardcoded

okBodyX = rgPrev > 0 ? bdCur >= rgPrev * minBodyX : bdCur > 0
okBodyP = rgPrev > 0 && bdCur / rgPrev * 100 >= minBodyP

sigBuy  = close > open && c1 < o1 && engBull && okBodyX && okBodyP
sigSell = close < open && c1 > o1 && engBear && okBodyX && okBodyP
```

Levels on a new setup:

```
breakCalc = dir==1 ? max(o1,c1) + atr*bodyBreakTol : min(o1,c1) - atr*bodyBreakTol
entryCalc = dir==1 ? high[i-1] + atr*bufEntryX    : low[i-1]  - atr*bufEntryX
slCalc    = dir==1 ? low[i-1]  - atr*bufSLX       : high[i-1] + atr*bufSLX
```

Guards (all present in Pine — keep them):

- `breakCalc` may not cross `entryCalc`; clamp to `entryCalc ∓ onetick`
- `slCalc` may not cross `entryCalc`; push to `entryCalc ∓ max(atr*bufSLX, 2*onetick)`
- only create the setup if `risk > onetick` **and** `|tpCalc - entryCalc| > onetick`

Result checks: **SL is tested before TP** on both sides.

## 4. Accepted platform differences (do not "fix" these)

| Pine | MT5 | Why |
| --- | --- | --- |
| `ta.atr(14)` = RMA | simple mean of TR | Deterministic per bar regardless of how much history is loaded. Documented in `EngulfAtrAt`. |
| Runs on last bar only (`var` state) | forward loop over full history | Same final state; MT5 must replay history. |
| `bar_index` absolute | index offset by `rates_total` | Only affects absolute indices, never distances. |
| `barstate.isconfirmed` | only closed bars are evaluated | Equivalent. |
| `label.style_label_left` | `OBJ_TEXT` + `ANCHOR_RIGHT` | Text sits left of the anchor, same visual. |
| `line.new(x1..x2)` future bars | `EngulfTimeAt()` extrapolates | Bar index -> chart time; beyond `rates_total` uses `PeriodSeconds`. |

## 5. Compile loop (MetaEditor CLI)

> **Fastest path:** run `Main\Tools\Build-MT5.ps1` — it compiles, deploys, and verifies in one
> command. See the `hoekagata-build` skill. The manual procedure below is the fallback when
> you need to control each step.

```powershell
$me  = 'C:\Program Files\MetaTrader 5\metaeditor64.exe'
$src = 'c:\Data Syakir\HoekaGATA\Main\MQL5\Indicators\HokaGATA\HoekaGataIndicator.mq5'
$log = 'c:\Data Syakir\HoekaGATA\b_ind.log'
if (Test-Path $log) { Remove-Item $log -Force }
Start-Process -FilePath $me -ArgumentList "/compile:`"$src`"", "/log:`"$log`"" -Wait
Get-Content $log -Encoding Unicode | Select-String 'error|warning|Result:'
```

Gotchas:

- The log is **UTF-16 (`-Encoding Unicode`)**. Reading it without that flag shows garbage.
- `Start-Process -Wait | Out-Null` then reading the log in a *separate* call is more reliable
  than piping in one shot.
- Success looks like `Result: 0 errors, 0 warnings`. Any error count > 0 means the `.ex5` was
  **not** regenerated — never report success without checking.
- `*.log` is git-ignored; delete build logs when done.

## 6. Deploy into the local MT5 terminal

The data folder is **not** the install folder. Resolve it dynamically:

```powershell
$dst = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory |
       Where-Object { Test-Path (Join-Path $_.FullName 'MQL5') } |
       Select-Object -First 1 -ExpandProperty FullName
```

On this machine that resolves to:

```
C:\Users\HYPE AMD\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5
```

Copy the whole folder (source **and** `.ex5`), then verify:

```powershell
$src = 'c:\Data Syakir\HoekaGATA\Main\MQL5'
New-Item -ItemType Directory -Force -Path "$dst\Indicators\HokaGATA" | Out-Null
New-Item -ItemType Directory -Force -Path "$dst\Experts\HokaGATA"    | Out-Null
Copy-Item "$src\Indicators\HokaGATA\*" "$dst\Indicators\HokaGATA\" -Recurse -Force
Copy-Item "$src\Experts\HokaGATA\*"    "$dst\Experts\HokaGATA\"    -Recurse -Force
```

Always list the destination afterwards and confirm every `.mq5`, `.mqh`, and `.ex5` is present
with a fresh timestamp.

### Navigator does not show the files — read this before debugging

**Copying files into the data folder is NOT enough.** If MT5 is running while you copy, its
Navigator tree is already built in memory and will NOT pick up a brand-new subfolder. Symptoms:

- The folder and `.ex5` are definitely on disk (correct path, valid `EX5` magic, fresh timestamp).
- Navigator shows no `HokaGATA` node, even after right-click -> Refresh.
- MetaEditor compiles the file in-place with `0 errors` — so it is not a permission problem.
- `MQL5\Logs\<date>.log` contains **no** mention of the program at all — MT5 never tried to load it.
- `MQL5\experts.dat` / `indicators.dat` timestamps are **older** than the copied files.

**Fix: fully restart the terminal.** Closing it via `Stop-Process` and starting
`terminal64.exe` again rebuilds the Navigator index. Confirm with the log afterwards:

```
Indicators  custom indicator HoekaGataIndicator (XAUUSD,H4) loaded succesfully
```

Gotchas seen in practice:

- Right-click -> Refresh is **not** always enough for a *newly created* directory.
- LiveUpdate can restart MT5 on its own (`liveupdate\terminal64.exe /update`) and log
  `MQL5 folder ... N files updated`. That is MT5 restoring its stock templates — it does **not**
  delete your files. Do not re-deploy in a panic; verify the files first.
- An `.ex5` with valid `EX5` magic and a fresh timestamp is almost never the problem. Check the
  index/log before recompiling.
- `Show All` in the Navigator filter hides files whose names do not match the filter box.

### Authoritative check: compile in-place inside the data folder

The most convincing proof that MT5 can see the file is to compile it **from the terminal data
folder itself** (not the repo copy):

```powershell
& 'C:\Program Files\MetaTrader 5\metaeditor64.exe' `
    "/compile:$dst\Indicators\HokaGATA\HoekaGataIndicator.mq5" "/log:$env:TEMP\hg.log"
Get-Content "$env:TEMP\hg.log" -Encoding Unicode | Select-String 'Result:'
```

`Result: 0 errors` here means write access and paths are fine, so any remaining "not visible"
issue is purely the Navigator index -> restart the terminal.

**Buffer-count changes require re-attaching.** If `indicator_buffers` changed, any chart that
already has the indicator loaded keeps the old compiled copy — the user must remove and re-add it.

## 7. File map

```
Source/HoekaGata_Indicator.pine              <- reference (Engulfing Breakout)

Main/MQL5/Indicators/HokaGATA/
  HoekaGataIndicator.mq5                     <- OnInit / OnCalculate / HG_SIG publishing
  Includes/HoekaGataIndicator_Config.mqh     <- inputs, enums, 4 buffers, state constants
  Includes/HoekaGataIndicator_Engulf.mqh     <- ATR + pattern detection
  Includes/HoekaGataIndicator_Core.mqh       <- state machine, levels, buffers, alerts
  Includes/HoekaGataIndicator_Drawing.mqh    <- lines/labels, time mapping, prob formatting
  Includes/HoekaGataIndicator_Panel.mqh      <- 14-row stats panel

Main/MQL5/Experts/HokaGATA/
  HoekaGataAlgo.mq5                          <- inputs, globals, event handlers
  Includes/HoekaGataAlgo_Config.mqh          <- panel config persistence + parsing helpers
  Includes/HoekaGataAlgo_Trading.mqh         <- signal read, order execution, risk
  Includes/HoekaGataAlgo_Panel.mqh           <- EA control panel
```

## 8. EA-specific notes

- `RecalculateSLTPFromActualEntry` keeps the **R:R ratio**, not Fibonacci levels. It shifts SL to
  the actual fill preserving the original risk distance, then rebuilds TP as
  `rr * riskDistance`. Do not reintroduce fib constants.
- Default is `InpRecalculateSLTPFromActualEntry = true`.
- `InpUseExtendTP`, `g_useExtendTP` and the panel `EXTEND_TP` button were **removed**.

## 9. Visual output (what the user should see)

- BreakBody line starts at `bar_index - 1`, dotted by default, label `BREAK BODY`.
- Entry line always dashed; SL/TP follow `InpLineStyle`; SL starts one bar earlier than Entry.
- All active lines/labels extend to `bar_index + extendB` every bar, then freeze on TP/SL hit.
- Opposite signal before fill deletes the setup visuals but keeps the BreakBody history.
- Panel: 14 rows, top-right, plain text (no background), `Overall:` footer.
- No candle markers / no boxes are drawn — same as Pine.

## 10. Definition of done

1. `Result: 0 errors, 0 warnings` for **both** indicator and EA.
2. Copy the fresh `.ex5` summary (name, bytes, timestamp) back to the user.
3. Deployed to the terminal data folder and the destination listing verified.
4. State any behaviour change the user must act on (buffer count, removed inputs, re-attach).
