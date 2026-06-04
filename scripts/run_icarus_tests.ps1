[CmdletBinding()]
param(
	[string[]]$Test = @(
		"smoke",
		"raw_forwarding",
		"load_use_stall",
		"lw_sw_store_forwarding",
		"beq_bne",
		"jal_jalr",
		"immediate_edges",
		"memory_offsets",
		"branch_forwarding",
		"expanded_alu_isa",
		"branch_variants",
		"byte_halfword_memory"
	),
	[int[]]$RandomSeed = @(1, 17, 99),
	[int]$RandomCount = 48,
	[string]$OutDir = "",
	[string]$Iverilog = "iverilog",
	[string]$Vvp = "vvp",
	[switch]$FailFast,
	[switch]$SkipRandom,
	[switch]$Wave,
	[string]$WaveDir = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$SrcDir = Join-Path $RepoRoot "src"
$TbFile = Join-Path $RepoRoot "tests\pipeline_selfcheck_tb.v"
$DefaultProgramTbFile = Join-Path $RepoRoot "tests\default_program_file_tb.v"
$RandomReferenceTbFile = Join-Path $RepoRoot "tests\random_reference_tb.v"

if ([string]::IsNullOrWhiteSpace($OutDir)) {
	$OutDir = Join-Path $RepoRoot ".codex-sim\icarus"
}

$OutDir = [System.IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ([string]::IsNullOrWhiteSpace($WaveDir)) {
	$WaveDir = Join-Path $OutDir "waves"
}
$WaveDir = [System.IO.Path]::GetFullPath($WaveDir)
if ($Wave) {
	New-Item -ItemType Directory -Force -Path $WaveDir | Out-Null
}

$SimFile = Join-Path $OutDir "pipeline_selfcheck.vvp"
$DefaultProgramSimFile = Join-Path $OutDir "default_program_file.vvp"
$RandomReferenceSimFile = Join-Path $OutDir "random_reference.vvp"
$RtlFiles = Get-ChildItem -Path $SrcDir -Filter "*.v" |
	Where-Object { $_.Name -ne "RISC_V_Single_Cycle_TB.v" } |
	Sort-Object Name |
	ForEach-Object { $_.FullName }

function New-WavePlusArg {
	param(
		[string]$Name
	)

	$Path = Join-Path $WaveDir "$Name.vcd"
	return "+WAVE=$($Path.Replace('\', '/'))"
}

Push-Location $RepoRoot
try {
	Write-Host "Compiling default program-file smoke test..."
	$DefaultProgramCompileArgs = @("-g2012", "-Wall", "-s", "default_program_file_tb", "-o", $DefaultProgramSimFile) + $RtlFiles + @($DefaultProgramTbFile)
	& $Iverilog @DefaultProgramCompileArgs
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	Write-Host ""
	Write-Host "Running default_program_file..."
	$DefaultProgramRunArgs = @($DefaultProgramSimFile)
	if ($Wave) {
		$DefaultProgramRunArgs += (New-WavePlusArg "default_program_file")
	}
	& $Vvp @DefaultProgramRunArgs
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	Write-Host ""
	Write-Host "Compiling pipeline self-check testbench..."
	$CompileArgs = @("-g2012", "-Wall", "-s", "pipeline_selfcheck_tb", "-o", $SimFile) + $RtlFiles + @($TbFile)
	& $Iverilog @CompileArgs
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	$Failures = @()
	foreach ($Name in $Test) {
		Write-Host ""
		Write-Host "Running $Name..."
		$RunArgs = @($SimFile, "+TEST=$Name")
		if ($Wave) {
			$RunArgs += (New-WavePlusArg "pipeline_$Name")
		}
		& $Vvp @RunArgs
		if ($LASTEXITCODE -ne 0) {
			$Failures += $Name
			if ($FailFast) {
				break
			}
		}
	}

	if (-not $SkipRandom -and (-not $FailFast -or $Failures.Count -eq 0)) {
		Write-Host ""
		Write-Host "Compiling random/reference testbench..."
		$RandomCompileArgs = @("-g2012", "-Wall", "-s", "random_reference_tb", "-o", $RandomReferenceSimFile) + $RtlFiles + @($RandomReferenceTbFile)
		& $Iverilog @RandomCompileArgs
		if ($LASTEXITCODE -ne 0) {
			exit $LASTEXITCODE
		}

		foreach ($Seed in $RandomSeed) {
			Write-Host ""
			Write-Host "Running random_reference seed=$Seed count=$RandomCount..."
			$RandomRunArgs = @($RandomReferenceSimFile, "+SEED=$Seed", "+COUNT=$RandomCount")
			if ($Wave) {
				$RandomRunArgs += (New-WavePlusArg "random_reference_seed_$Seed")
			}
			& $Vvp @RandomRunArgs
			if ($LASTEXITCODE -ne 0) {
				$Failures += "random_reference(seed=$Seed)"
				if ($FailFast) {
					break
				}
			}
		}
	}

	Write-Host ""
	if ($Failures.Count -gt 0) {
		Write-Host ("Failing tests: " + ($Failures -join ", "))
		exit 1
	}

	Write-Host "All requested Icarus tests passed."
	exit 0
}
finally {
	Pop-Location
}
