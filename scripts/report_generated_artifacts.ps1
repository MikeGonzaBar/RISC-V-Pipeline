[CmdletBinding()]
param(
    [switch]$IncludeIgnored,

    [switch]$AsCommands,

    [switch]$UntrackTracked
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

$rules = @(
    [PSCustomObject]@{ Name = "macOS metadata"; Regex = '(^|/)\.DS_Store$' },
    [PSCustomObject]@{ Name = "Quartus workspace"; Regex = '^proj_quartus/.*\.qws$' },
    [PSCustomObject]@{ Name = "Quartus database"; Regex = '^proj_quartus/(db|incremental_db|output_files)/' },
    [PSCustomObject]@{ Name = "Quartus report/programming output"; Regex = '^proj_quartus/.*\.(rpt|summary|smsg|done|pin|sof|pof|jdi|sld|cdf|log)$' },
    [PSCustomObject]@{ Name = "ModelSim generated output"; Regex = '^proj_modelsim/(work/|transcript$|.*\.(wlf|cr\.mti|log)$)' },
    [PSCustomObject]@{ Name = "Local simulator output"; Regex = '^(\.codex-sim/|obj_dir/|.*\.(vvp|vcd|fst|lxt|lxt2)$)' },
    [PSCustomObject]@{ Name = "Assembler scratch output"; Regex = '^(assembly_code/generated/|assembly_code/.*\.(o|obj|elf|bin|lst|map)$)' }
)

function Get-MatchesForPaths {
    param(
        [string[]]$Paths,
        [string]$State
    )

    $items = @()
    foreach ($path in $Paths) {
        $normalized = $path.Replace("\", "/")
        foreach ($rule in $rules) {
            if ($normalized -match $rule.Regex) {
                $items += [PSCustomObject]@{
                    State = $State
                    Reason = $rule.Name
                    Path = $normalized
                }
                break
            }
        }
    }

    return $items
}

Push-Location $repoRoot
try {
    $tracked = & git ls-files
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $recommendations = @()
    $recommendations += @(Get-MatchesForPaths -Paths $tracked -State "tracked")

    if ($IncludeIgnored) {
        $ignored = & git ls-files --others --ignored --exclude-standard
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        $recommendations += @(Get-MatchesForPaths -Paths $ignored -State "ignored")
    }

    if ($recommendations.Count -eq 0) {
        Write-Host "No generated-artifact candidates found."
        exit 0
    }

    if ($UntrackTracked) {
        $trackedPaths = @($recommendations | Where-Object { $_.State -eq "tracked" } | ForEach-Object { $_.Path })
        if ($trackedPaths.Count -eq 0) {
            Write-Host "No tracked generated-artifact candidates to untrack."
            exit 0
        }

        Write-Host "Untracking $($trackedPaths.Count) generated-artifact candidate(s) with git rm --cached."
        & git rm --cached -- @trackedPaths
        exit $LASTEXITCODE
    }

    if ($AsCommands) {
        foreach ($item in $recommendations | Where-Object { $_.State -eq "tracked" }) {
            $escaped = $item.Path.Replace("'", "''")
            Write-Output "git rm --cached -- '$escaped'"
        }
        exit 0
    }

    $recommendations |
        Sort-Object State, Reason, Path |
        Format-Table -AutoSize State, Reason, Path

    $trackedCount = ($recommendations | Where-Object { $_.State -eq "tracked" }).Count
    if ($trackedCount -gt 0) {
        Write-Host ""
        Write-Host "Recommendation: review tracked generated artifacts above and remove them from the index with git rm --cached after confirming they are not source files."
        Write-Host "This script does not delete files."
    }
}
finally {
    Pop-Location
}
