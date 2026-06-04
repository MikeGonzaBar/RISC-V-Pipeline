[CmdletBinding()]
param(
    [string]$ProjectDir = "",

    [string]$ProjectName = "RISC_V_Single_Cycle",

    [ValidateSet("Project", "Map", "Compile")]
    [string]$Flow = "Map",

    [switch]$RequireQuartus
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectPath {
    param(
        [string]$PathValue,
        [string]$DefaultPath
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return (Resolve-Path $DefaultPath).Path
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return (Resolve-Path $PathValue).Path
    }

    return (Resolve-Path (Join-Path (Get-Location) $PathValue)).Path
}

function Read-VerilogAssignments {
    param([string]$QsfPath)

    $assignments = New-Object System.Collections.Generic.List[string]
    foreach ($line in Get-Content $QsfPath) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
            continue
        }

        if ($trimmed -match '^set_global_assignment\s+-name\s+VERILOG_FILE\s+(.+)$') {
            $value = $Matches[1].Trim()
            if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $assignments.Add($value)
        }
    }

    return $assignments
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$projectPath = Resolve-ProjectPath $ProjectDir (Join-Path $repoRoot "proj_quartus")
$qpf = Join-Path $projectPath "$ProjectName.qpf"
$qsf = Join-Path $projectPath "$ProjectName.qsf"

if (-not (Test-Path $qpf)) {
    throw "Quartus project file not found: $qpf"
}

if (-not (Test-Path $qsf)) {
    throw "Quartus settings file not found: $qsf"
}

$sourceRefs = Read-VerilogAssignments $qsf
if ($sourceRefs.Count -eq 0) {
    throw "No VERILOG_FILE assignments found in $qsf"
}

$missingSources = New-Object System.Collections.Generic.List[string]
$simulationOnlySources = New-Object System.Collections.Generic.List[string]

foreach ($sourceRef in $sourceRefs) {
    $candidatePath = [System.IO.Path]::GetFullPath((Join-Path $projectPath $sourceRef))
    if (-not (Test-Path $candidatePath)) {
        $missingSources.Add($sourceRef)
    }

    $normalized = $sourceRef.Replace("\", "/")
    if ($normalized -match '(^|/)tests/' -or $normalized -match '_TB\.v$') {
        $simulationOnlySources.Add($sourceRef)
    }
}

if ($missingSources.Count -gt 0) {
    Write-Error ("Missing QSF source file(s): " + ($missingSources -join ", "))
}

if ($simulationOnlySources.Count -gt 0) {
    Write-Error ("Simulation-only file(s) should not be in the Quartus source set: " + ($simulationOnlySources -join ", "))
}

Write-Host "Quartus project metadata validated: $($sourceRefs.Count) Verilog source file(s)."

$quartusMap = Get-Command quartus_map -ErrorAction SilentlyContinue
$quartusSh = Get-Command quartus_sh -ErrorAction SilentlyContinue

if ($Flow -eq "Project") {
    if (-not $quartusSh) {
        if ($RequireQuartus) {
            throw "quartus_sh was not found on PATH."
        }
        Write-Host "quartus_sh not found; skipped Quartus tool project-open validation."
        exit 0
    }

    Push-Location $projectPath
    try {
        & $quartusSh.Source "--tcl_eval" "project_open $ProjectName; project_close"
        exit $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

if ($Flow -eq "Map") {
    if (-not $quartusMap) {
        if ($RequireQuartus) {
            throw "quartus_map was not found on PATH."
        }
        Write-Host "quartus_map not found; skipped Quartus map validation."
        exit 0
    }

    Push-Location $projectPath
    try {
        & $quartusMap.Source "--read_settings_files=on" "--write_settings_files=off" $ProjectName "-c" $ProjectName
        exit $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

if (-not $quartusSh) {
    if ($RequireQuartus) {
        throw "quartus_sh was not found on PATH."
    }
    Write-Host "quartus_sh not found; skipped full Quartus compile."
    exit 0
}

Push-Location $projectPath
try {
    & $quartusSh.Source "--flow" "compile" $ProjectName "-c" $ProjectName
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
