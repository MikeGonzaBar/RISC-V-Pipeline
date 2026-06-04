# RISC-V-Pipeline

A 5-stage pipelined RISC-V processor implementation in Verilog. This project was developed for a computer organization course at ITESO by Dr. José Luis Pizano Escalante.

## Implemented Instruction Set Architecture (ISA)

This RISC-V core implements a subset of the RV32I base integer instruction set. The following instructions are supported:

- **R-Type:**
  - `add`
  - `sub`
  - `and`
  - `or`
  - `xor`
  - `slt`
  - `sltu`
  - `sll`
  - `srl`
  - `sra`
- **I-Type:**
  - `addi`
  - `andi`
  - `ori`
  - `xori`
  - `slti`
  - `sltiu`
  - `slli`
  - `srli`
  - `srai`
  - `lb`
  - `lh`
  - `lw`
  - `lbu`
  - `lhu`
  - `jalr`
- **S-Type:**
  - `sb`
  - `sh`
  - `sw`
- **B-Type:**
  - `beq`
  - `bne`
  - `blt`
  - `bge`
  - `bltu`
  - `bgeu`
- **J-Type:**
  - `jal`
- **U-Type:**
  - `auipc`
  - `lui`

**Note:** This is still a course-core implementation, not a privileged or exception-capable core. CSRs, exceptions, interrupts, `ecall`/`ebreak`, and `fence`/`fence.i` trap/ordering semantics are out of scope.

## Pipeline Stages

The processor implements a classic 5-stage RISC pipeline:

1.  **IF (Instruction Fetch):** Fetches the next instruction from memory.
2.  **ID (Instruction Decode):** Decodes the instruction and reads operands from the register file.
3.  **EX (Execute):** Executes the instruction, typically involving the ALU.
4.  **MEM (Memory Access):** Accesses little-endian data memory for byte, halfword, and word loads/stores.
5.  **WB (Write Back):** Writes the result back to the register file.

The pipeline includes EX/MEM and MEM/WB forwarding, store-data forwarding, load-use stalls, and flushes for taken branches and jumps.

## Directory Structure

- `src/`: Contains the Verilog source code for the processor components and the simulation testbench.
- `assembly_code/`: Contains sample assembly programs.
- `tests/`: Contains self-checking Icarus Verilog regression tests.
- `scripts/`: Contains local test runner scripts.
- `proj_modelsim/`: Contains project files and `.do` scripts for simulation with ModelSim.
- `proj_quartus/`: Contains the Intel Quartus project files. Generated databases, reports, and programming files are build artifacts.

## Usage

### Simulation (ModelSim)

To run a simulation of the processor, you can use the scripts provided in the `proj_modelsim` directory. These are typically `.do` files that can be executed in the ModelSim console.

### Simulation (Icarus Verilog)

Run the lightweight regression suite from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_icarus_tests.ps1
```

Run a subset:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_icarus_tests.ps1 -Test smoke,raw_forwarding
```

Local Icarus builds write outputs under `.codex-sim/` by default. Generated files such as `.vvp` executables and `.vcd`/`.fst` waveforms are ignored.

The top-level instruction memory loads `src/text.dat` by default through the `PROGRAM_FILE` parameter. `PROGRAM_INIT_WORDS` defaults to `0`, which means load the full file instead of truncating to a fixed word count. The Icarus runner changes to the repository root before simulation so that default path is stable.

The local test runner also supports VCD output:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_icarus_tests.ps1 -Wave
```

The GitHub Actions workflow in `.github/workflows/icarus.yml` installs Icarus Verilog on Ubuntu and runs the same regression suite.

### Assembly to Memory Hex

Generate a `$readmemh`-compatible program file from assembly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\assemble_riscv.ps1 -InputFile .\assembly_code\requiredCode.asm -OutFile .\src\text.dat -Force
```

The script prefers a GNU RISC-V toolchain when available, then falls back to a local assembler for the implemented course-core RV32I subset.

### Optional Tool Checks

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_verilator_lint.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_quartus_validation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\report_generated_artifacts.ps1
```

The Verilator and Quartus scripts skip tool-backed checks when those tools are not installed unless you pass `-RequireVerilator` or `-RequireQuartus`.
Use `report_generated_artifacts.ps1 -UntrackTracked` to remove generated Quartus/ModelSim files from git's index without deleting local files.

### Synthesis (Intel Quartus)

The project can be synthesized for an FPGA using the Quartus project file located in the `proj_quartus` directory. The QSF source list is intended to contain synthesizable HDL only; testbenches such as `src/RISC_V_Single_Cycle_TB.v` and `tests/*.v` belong in simulation flows, not the Quartus synthesis source set.

The top-level debug outputs are exposed for inspection and marked as Quartus virtual pins in `proj_quartus/RISC_V_Single_Cycle.qsf`, so they remain observable without consuming board I/O pins.

### Hardware Observability (Quartus/SignalTap)

The synthesis top level keeps a lightweight debug surface for board bring-up and SignalTap captures:

- `debug_pc_o` and `debug_instruction_o` show the current fetch PC and instruction.
- `debug_wb_reg_write_o`, `debug_wb_rd_o`, and `debug_wb_data_o` show write-back commits.
- `debug_t0_o` through `debug_t2_o` and `debug_s0_o` through `debug_s3_o` expose selected architectural registers.

Refresh the virtual-pin assignments from the repository root with:

```powershell
quartus_sh -t .\proj_quartus\debug_observability.tcl
```

Then run Quartus Analysis & Synthesis or a full compile. In SignalTap, use the design clock `clk` as the sample clock, add the `debug_*` top-level ports as probes through Node Finder, and trigger on useful events such as `debug_wb_reg_write_o == 1` with a matching `debug_wb_rd_o` value. Keep board-specific package-pin assignments for `clk`, `reset`, LEDs, switches, or headers in a separate board QSF or board-specific revision; this project metadata deliberately avoids those assumptions.

## Build Artifact Policy

Generated simulator and FPGA-tool outputs should not be committed. The root `.gitignore` covers local Icarus output, ModelSim `work/` libraries and waveform files, and Quartus `db/`, `incremental_db/`, and `output_files/` directories. Existing tracked generated files may still appear in history, but new cleanup work should keep source files, scripts, and project metadata separate from regenerated reports and databases.

---
*Original author: Dr. José Luis Pizano Escalante (luispizano@iteso.mx)*
