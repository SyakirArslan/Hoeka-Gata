---
name: hoekagata-build
description: Compile the HoekaGATA MQL5 indicator/EA with MetaEditor and deploy them into the local MT5 terminal. Use when the user asks to "compile", "build", "rebuild", "update MT5", "deploy ke MT5", "masukkan ke folder MT5", or wants to immediately test changes on a chart.
---

# HoekaGATA — compile & deploy to MT5

One command does everything:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File 'c:\Data Syakir\HoekaGATA\Main\Tools\Build-MT5.ps1'
```

## 1. What the script does

| Step | Detail |
| --- | --- |
| Resolve MT5 data folder | Reads the running `terminal64.exe` path, matches it against `origin.txt` in each `%APPDATA%\MetaQuotes\Terminal\<hash>` folder. Falls back to "most recently written folder that has `MQL5`". |
| Compile | `metaeditor64.exe /compile:<path> /log:<path>` via `Start-Process -Wait`. |
| Gate | Any `N errors` with `N > 0` aborts — nothing is deployed on a failed build. |
| Deploy | Copies the **whole** `Indicators\HokaGATA` / `Experts\HokaGATA` folder (source + `.ex5`). |
| Verify | SHA256 of every source file and `.ex5` compared repo vs MT5. Aborts on any mismatch. |

## 2. Parameters

| Parameter | Use |
| --- | --- |
| `-Target Indicator` | Indicator only (fastest loop while tuning visuals) |
| `-Target EA` | EA only |
| `-Target All` | Both — **default** |
| `-NoDeploy` | Compile only, do not touch MT5 |
| `-Restart` | Kill and relaunch `terminal64.exe` afterwards |

Examples:

```powershell
# normal iteration
.\Build-MT5.ps1 -Target Indicator

# after adding files/folders - MT5 must be restarted to rebuild the Navigator index
.\Build-MT5.ps1 -Target Indicator -Restart

# syntax check only
.\Build-MT5.ps1 -NoDeploy
```

## 3. Reading the output

Success looks like this:

```
== HoekaGATA build
   repo  : C:\Data Syakir\HoekaGATA
   editor: C:\Program Files\MetaTrader 5\metaeditor64.exe
   mt5   : C:\Users\<user>\AppData\Roaming\MetaQuotes\Terminal\<hash>
   mt5 process: STOPPED

== Compiling
   [OK]   HoekaGataIndicator -> Result: 0 errors, 0 warnings, 1955 ms elapsed

== Deploying
   [OK]   HoekaGataIndicator copied to MQL5\Indicators\HokaGATA

== Verifying (SHA256)
   [OK]   All files verified identical.
   HoekaGataIndicator.ex5 : 60,004 bytes @ 18:50:01

== Done
```

Failure modes:

| Output | Meaning | Fix |
| --- | --- | --- |
| `[FAIL] ... -> Result: N errors` | Compile error | Read the printed error lines above it. **Nothing was deployed.** |
| `Compile produced no log` | MetaEditor never ran | Check the path in `$MetaEditorCandidates`. |
| `hash mismatch` | Copy blocked (file locked by MT5) | Close MT5 and retry. |
| `[WARN] Created new folder` | Brand-new directory deployed | Re-run with `-Restart`, else the Navigator will not show it. |

## 4. Rules that keep builds working

1. **Never trust the exit code alone.** MetaEditor can exit `0` while the log says errors.
   Always parse the `Result:` line — the script already does this.
2. **Compiler log is UTF-16.** `Get-Content` without `-Encoding Unicode` shows garbage.
3. **Writing `.ex5` into MT5 while the terminal is open is fine**; adding a **new subfolder**
   while it runs is not visible until a full restart.
4. **Do not skip the SHA256 verify.** It catches silent partial copies and stale `.ex5`.
5. **Hash mismatch on `*.mqh` only** usually means the `.ex5` is fine but sources diverged —
   still fix it, MT5 compiles from the deployed sources.
6. After deploying, the user must **remove and re-attach** the program on the chart when
   inputs or buffer counts changed.
