# RV32I 5-Stage Pipelined Processor
A fully functional **RISC-V RV32I** 5-stage pipelined CPU implemented in Verilog.
The design includes forwarding, hazard detection, stall insertion, branch flushing,
and clean ALU/memory behavior.

## Pipeline Overview
- IF – Instruction Fetch
- ID – Instruction Decode & Register Read
- EX – ALU & Branch Evaluation
- MEM – Data Memory Access
- WB – Register Writeback

## Key Features
- Full RV32I 5-stage pipeline
- Load-use hazard detection + automatic stall
- EX/MEM → EX and MEM/WB → EX forwarding
- BEQ branch flush support
- 4 KB IMEM & DMEM
- ALU supports: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU

## Project Structure
src/ <br>
 ├── rv32i_pipeline.v <br>
 ├── control.v <br>
 ├── regfile.v<br>
 ├── alu.v<br>
 ├── hazard_unit.v<br>
 ├── forward_unit.v<br>
 └── rv32i_pipeline_tb.v<br>

README.md

## Simulation (Icarus Verilog)
iverilog -g2012 -o sim rv32i_pipeline.v control.v regfile.v alu.v hazard_unit.v forward_unit.v rv32i_pipeline_tb.v<br>
vvp sim<br>

## Included Example Program
addi x1, x0, 5<br>
addi x2, x0, 7<br>
add  x3, x1, x2<br>
sw   x3, 0(x0)<br>
auipc x4, 1<br>
jal  x0, 0<br>

## ALU Demonstration Program

addi x1, x0, 5<br>
addi x2, x0, 12<br>
add  x3, x1, x2<br>
sub  x4, x2, x1<br>
and  x5, x1, x2<br>
or   x6, x1, x2<br>
xor  x7, x1, x2<br>
sll  x8, x1, x2<br>
srl  x9, x2, x1<br>
sra  x10,x2,x1<br>
slt  x11,x1,x2<br>
sltu x12,x1,x2<br>
jal x0,0<br>


## Author
Rohan R
