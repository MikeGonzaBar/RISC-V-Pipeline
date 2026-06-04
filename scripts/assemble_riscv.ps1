[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [string]$OutFile = "",

    [string]$ToolchainPrefix = "",

    [switch]$UseLocalAssembler,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

function New-RegisterMap {
    $map = @{
        zero = 0
        ra = 1
        sp = 2
        gp = 3
        tp = 4
        t0 = 5
        t1 = 6
        t2 = 7
        s0 = 8
        fp = 8
        s1 = 9
        a0 = 10
        a1 = 11
        a2 = 12
        a3 = 13
        a4 = 14
        a5 = 15
        a6 = 16
        a7 = 17
        s2 = 18
        s3 = 19
        s4 = 20
        s5 = 21
        s6 = 22
        s7 = 23
        s8 = 24
        s9 = 25
        s10 = 26
        s11 = 27
        t3 = 28
        t4 = 29
        t5 = 30
        t6 = 31
    }

    for ($index = 0; $index -lt 32; $index++) {
        $map["x$index"] = $index
    }

    return $map
}

function Resolve-InputPath {
    param([string]$PathValue)

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return (Resolve-Path $PathValue).Path
    }

    return (Resolve-Path (Join-Path (Get-Location) $PathValue)).Path
}

function Resolve-OutputPath {
    param(
        [string]$PathValue,
        [string]$DefaultPath
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return [System.IO.Path]::GetFullPath($DefaultPath)
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PathValue))
}

function Find-Toolchain {
    param([string]$Prefix)

    $prefixes = @()
    if (-not [string]::IsNullOrWhiteSpace($Prefix)) {
        $prefixes += $Prefix.TrimEnd("-")
    }
    else {
        $prefixes += @(
            "riscv64-unknown-elf",
            "riscv32-unknown-elf",
            "riscv64-elf",
            "riscv32-elf"
        )
    }

    foreach ($candidate in $prefixes) {
        $as = Get-Command "$candidate-as" -ErrorAction SilentlyContinue
        $objcopy = Get-Command "$candidate-objcopy" -ErrorAction SilentlyContinue
        if ($as -and $objcopy) {
            return [PSCustomObject]@{
                Prefix = $candidate
                As = $as.Source
                Objcopy = $objcopy.Source
            }
        }
    }

    return $null
}

function Convert-BinaryToMemHex {
    param(
        [string]$BinFile,
        [string]$Destination
    )

    $bytes = [System.IO.File]::ReadAllBytes($BinFile)
    if (($bytes.Length % 4) -ne 0) {
        throw "Binary text section length $($bytes.Length) is not a whole number of 32-bit words."
    }

    $lines = @()
    for ($index = 0; $index -lt $bytes.Length; $index += 4) {
        $word = [uint32]$bytes[$index]
        $word = $word -bor ([uint32]$bytes[$index + 1] -shl 8)
        $word = $word -bor ([uint32]$bytes[$index + 2] -shl 16)
        $word = $word -bor ([uint32]$bytes[$index + 3] -shl 24)
        $lines += ("{0:x8}" -f $word)
    }

    Set-Content -Path $Destination -Value $lines -Encoding ascii
    return $lines.Count
}

function Strip-Comment {
    param([string]$Line)

    $result = $Line
    foreach ($marker in @("#", "//", ";")) {
        $index = $result.IndexOf($marker)
        if ($index -ge 0) {
            $result = $result.Substring(0, $index)
        }
    }

    return $result.Trim()
}

function Split-Operands {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    return @($Text -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

function Get-TokenizedInstruction {
    param([string]$Text)

    $parts = $Text.Trim() -split "\s+", 2
    if ($parts.Count -eq 0 -or [string]::IsNullOrWhiteSpace($parts[0])) {
        throw "empty instruction"
    }

    $operandText = ""
    if ($parts.Count -gt 1) {
        $operandText = $parts[1]
    }

    return [PSCustomObject]@{
        Mnemonic = $parts[0].ToLowerInvariant()
        Operands = @(Split-Operands $operandText)
    }
}

function Parse-Int {
    param([string]$Value)

    $clean = $Value.Trim().Replace("_", "")
    if ($clean.Length -eq 0) {
        throw "empty integer"
    }

    $sign = [int64]1
    if ($clean.StartsWith("-")) {
        $sign = -1
        $clean = $clean.Substring(1)
    }
    elseif ($clean.StartsWith("+")) {
        $clean = $clean.Substring(1)
    }

    if ($clean.StartsWith("0x", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $sign * [Convert]::ToInt64($clean.Substring(2), 16)
    }

    if ($clean.StartsWith("0b", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $sign * [Convert]::ToInt64($clean.Substring(2), 2)
    }

    return $sign * [int64]::Parse($clean, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Parse-Reg {
    param([string]$Value)

    $key = $Value.Trim().ToLowerInvariant()
    if (-not $script:RegisterMap.ContainsKey($key)) {
        throw "unknown register '$Value'"
    }

    return [int]$script:RegisterMap[$key]
}

function Parse-MemOperand {
    param([string]$Value)

    if ($Value -notmatch '^\s*([+-]?(?:0x[0-9a-fA-F]+|0b[01]+|\d+))\s*\(\s*([A-Za-z0-9_.$]+)\s*\)\s*$') {
        throw "expected memory operand imm(rs1), got '$Value'"
    }

    return [PSCustomObject]@{
        Imm = Parse-Int $Matches[1]
        Rs1 = Parse-Reg $Matches[2]
    }
}

function Require-Operands {
    param(
        [string]$Mnemonic,
        [object[]]$Operands,
        [int]$Expected
    )

    if ($Operands.Count -ne $Expected) {
        throw "$Mnemonic expects $Expected operand(s), got $($Operands.Count)"
    }
}

function Check-Range {
    param(
        [string]$Name,
        [int64]$Value,
        [int64]$Lower,
        [int64]$Upper
    )

    if ($Value -lt $Lower -or $Value -gt $Upper) {
        throw "$Name immediate $Value is outside [$Lower, $Upper]"
    }
}

function Check-Aligned {
    param(
        [string]$Name,
        [int64]$Value,
        [int64]$Alignment
    )

    if (($Value % $Alignment) -ne 0) {
        throw "$Name immediate $Value must be $Alignment-byte aligned"
    }
}

function Resolve-Immediate {
    param(
        [string]$Token,
        [hashtable]$Labels,
        [int64]$Pc
    )

    if ($Labels.ContainsKey($Token)) {
        return [int64]$Labels[$Token] - $Pc
    }

    return Parse-Int $Token
}

function Encode-R {
    param([int64]$Funct7, [int64]$Rs2, [int64]$Rs1, [int64]$Funct3, [int64]$Rd, [int64]$Opcode)

    $word = ((($Funct7 -band 0x7f) -shl 25) -bor (($Rs2 -band 0x1f) -shl 20))
    $word = $word -bor (($Rs1 -band 0x1f) -shl 15)
    $word = $word -bor (($Funct3 -band 0x07) -shl 12)
    $word = $word -bor (($Rd -band 0x1f) -shl 7)
    $word = $word -bor ($Opcode -band 0x7f)
    return [uint32]$word
}

function Encode-I {
    param([int64]$Imm, [int64]$Rs1, [int64]$Funct3, [int64]$Rd, [int64]$Opcode)

    Check-Range "I-type" $Imm -2048 2047
    $encoded = $Imm -band 0xfff
    $word = (($encoded -shl 20) -bor (($Rs1 -band 0x1f) -shl 15))
    $word = $word -bor (($Funct3 -band 0x07) -shl 12)
    $word = $word -bor (($Rd -band 0x1f) -shl 7)
    $word = $word -bor ($Opcode -band 0x7f)
    return [uint32]$word
}

function Encode-S {
    param([int64]$Imm, [int64]$Rs2, [int64]$Rs1, [int64]$Funct3, [int64]$Opcode)

    Check-Range "S-type" $Imm -2048 2047
    $encoded = $Imm -band 0xfff
    $word = (((($encoded -shr 5) -band 0x7f) -shl 25) -bor (($Rs2 -band 0x1f) -shl 20))
    $word = $word -bor (($Rs1 -band 0x1f) -shl 15)
    $word = $word -bor (($Funct3 -band 0x07) -shl 12)
    $word = $word -bor (($encoded -band 0x1f) -shl 7)
    $word = $word -bor ($Opcode -band 0x7f)
    return [uint32]$word
}

function Encode-B {
    param([int64]$Imm, [int64]$Rs2, [int64]$Rs1, [int64]$Funct3, [int64]$Opcode)

    Check-Range "B-type" $Imm -4096 4094
    Check-Aligned "B-type" $Imm 2
    $encoded = $Imm -band 0x1fff
    $word = (((($encoded -shr 12) -band 0x01) -shl 31) -bor (((($encoded -shr 5) -band 0x3f) -shl 25)))
    $word = $word -bor (($Rs2 -band 0x1f) -shl 20)
    $word = $word -bor (($Rs1 -band 0x1f) -shl 15)
    $word = $word -bor (($Funct3 -band 0x07) -shl 12)
    $word = $word -bor (((($encoded -shr 1) -band 0x0f) -shl 8))
    $word = $word -bor (((($encoded -shr 11) -band 0x01) -shl 7))
    $word = $word -bor ($Opcode -band 0x7f)
    return [uint32]$word
}

function Encode-U {
    param([int64]$Imm, [int64]$Rd, [int64]$Opcode)

    Check-Range "U-type" $Imm 0 0xfffff
    $word = (($Imm -band 0xfffff) -shl 12)
    $word = $word -bor (($Rd -band 0x1f) -shl 7)
    $word = $word -bor ($Opcode -band 0x7f)
    return [uint32]$word
}

function Encode-J {
    param([int64]$Imm, [int64]$Rd, [int64]$Opcode)

    Check-Range "J-type" $Imm -1048576 1048574
    Check-Aligned "J-type" $Imm 2
    $encoded = $Imm -band 0x1fffff
    $word = (((($encoded -shr 20) -band 0x01) -shl 31) -bor (((($encoded -shr 1) -band 0x03ff) -shl 21)))
    $word = $word -bor (((($encoded -shr 11) -band 0x01) -shl 20))
    $word = $word -bor (((($encoded -shr 12) -band 0xff) -shl 12))
    $word = $word -bor (($Rd -band 0x1f) -shl 7)
    $word = $word -bor ($Opcode -band 0x7f)
    return [uint32]$word
}

function Get-EncodedWordCount {
    param([string]$Text)

    $instruction = Get-TokenizedInstruction $Text
    $mnemonic = $instruction.Mnemonic
    $operands = @($instruction.Operands)

    if ($mnemonic -eq ".word") {
        if ($operands.Count -eq 0) {
            throw ".word expects at least one operand"
        }
        return $operands.Count
    }

    if ($mnemonic.StartsWith(".")) {
        $ignored = @(".text", ".data", ".section", ".globl", ".global", ".align", ".p2align", ".option", ".attribute")
        if ($ignored -contains $mnemonic) {
            return 0
        }
        throw "unsupported directive '$mnemonic'"
    }

    return 1
}

function Invoke-FirstPass {
    param([string[]]$Lines)

    $labels = @{}
    $records = @()
    $pc = [int64]0

    for ($lineIndex = 0; $lineIndex -lt $Lines.Count; $lineIndex++) {
        $lineNo = $lineIndex + 1
        $text = Strip-Comment $Lines[$lineIndex]
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        while ($text -match '^([A-Za-z_.$][A-Za-z0-9_.$]*):') {
            $label = $Matches[1]
            if ($labels.ContainsKey($label)) {
                throw "line $($lineNo): duplicate label '$label'"
            }
            $labels[$label] = [int]$pc
            $text = $text.Substring($Matches[0].Length).Trim()
        }

        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        try {
            $count = Get-EncodedWordCount $text
        }
        catch {
            throw "line $($lineNo): $($_.Exception.Message)"
        }

        if ($count -gt 0) {
            $records += [PSCustomObject]@{
                LineNo = $lineNo
                Pc = $pc
                Text = $text
            }
            $pc += 4 * $count
        }
    }

    return [PSCustomObject]@{
        Records = @($records)
        Labels = $labels
    }
}

function Invoke-AssembleRecord {
    param(
        [object]$Record,
        [hashtable]$Labels
    )

    $instruction = Get-TokenizedInstruction $Record.Text
    $mnemonic = $instruction.Mnemonic
    $operands = @($instruction.Operands)

    switch ($mnemonic) {
        ".word" {
            $words = @()
            foreach ($operand in $operands) {
                $words += [uint32](Parse-Int $operand)
            }
            return $words
        }
        "nop" {
            Require-Operands $mnemonic $operands 0
            return Encode-I 0 0 0 0 0x13
        }
        "add" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 0 (Parse-Reg $operands[0]) 0x33
        }
        "sub" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0x20 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 0 (Parse-Reg $operands[0]) 0x33
        }
        "sll" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 1 (Parse-Reg $operands[0]) 0x33
        }
        "slt" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 2 (Parse-Reg $operands[0]) 0x33
        }
        "sltu" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 3 (Parse-Reg $operands[0]) 0x33
        }
        "xor" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 4 (Parse-Reg $operands[0]) 0x33
        }
        "srl" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 5 (Parse-Reg $operands[0]) 0x33
        }
        "sra" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0x20 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 5 (Parse-Reg $operands[0]) 0x33
        }
        "or" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 6 (Parse-Reg $operands[0]) 0x33
        }
        "and" {
            Require-Operands $mnemonic $operands 3
            return Encode-R 0 (Parse-Reg $operands[2]) (Parse-Reg $operands[1]) 7 (Parse-Reg $operands[0]) 0x33
        }
        "addi" {
            Require-Operands $mnemonic $operands 3
            return Encode-I (Parse-Int $operands[2]) (Parse-Reg $operands[1]) 0 (Parse-Reg $operands[0]) 0x13
        }
        "slti" {
            Require-Operands $mnemonic $operands 3
            return Encode-I (Parse-Int $operands[2]) (Parse-Reg $operands[1]) 2 (Parse-Reg $operands[0]) 0x13
        }
        "sltiu" {
            Require-Operands $mnemonic $operands 3
            return Encode-I (Parse-Int $operands[2]) (Parse-Reg $operands[1]) 3 (Parse-Reg $operands[0]) 0x13
        }
        "xori" {
            Require-Operands $mnemonic $operands 3
            return Encode-I (Parse-Int $operands[2]) (Parse-Reg $operands[1]) 4 (Parse-Reg $operands[0]) 0x13
        }
        "ori" {
            Require-Operands $mnemonic $operands 3
            return Encode-I (Parse-Int $operands[2]) (Parse-Reg $operands[1]) 6 (Parse-Reg $operands[0]) 0x13
        }
        "andi" {
            Require-Operands $mnemonic $operands 3
            return Encode-I (Parse-Int $operands[2]) (Parse-Reg $operands[1]) 7 (Parse-Reg $operands[0]) 0x13
        }
        "slli" {
            Require-Operands $mnemonic $operands 3
            $shamt = Parse-Int $operands[2]
            Check-Range "shift" $shamt 0 31
            $word = (($shamt -band 0x1f) -shl 20)
            $word = $word -bor ((Parse-Reg $operands[1]) -shl 15)
            $word = $word -bor (1 -shl 12)
            $word = $word -bor ((Parse-Reg $operands[0]) -shl 7)
            $word = $word -bor 0x13
            return [uint32]$word
        }
        "srli" {
            Require-Operands $mnemonic $operands 3
            $shamt = Parse-Int $operands[2]
            Check-Range "shift" $shamt 0 31
            $word = (($shamt -band 0x1f) -shl 20)
            $word = $word -bor ((Parse-Reg $operands[1]) -shl 15)
            $word = $word -bor (5 -shl 12)
            $word = $word -bor ((Parse-Reg $operands[0]) -shl 7)
            $word = $word -bor 0x13
            return [uint32]$word
        }
        "srai" {
            Require-Operands $mnemonic $operands 3
            $shamt = Parse-Int $operands[2]
            Check-Range "shift" $shamt 0 31
            $word = (0x20 -shl 25)
            $word = $word -bor (($shamt -band 0x1f) -shl 20)
            $word = $word -bor ((Parse-Reg $operands[1]) -shl 15)
            $word = $word -bor (5 -shl 12)
            $word = $word -bor ((Parse-Reg $operands[0]) -shl 7)
            $word = $word -bor 0x13
            return [uint32]$word
        }
        "lui" {
            Require-Operands $mnemonic $operands 2
            return Encode-U (Parse-Int $operands[1]) (Parse-Reg $operands[0]) 0x37
        }
        "auipc" {
            Require-Operands $mnemonic $operands 2
            return Encode-U (Parse-Int $operands[1]) (Parse-Reg $operands[0]) 0x17
        }
        "lb" {
            Require-Operands $mnemonic $operands 2
            $mem = Parse-MemOperand $operands[1]
            return Encode-I $mem.Imm $mem.Rs1 0 (Parse-Reg $operands[0]) 0x03
        }
        "lh" {
            Require-Operands $mnemonic $operands 2
            $mem = Parse-MemOperand $operands[1]
            return Encode-I $mem.Imm $mem.Rs1 1 (Parse-Reg $operands[0]) 0x03
        }
        "lw" {
            Require-Operands $mnemonic $operands 2
            $mem = Parse-MemOperand $operands[1]
            return Encode-I $mem.Imm $mem.Rs1 2 (Parse-Reg $operands[0]) 0x03
        }
        "lbu" {
            Require-Operands $mnemonic $operands 2
            $mem = Parse-MemOperand $operands[1]
            return Encode-I $mem.Imm $mem.Rs1 4 (Parse-Reg $operands[0]) 0x03
        }
        "lhu" {
            Require-Operands $mnemonic $operands 2
            $mem = Parse-MemOperand $operands[1]
            return Encode-I $mem.Imm $mem.Rs1 5 (Parse-Reg $operands[0]) 0x03
        }
        "sb" {
            Require-Operands $mnemonic $operands 2
            $mem = Parse-MemOperand $operands[1]
            return Encode-S $mem.Imm (Parse-Reg $operands[0]) $mem.Rs1 0 0x23
        }
        "sh" {
            Require-Operands $mnemonic $operands 2
            $mem = Parse-MemOperand $operands[1]
            return Encode-S $mem.Imm (Parse-Reg $operands[0]) $mem.Rs1 1 0x23
        }
        "sw" {
            Require-Operands $mnemonic $operands 2
            $mem = Parse-MemOperand $operands[1]
            return Encode-S $mem.Imm (Parse-Reg $operands[0]) $mem.Rs1 2 0x23
        }
        "beq" {
            Require-Operands $mnemonic $operands 3
            $imm = Resolve-Immediate $operands[2] $Labels $Record.Pc
            return Encode-B $imm (Parse-Reg $operands[1]) (Parse-Reg $operands[0]) 0 0x63
        }
        "bne" {
            Require-Operands $mnemonic $operands 3
            $imm = Resolve-Immediate $operands[2] $Labels $Record.Pc
            return Encode-B $imm (Parse-Reg $operands[1]) (Parse-Reg $operands[0]) 1 0x63
        }
        "blt" {
            Require-Operands $mnemonic $operands 3
            $imm = Resolve-Immediate $operands[2] $Labels $Record.Pc
            return Encode-B $imm (Parse-Reg $operands[1]) (Parse-Reg $operands[0]) 4 0x63
        }
        "bge" {
            Require-Operands $mnemonic $operands 3
            $imm = Resolve-Immediate $operands[2] $Labels $Record.Pc
            return Encode-B $imm (Parse-Reg $operands[1]) (Parse-Reg $operands[0]) 5 0x63
        }
        "bltu" {
            Require-Operands $mnemonic $operands 3
            $imm = Resolve-Immediate $operands[2] $Labels $Record.Pc
            return Encode-B $imm (Parse-Reg $operands[1]) (Parse-Reg $operands[0]) 6 0x63
        }
        "bgeu" {
            Require-Operands $mnemonic $operands 3
            $imm = Resolve-Immediate $operands[2] $Labels $Record.Pc
            return Encode-B $imm (Parse-Reg $operands[1]) (Parse-Reg $operands[0]) 7 0x63
        }
        "jal" {
            Require-Operands $mnemonic $operands 2
            $imm = Resolve-Immediate $operands[1] $Labels $Record.Pc
            return Encode-J $imm (Parse-Reg $operands[0]) 0x6f
        }
        "jalr" {
            if ($operands.Count -eq 2) {
                $mem = Parse-MemOperand $operands[1]
                return Encode-I $mem.Imm $mem.Rs1 0 (Parse-Reg $operands[0]) 0x67
            }

            Require-Operands $mnemonic $operands 3
            return Encode-I (Parse-Int $operands[2]) (Parse-Reg $operands[1]) 0 (Parse-Reg $operands[0]) 0x67
        }
        default {
            throw "unsupported instruction '$mnemonic'"
        }
    }
}

function Invoke-LocalAssembler {
    param(
        [string]$SourcePath,
        [string]$Destination
    )

    $sourceLines = Get-Content $SourcePath
    $pass = Invoke-FirstPass $sourceLines
    $words = @()

    foreach ($record in $pass.Records) {
        try {
            foreach ($word in @(Invoke-AssembleRecord $record $pass.Labels)) {
                $words += ("{0:x8}" -f ([uint32]$word))
            }
        }
        catch {
            throw "line $($record.LineNo): $($_.Exception.Message)"
        }
    }

    Set-Content -Path $Destination -Value $words -Encoding ascii
    Write-Host "Wrote $($words.Count) word(s) to $Destination"
}

$script:RegisterMap = New-RegisterMap
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$inputPath = Resolve-InputPath $InputFile
$defaultOut = Join-Path $repoRoot (Join-Path ".codex-sim\asm" (([System.IO.Path]::GetFileNameWithoutExtension($inputPath)) + ".dat"))
$outPath = Resolve-OutputPath $OutFile $defaultOut
$outDir = Split-Path -Parent $outPath

if ((Test-Path $outPath) -and -not $Force) {
    throw "Refusing to overwrite existing output '$outPath'. Re-run with -Force or choose a new -OutFile."
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$toolchain = $null
if (-not $UseLocalAssembler) {
    $toolchain = Find-Toolchain $ToolchainPrefix
}

if ($toolchain) {
    $scratchDir = Join-Path $repoRoot ".codex-sim\asm\toolchain"
    New-Item -ItemType Directory -Force -Path $scratchDir | Out-Null
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
    $objectFile = Join-Path $scratchDir "$baseName.o"
    $binaryFile = Join-Path $scratchDir "$baseName.bin"

    Write-Host "Assembling with $($toolchain.Prefix)-as..."
    & $toolchain.As "-march=rv32i" "-mabi=ilp32" "-o" $objectFile $inputPath
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    & $toolchain.Objcopy "-O" "binary" "-j" ".text" $objectFile $binaryFile
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $wordCount = Convert-BinaryToMemHex $binaryFile $outPath
    Write-Host "Wrote $wordCount word(s) to $outPath"
    exit 0
}

Write-Host "Assembling with local RV32I-subset assembler..."
Invoke-LocalAssembler $inputPath $outPath
