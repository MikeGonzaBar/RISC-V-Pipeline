[CmdletBinding()]
param(
    [string]$TopModule = "RISC_V_Single_Cycle",

    [string]$OutDir = "",

    [string]$Verilator = "verilator",

    [switch]$RequireVerilator,

    [switch]$StrictWarnings
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$srcDir = Join-Path $repoRoot "src"

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $repoRoot ".codex-sim\verilator"
}

$OutDir = [System.IO.Path]::GetFullPath($OutDir)

$verilatorTool = Get-Command $Verilator -ErrorAction SilentlyContinue
if (-not $verilatorTool) {
    if ($RequireVerilator) {
        throw "Verilator command '$Verilator' was not found on PATH."
    }

    Write-Host "Verilator not found; skipped lint."
    exit 0
}

$rtlFiles = Get-ChildItem -Path $srcDir -Filter "*.v" |
    Where-Object { $_.Name -notmatch '_TB\.v$' } |
    Sort-Object Name |
    ForEach-Object { $_.FullName }

if ($rtlFiles.Count -eq 0) {
    throw "No RTL files found under $srcDir"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$lintArgs = @(
    "--lint-only",
    "--Wall",
    "--timing",
    "--top-module", $TopModule,
    "--Mdir", $OutDir
)

if (-not $StrictWarnings) {
    $lintArgs += "--Wno-fatal"
}

$lintArgs += $rtlFiles

Push-Location $repoRoot
try {
    Write-Host "Running Verilator lint for top module $TopModule..."
    & $verilatorTool.Source @lintArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
