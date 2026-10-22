#Requires -Version 5.1
<#
.SYNOPSIS
    Compile the HoekaGATA MQL5 programs and deploy them into the running MT5 terminal.

.DESCRIPTION
    One-shot script:
      1. Resolves the MT5 data folder (the one the running terminal actually uses).
      2. Compiles the requested .mq5 files with metaeditor64.exe.
      3. Fails fast on any compiler error.
      4. Copies source + .ex5 into <data folder>\MQL5.
      5. Verifies every deployed file by SHA256 hash.

.PARAMETER Target
    Indicator, EA, or All. Default: All.

.PARAMETER NoDeploy
    Compile only, do not copy into MT5.

.PARAMETER Restart
    Restart terminal64.exe afterwards (needed when a NEW folder is deployed).
    This closes MT5 without saving unsaved panel changes.

.EXAMPLE
    .\Build-MT5.ps1
    .\Build-MT5.ps1 -Target Indicator
    .\Build-MT5.ps1 -Target Indicator -Restart
#>
[CmdletBinding()]
param(
    [ValidateSet('Indicator', 'EA', 'All')]
    [string]$Target = 'All',

    [switch]$NoDeploy,

    [switch]$Restart
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- configuration
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # ...\HoekaGATA
$RepoMql5 = Join-Path $RepoRoot 'Main\MQL5'

$MetaEditorCandidates = @(
    'C:\Program Files\MetaTrader 5\metaeditor64.exe',
    'C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe'
)

$Programs = @{
    Indicator = @{
        Name = 'HoekaGataIndicator'
        Dir  = 'Indicators\HokaGATA'
        File = 'HoekaGataIndicator.mq5'
    }
    EA        = @{
        Name = 'HoekaGataAlgo'
        Dir  = 'Experts\HokaGATA'
        File = 'HoekaGataAlgo.mq5'
    }
}

# --------------------------------------------------------------------- helpers
function Write-Step([string]$Text) {
    Write-Host ''
    Write-Host "== $Text" -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host "   [OK]   $Text" -ForegroundColor Green
}

function Write-Warn2([string]$Text) {
    Write-Host "   [WARN] $Text" -ForegroundColor Yellow
}

function Write-Fail([string]$Text) {
    Write-Host "   [FAIL] $Text" -ForegroundColor Red
}

function Get-MetaEditorPath {
    foreach ($p in $MetaEditorCandidates) {
        if (Test-Path $p) { return $p }
    }
    throw "metaeditor64.exe not found. Looked in: $($MetaEditorCandidates -join '; ')"
}

function Get-Mt5DataFolder {
    # The running terminal wins: its install folder maps to a data folder via origin.txt.
    $terminals = Get-Process -Name 'terminal64' -ErrorAction SilentlyContinue
    $roots = @()
    $appDataTerminal = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
    if (Test-Path $appDataTerminal) {
        $roots = @(Get-ChildItem $appDataTerminal -Directory -ErrorAction SilentlyContinue)
    }

    if ($terminals) {
        $exeDir = Split-Path -Parent $terminals[0].Path
        foreach ($r in $roots) {
            $originFile = Join-Path $r.FullName 'origin.txt'
            if (Test-Path $originFile) {
                $origin = (Get-Content $originFile -Raw).Trim()
                if ($origin -and ($origin.TrimEnd('\') -ieq $exeDir.TrimEnd('\'))) {
                    return $r.FullName
                }
            }
        }
        Write-Warn2 'Running terminal folder not matched by origin.txt; falling back to scan.'
    }

    $withMql5 = @($roots | Where-Object { Test-Path (Join-Path $_.FullName 'MQL5') })
    if ($withMql5.Count -eq 0) { throw "No MT5 data folder found under $appDataTerminal" }
    if ($withMql5.Count -gt 1) {
        Write-Warn2 'Multiple MT5 data folders found, using the most recently written one.'
    }
    return ($withMql5 | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Invoke-Compile {
    param([string]$MetaEditor, [string]$SourcePath, [string]$Label)

    $log = Join-Path $env:TEMP "hg_build_$Label.log"
    if (Test-Path $log) { Remove-Item $log -Force }

    $proc = Start-Process -FilePath $MetaEditor `
        -ArgumentList "/compile:`"$SourcePath`"", "/log:`"$log`"" `
        -Wait -PassThru -WindowStyle Hidden

    if (-not (Test-Path $log)) {
        throw "Compile produced no log for $Label (exit code $($proc.ExitCode))."
    }

    # MetaEditor writes the log as UTF-16 - must use -Encoding Unicode.
    $lines = Get-Content $log -Encoding Unicode
    $result = $lines | Select-String 'Result:' | Select-Object -First 1
    if (-not $result) { throw "Compiler log has no 'Result:' line for $Label." }

    $problems = $lines | Select-String -Pattern ':\s+(error|warning)\s'
    if ($problems) { $problems | ForEach-Object { Write-Host "   $($_.Line.Trim())" } }

    $resultText = $result.Line.Trim()
    $hasError = $false
    if ($resultText -match '(\d+)\s+errors?') { $hasError = ([int]$Matches[1] -gt 0) }

    if ($hasError) {
        Write-Fail "$Label -> $resultText"
        throw "Compilation failed for $Label."
    }

    Write-Ok "$Label -> $resultText"
    Remove-Item $log -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------------ start
Write-Step 'HoekaGATA build'
Write-Host "   repo  : $RepoRoot"

$MetaEditor = Get-MetaEditorPath
Write-Host "   editor: $MetaEditor"

if ($NoDeploy) {
    $DataFolder = $null
    Write-Host '   deploy: disabled (-NoDeploy)'
} else {
    $DataFolder = Get-Mt5DataFolder
    Write-Host "   mt5   : $DataFolder"
}

$running = Get-Process -Name 'terminal64' -ErrorAction SilentlyContinue
if ($running) { Write-Host "   mt5 process: RUNNING (pid $($running.Id -join ','))" }
else { Write-Host '   mt5 process: STOPPED' }

# ---------------------------------------------------------------------- compile
$selected = switch ($Target) {
    'All'   { @('Indicator', 'EA') }
    default { @($Target) }
}

Write-Step 'Compiling'
foreach ($key in $selected) {
    $p = $Programs[$key]
    $src = Join-Path $RepoMql5 (Join-Path $p.Dir $p.File)
    if (-not (Test-Path $src)) { throw "Source not found: $src" }
    Invoke-Compile -MetaEditor $MetaEditor -SourcePath $src -Label $p.Name
}

# ----------------------------------------------------------------------- deploy
$createdNewFolder = $false
if (-not $NoDeploy) {
    Write-Step 'Deploying'

    foreach ($key in $selected) {
        $p = $Programs[$key]
        $srcDir = Join-Path $RepoMql5 $p.Dir
        $dstDir = Join-Path $DataFolder "MQL5\$($p.Dir)"

        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
            $createdNewFolder = $true
            Write-Warn2 "Created new folder: $dstDir"
        }

        Copy-Item (Join-Path $srcDir '*') $dstDir -Recurse -Force
        Write-Ok "$($p.Name) copied to MQL5\$($p.Dir)"
    }

    Write-Step 'Verifying (SHA256)'
    $mismatch = 0
    foreach ($key in $selected) {
        $p = $Programs[$key]
        $srcDir = Join-Path $RepoMql5 $p.Dir
        $dstDir = Join-Path $DataFolder "MQL5\$($p.Dir)"

        foreach ($f in (Get-ChildItem $srcDir -Recurse -File)) {
            $rel = $f.FullName.Substring($srcDir.Length).TrimStart('\')
            $dst = Join-Path $dstDir $rel
            if (-not (Test-Path $dst)) {
                Write-Fail "$($p.Name)\$rel missing in MT5"
                $mismatch++
                continue
            }
            if ((Get-FileHash $f.FullName).Hash -ne (Get-FileHash $dst).Hash) {
                Write-Fail "$($p.Name)\$rel hash mismatch"
                $mismatch++
            }
        }
    }
    if ($mismatch -eq 0) { Write-Ok 'All files verified identical.' }
    else { throw "$mismatch file(s) failed verification." }

    foreach ($key in $selected) {
        $p = $Programs[$key]
        $ex5 = Join-Path $DataFolder "MQL5\$($p.Dir)\$($p.Name).ex5"
        if (Test-Path $ex5) {
            $item = Get-Item $ex5
            Write-Host ("   {0}.ex5 : {1:N0} bytes @ {2}" -f $p.Name, $item.Length, $item.LastWriteTime.ToString('HH:mm:ss'))
        }
    }
}

# ---------------------------------------------------------------------- restart
if ($Restart) {
    Write-Step 'Restarting MT5'
    $proc = Get-Process -Name 'terminal64' -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Stop-Process -Force
        Start-Sleep -Seconds 3
        Write-Ok 'Terminal closed.'
    }
    Start-Process -FilePath (Join-Path (Split-Path -Parent $MetaEditor) 'terminal64.exe')
    Start-Sleep -Seconds 6
    Write-Ok 'Terminal started.'
}

# ------------------------------------------------------------------------- tips
Write-Step 'Done'
if ($createdNewFolder -and -not $Restart) {
    Write-Host '   A NEW folder was deployed - MT5 must be fully restarted before the' -ForegroundColor Yellow
    Write-Host '   Navigator shows it. Re-run with -Restart or restart MT5 manually.' -ForegroundColor Yellow
}
Write-Host '   In MT5: remove and re-attach the indicator so changed inputs take effect.' -ForegroundColor Cyan
