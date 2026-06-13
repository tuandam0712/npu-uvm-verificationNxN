# NxN Systolic Array NPU Verification using UVM

## Table of Contents

- [Overview](#overview)
- [Top Architecture](#top-architecture)
- [Processing Element](#processing-element-pe)
- [RTL Structure](#rtl-structure)
- [Verification Architecture](#verification-architecture)
- [Scoreboard and Golden Model](#scoreboard-and-golden-model)
- [SystemVerilog Assertions](#systemverilog-assertions)
- [Functional Coverage](#functional-coverage)
- [Regression Results](#regression-results)
- [How to Run](#how-to-run)
- [Future Work](#future-work)

## Overview

This project implements and verifies a parameterizable NxN Neural Processing Unit (NPU) based on a systolic array architecture for signed INT8 matrix multiplication.

The RTL design is developed in SystemVerilog and supports configurable array dimensions through parameterization.

A complete UVM verification environment is built to validate functionality, timing behavior, and data propagation across the systolic array.

Verification techniques used in this project include:

- Directed testing
- Constrained-random testing
- Golden-model scoreboard checking
- SystemVerilog Assertions (SVA)
- Functional coverage
- Regression testing

Current regression status:

| Metric | Result |
|---|---:|
| Total Tests | 106 |
| Directed Tests | 6 |
| Random Tests | 100 |
| Passed | 106 |
| Failed | 0 |
| UVM Errors | 0 |
| UVM Fatals | 0 |

Current functional coverage status:

| Coverage Type | Result |
|---|---:|
| Input Data Coverage | 100% |
| Matrix Pattern Coverage | 100% |
| Output Data Coverage | 100% |
| Total Functional Coverage | 100% |

## Top Architecture

![Top Architecture](images/dir1.png)

The design consists of two major RTL blocks:

### Controller FSM

The controller manages the computation flow using the following states:

- IDLE
- CLEAR
- COMPUTE
- WAIT_DRAIN
- DONE

### NxN Systolic Array

- The systolic array is composed of NxN Processing Elements (PEs).
- Input matrix A propagates horizontally across the array.
- Input matrix B propagates vertically across the array.
- A wavefront-based valid signal propagates together with the operands to guarantee timing alignment.

## Processing Element (PE)

Each PE is intentionally designed as a lightweight MAC cell.

Inputs:

- `a_in`
- `b_in`
- `valid`
- `clear`

Output:

- Accumulated result

Operation priority:

1. Reset
2. Clear
3. MAC operation
4. Hold accumulated value

Operand forwarding is not implemented inside the PE. Data propagation and skew management are handled at the systolic array level.

## RTL Structure

```text
rtl/
├── pe.sv
├── systolic_arr_NxN.sv
├── sa_controller_NxN.sv
└── npu_top_NxN.sv
```

| File | Description |
|---|---|
| `pe.sv` | Implements signed Multiply-Accumulate (MAC) functionality. |
| `systolic_arr_NxN.sv` | Implements operand skewing, valid propagation, and PE interconnection. |
| `sa_controller_NxN.sv` | Controls computation sequencing and latency management. |
| `npu_top_NxN.sv` | Top-level integration of controller and systolic array. |

## Verification Architecture

![Verification Architecture](images/dir2.png)

The UVM environment includes:

- Sequence
- Driver
- Input monitor
- Output monitor
- Scoreboard
- Functional coverage collectors
- Agent
- Environment
- Test

## Scoreboard and Golden Model

The verification environment uses a self-checking scoreboard.

Input transactions captured by the input monitor are used to generate expected matrix multiplication results through a golden reference model.

Output transactions captured by the output monitor are compared against the expected results.

A transaction is reported as PASS only when all matrix elements match the expected reference values.

This approach enables automated regression testing without manual waveform inspection.

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

## Functional Coverage

Functional coverage is used to measure verification completeness and scenario exploration.

### Input Data Coverage

Input operands A and B are categorized into boundary-aware value classes:

- Zero value
- Minimum negative boundary value: `-64`
- Maximum positive boundary value: `63`
- Normal positive range: `[1:62]`
- Normal negative range: `[-63:-1]`
- Cross coverage between A and B value classes

This improves the previous sign-only coverage by explicitly checking important boundary values used by signed INT8 MAC operations.

### Matrix Pattern Coverage

Directed matrix patterns include:

- Zero matrix
- Identity matrix
- Random matrix
- All-positive matrix
- All-negative matrix
- Sparse matrix

### Output Data Coverage

Output matrix elements are categorized into:

- Zero result
- Small positive result
- Large positive result
- Small negative result
- Large negative result

Coverage closure target:

- 100% input data coverage
- 100% matrix pattern coverage
- 100% output data coverage

## Regression Results

The verification environment was executed using both directed and constrained-random testing.

### Regression Summary

| Metric | Result |
|---|---:|
| Total Tests | 106 |
| Directed Tests | 6 |
| Random Tests | 100 |
| Passed | 106 |
| Failed | 0 |
| UVM Errors | 0 |
| UVM Fatals | 0 |

### Functional Coverage Summary

| Coverage Type | Result |
|---|---:|
| Input Data Coverage | 100% |
| Matrix Pattern Coverage | 100% |
| Output Data Coverage | 100% |
| Total Functional Coverage | 100% |

Questa-generated coverage reports are stored under `reports/` when the coverage script is executed.

Generated simulator databases such as `.ucdb`, `.wlf`, `.vcd`, `work/`, and raw transcripts are intentionally excluded from the repository.

## How to Run

### Run normal UVM regression

```tcl
do scripts/run_uvm.do
```

Expected result:

```text
106/106 tests passed
0 UVM errors
0 UVM fatals
```

### Run coverage closure

```tcl
do scripts/run_cov.do
```

This flow runs:

- UVM normal regression
- RTL reset-abort coverage test
- UCDB coverage merge
- Final coverage report generation

Expected coverage result:

| Coverage Type | Result |
|---|---:|
| Statement Coverage | 100% |
| Branch Coverage | 100% |
| Condition Coverage | 100% |
| Expression Coverage | 100% |
| FSM State Coverage | 100% |
| FSM Transition Coverage | 100% |
| Functional Coverage | 100% |

## Future Work

Future improvements include:

- APB UVM agent and APB protocol-level verification
- Advanced protocol assertions
- Reset and start/busy corner-case sequences
- Coverage closure automation
- Regression infrastructure enhancement
- Formal verification exploration
- Reusable AI accelerator verification framework

Long-term goal: evolve this project into a reusable open-source verification platform for AI accelerator IPs.
