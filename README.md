# NxN Systolic Array NPU Verification using UVM

## Overview

This project implements and verifies a parameterizable NxN systolic-array-based NPU for signed INT8 matrix multiplication.

The RTL design is written in SystemVerilog and supports configurable array size through parameters. The current verified configuration is:

```text
N     = 8
width = 8
```

The verification environment is built using UVM and focuses on functional correctness, systolic data propagation, controller sequencing, scoreboard checking, assertions, and functional coverage.

Verification techniques used in the current project:

- Directed testing
- Constrained-random testing
- Back-to-back transaction testing
- Self-checking scoreboard
- SystemVerilog Assertions (SVA)
- Functional coverage
- Regression testing in QuestaSim/ModelSim

## Current Regression Status

The latest clean regression contains:

| Metric | Result |
|---|---:|
| Total Tests | 126 |
| Directed Tests | 6 |
| Back-to-Back Random Tests | 20 |
| Random Tests | 100 |
| Passed | 126 |
| Failed | 0 |
| UVM Warnings | 0 |
| UVM Errors | 0 |
| UVM Fatals | 0 |

Latest functional coverage result:

| Coverage Type | Result |
|---|---:|
| Input Data Coverage | 100% |
| Matrix Pattern Coverage | 100% |
| Scenario Coverage | 100% |
| Output Data Coverage | 100% |

> Note: These numbers refer to the UVM functional coverage and regression log currently produced by the project. Code coverage closure such as statement, branch, condition, expression, and FSM transition coverage is not claimed unless a separate coverage report is generated and committed.

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

Main controller responsibilities:

- Generate the `clear` signal before computation.
- Generate the `valid_in` signal during input loading.
- Control the compute and drain latency.
- Assert `done` when the output matrix is ready.

### NxN Systolic Array

The systolic array is composed of NxN processing elements.

Main behavior:

- Matrix A operands propagate horizontally.
- Matrix B operands propagate vertically.
- Valid signals propagate as a wavefront to align data movement and MAC operations.
- Output matrix elements are accumulated inside the PEs.

## Processing Element (PE)

Each PE is a signed multiply-accumulate cell.

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
3. MAC operation when `valid = 1`
4. Hold accumulated value when not computing

Operand forwarding is not implemented inside the PE. Operand skewing and propagation are handled at the systolic array level.

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
| `pe.sv` | Signed multiply-accumulate processing element. |
| `systolic_arr_NxN.sv` | NxN PE interconnection, operand propagation, and valid wavefront. |
| `sa_controller_NxN.sv` | FSM controller for clear, compute, drain, and done sequencing. |
| `npu_top_NxN.sv` | Top-level integration of controller and systolic array. |

## Verification Architecture

![Verification Architecture](images/dir2.png)

The UVM environment includes:

- Sequence item
- Sequences
- Driver
- Input monitor
- Output monitor
- Scoreboard
- Functional coverage collectors
- Agent
- Environment
- Test

The environment is transaction-based. For a normal transaction, the driver sends one matrix multiplication operation, the input monitor captures the input matrix transaction, the output monitor captures the output matrix when `done` is asserted, and the scoreboard compares actual output against the golden model.

## Scoreboard and Golden Model

The scoreboard is self-checking.

Input transactions captured by the input monitor are used to compute the expected matrix multiplication result:

```text
C[i][j] = sum(A[i][k] * B[k][j]) for k = 0 to N-1
```

The golden model computes the full-precision result using a 64-bit signed temporary value, then casts the expected result to the DUT accumulator width before comparison. This matches the fixed-width hardware accumulator behavior.

A transaction is reported as PASS only when all matrix elements match.

## SystemVerilog Assertions

The project includes SVA checks for important RTL behavior.

Assertion categories:

### Processing Element

- Reset behavior
- Clear behavior
- Hold behavior
- MAC operation behavior

### Controller

- FSM transition behavior
- `done` behavior
- Start-to-done sequencing/latency behavior

### Systolic Array

- Valid wavefront propagation
- Operand alignment
- No-X checking during valid operation

## Functional Coverage

Functional coverage is used to measure input value classes, matrix patterns, scenario types, and output value ranges.

### Input Data Coverage

Input operands A and B are categorized into boundary-aware value classes:

- Zero value
- Minimum negative boundary value: `-64`
- Maximum positive boundary value: `63`
- Positive range: `[1:62]`
- Negative range: `[-63:-1]`
- Cross coverage between A and B value classes

### Matrix Pattern Coverage

Directed matrix patterns include:

- Zero matrix
- Identity matrix
- Min/max boundary matrix
- All-positive matrix
- All-negative matrix
- Sparse matrix
- Random matrix

### Scenario Coverage

Current scenario coverage includes:

- Normal transaction spacing
- Back-to-back transactions with zero idle gap

### Output Data Coverage

Output matrix elements are categorized into magnitude-aware classes:

- Zero result
- Small positive result
- Large positive result
- Small negative result
- Large negative result

## Regression Results

### Regression Summary

| Metric | Result |
|---|---:|
| Total Tests | 126 |
| Directed Tests | 6 |
| Back-to-Back Random Tests | 20 |
| Random Tests | 100 |
| Passed | 126 |
| Failed | 0 |
| UVM Warnings | 0 |
| UVM Errors | 0 |
| UVM Fatals | 0 |

### Functional Coverage Summary

| Coverage Type | Result |
|---|---:|
| Input Data Coverage | 100% |
| Matrix Pattern Coverage | 100% |
| Scenario Coverage | 100% |
| Output Data Coverage | 100% |

## How to Run

### Run UVM regression

```tcl
do scripts/run_uvm.do
```

Expected clean result:

```text
tests=126 directed=6 btb=20 random=100
SCB_PASS trans=126
UVM_WARNING : 0
UVM_ERROR   : 0
UVM_FATAL   : 0
```

### Run coverage

```tcl
do scripts/run_cov.do
```

Expected functional coverage result:

```text
input data coverage   = 100%
matrix pattern cov    = 100%
scenario cov          = 100%
output data coverage  = 100%
```

## Current Limitations

### Reset During Compute

True reset-during-compute is not claimed as a supported verified feature in the current UVM environment.

The current UVM environment is transaction-based and assumes that a started transaction eventually produces a valid `done` response. A reset asserted in the middle of computation aborts the active transaction and may legally produce no output. Supporting this correctly requires reset-aware driver, monitor, and scoreboard synchronization.

This was analyzed during development, but it is not included in the clean regression to avoid false scoreboard mismatches or unstable transaction pairing.

### Code Coverage

Functional coverage is reported by the UVM coverage model. Full RTL code coverage closure is not claimed unless the corresponding Questa coverage report is generated and reviewed.

## Future Work

Planned improvements:

- Reset-aware UVM flow for true reset-during-compute testing
- Start-while-busy corner-case testing
- APB or AXI-Lite wrapper verification
- Protocol-level assertions
- More detailed latency and performance counters
- Formal checks for PE/controller properties
- Regression automation and report generation

## Project Summary

Current verified status:

```text
NPU NxN UVM verification
Configuration: N=8, width=8
Directed tests: 6
Back-to-back random tests: 20
Random tests: 100
Total clean regression: 126 tests
Scoreboard: width-accurate golden model
Functional coverage: input/matrix/scenario/output coverage all 100%
Reset-during-compute: documented as future reset-aware enhancement
```
