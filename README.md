Done! Here's the final RV32I softcore RISC-V processor built with Verilator:

## Project Structure

```
/Users/peter/Desktop/riscv/
├── Makefile                  # Build system (make sim / make clean / make lint)
├── rtl/
│   ├── rv32_alu.sv          # 32-bit ALU (ADD, SUB, AND, OR, XOR, SLL, SLT, SLTU, SRA, SRL)
│   ├── rv32_ctrl.sv         # Instruction decoder (opcode/funct3/funct7 → control signals)
│   ├── rv32_regfile.sv      # 32×32-bit register file (2 read, 1 write, zero hardwired)
│   └── rv32_core.sv         # 5-stage pipelined core (IF/ID/EX/MEM/WB)
└── tb/
    └── tb_rv32_core.sv      # Testbench with memory models + test program
```

## Key Features

- **5-stage pipeline**: IF → ID → EX → MEM → WB
- **Full RV32I base ISA**: all 40 base instructions supported
- **Data hazard handling**: register forwarding (EX/MEM and MEM/WB bypasses) + load-use stall with flush
- **Branch resolution**: resolved in EX stage (branches/jumps taken in 2 cycles)
- **Load/store**: byte/half/word with byte-enable support

https://peter.hkprog.org/2026/11/qwen-3-8-27b-on-rtx-6000/

## Build & Run

```bash
cd /Users/peter/Desktop/riscv
make sim        # build + simulate
make clean      # remove build artifacts
make lint       # lint RTL only
```

## Test Results

The testbench verifies: `addi`, `add`, `and`, `or`, `xor`, `sw`, `lw` — all pass:

```
x1  = 10 (expected 10)
x2  = 20 (expected 20)
x3  = 30 (expected 30)
x4  = 25 (expected 25)
x5  = 1  (expected 1)
x6  = 30 (expected 30)
x7  = 20 (expected 20)
x8  = 30 (expected 30)
ALL TESTS PASSED!
```