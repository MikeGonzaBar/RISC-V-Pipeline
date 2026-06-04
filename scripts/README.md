# Local automation scripts

Run these from the repository root with PowerShell.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_icarus_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_verilator_lint.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_quartus_validation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\assemble_riscv.ps1 -InputFile .\assembly_code\requiredCode.asm
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\report_generated_artifacts.ps1
```

Use `run_icarus_tests.ps1 -Wave` to emit VCD files under `.codex-sim/icarus/waves`.

`run_verilator_lint.ps1` and `run_quartus_validation.ps1` skip their tool-backed checks when the corresponding tools are not installed. Add `-RequireVerilator` or `-RequireQuartus` when a missing tool should fail the run.

`assemble_riscv.ps1` prefers a GNU RISC-V toolchain when `riscv64-unknown-elf-*` or `riscv32-unknown-elf-*` is on `PATH`, then falls back to a local PowerShell assembler for the implemented course-core RV32I subset. By default it writes under `.codex-sim/asm/` and refuses to overwrite an existing output unless `-Force` is passed.

`report_generated_artifacts.ps1` reports cleanup candidates. Use `-AsCommands` to print suggested `git rm --cached` commands, or `-UntrackTracked` to remove tracked generated files from the git index while leaving local files on disk.
