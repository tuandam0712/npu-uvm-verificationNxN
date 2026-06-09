# NxN Systolic Array NPU Verification using UVM

## Table of Contents

- Overview
- Top Architecture
- Processing Element
- RTL Structure
- Verification Architecture
- Scoreboard and Golden Model
- SystemVerilog Assertions
- Functional Coverage
- Regression Results
- How to Run
- Future Work

## Overview

This project implements and verifies a parameterizable NxN Neural Processing Unit(NPU) based on a systolic array architecture for signed INT8 matrix multiplication.

The RTL design is developed in SystemVerilog and supports configurable array dimensions through parameterization.

A complete UVM verification environment is built to validate functionality, timing behavior, and data propagation across the systolic array.

Verification techniques used in this project include:
- Directed testing
- Constrained random testing 
- Golden model scb checking 
- SystemVerilog Assertions (SVA)
- Functional coverage
- Regression testing

Current regression status:
- 102/102 tests passed
- 0 UVM err
- 0 UVM fatals
- 100% in data coverage
- 100% matrix pattern coverage
- 100% out data coverage

## Top architecture
![Top Architecture](images/dir1.png)

The design consists of 2 major RTL blocks:

Controller FSM
The controller manages the computation flow using five states:
- IDLE
- CLEAR
- COMPUTE
- WAIT_DRAIN
- DONE

NxN Systolic Array
- The systolic array is composed of NxN Processing Elements (PEs)
- Input matrix A propagates horizontally across the array
- input matrix B propagates verically across the array
- A wavefront based valid signal propagates together with the operands to guarantee timing alignment

## Processing Element (PE)

Each PE is intentionally designed as a lightweight MAC cell.

Inputs:
- a_in
- b_in
- valid
- clear

Output:
- accumulated result

Operation priority:
- Reset
- Clear
- MAC operation
- Hold accumulated value

Operand forwarding is not implemented inside the PE

Data propagation and skew management are handled at the systolic array level

## RTL Structure

rtl/
|-- pe.sv
|
|-- systolic_arr_NxN.sv
|
|-- sa_controller_NxN.sv
|
|-- npu_top_NxN.sv

pe.sv

Implements signed Multiply Accmulate (MAC)functionality.

systolic_arr_NxN.sv

Implements operand skewing, valid propagation, and PE interconnection.

sa_controller_NxN.sv

Controls computation sequencing and latency management.

npu_top_NxN.sv

Top level integration of controller and systolic array.

## Verification Architecture
![Verification Architecture](images/dir2.png)

## Scoreboard and Golden Model

The verification environment uses a self_checking scoreboard

Input trans captured by the input monitor are used to gen expected matrix multiplication results through a golden reference model

Output trans captured by the output monitor are compared against the expected results

A trans is reported as PASS only when all matrix elements match the expected reference values

This approach enables automated regression testing without manual waveform inspection

## SystemVerilog Assertions

Implemented assertion categories:

### Processing Element (PE)

- Reset behavior
- Clear behavior
- Hold behavior
- MAC operation correctness

### Controller

- State transition checking
- Done pulse width checking
- Start-to-done latency checking

### Systolic Array

- Valid wavefront propagation
- Operand alignment checking
- No-X checking during valid operation