# RISC-V-Pipeline

A 5-stage pipelined RISC-V processor implementation in Verilog. This project was developed for a computer organization course at ITESO by Dr. José Luis Pizano Escalante.

## Implemented Instruction Set Architecture (ISA)

This RISC-V core implements a subset of the RV32I base integer instruction set. The following instructions are supported:

- **R-Type:**
  - `add`
  - `sub`
- **I-Type:**
  - `addi`
  - `ori`
  - `slli`
  - `srli`
- **U-Type:**
  - `lui`

**Note:** Load, store, and branch instructions are not implemented in the current version.

## Pipeline Stages

The processor implements a classic 5-stage RISC pipeline:

1.  **IF (Instruction Fetch):** Fetches the next instruction from memory.
2.  **ID (Instruction Decode):** Decodes the instruction and reads operands from the register file.
3.  **EX (Execute):** Executes the instruction, typically involving the ALU.
4.  **MEM (Memory Access):** Accesses data memory for loads and stores (currently not implemented).
5.  **WB (Write Back):** Writes the result back to the register file.

## Directory Structure

- `src/`: Contains all the Verilog source code for the processor components.
- `assembly_code/`: Contains sample assembly programs.
- `proj_modelsim/`: Contains project files and scripts for simulation with ModelSim.
- `proj_quartus/`: Contains project files for synthesis with Intel Quartus.

## Usage

### Simulation (ModelSim)

To run a simulation of the processor, you can use the scripts provided in the `proj_modelsim` directory. These are typically `.do` files that can be executed in the ModelSim console.

### Synthesis (Intel Quartus)

The project can be synthesized for an FPGA using the Quartus project file located in the `proj_quartus` directory.

---
*Original author: Dr. José Luis Pizano Escalante (luispizano@iteso.mx)*