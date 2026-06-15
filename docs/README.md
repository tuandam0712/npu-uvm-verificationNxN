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

## Verification Layers

This project currently contains two verification layers:

| Layer | Purpose |
|---|---|
| NPU Core UVM | Verifies the systolic-array NPU core through direct matrix-level transactions |
| APB Wrapper UVM | Verifies software-style APB access to CONTROL, STATUS, Matrix A, Matrix B, and Matrix C regions |

The NPU core UVM environment focuses on datapath, controller, systolic propagation, back-to-back operation, assertions, scoreboard checking, and functional coverage.

The APB wrapper UVM environment focuses on register-mapped access, APB-controlled matrix computation, status polling, signed APB readback, APB protocol SVA, dynamic APB scoreboard checking, and APB functional coverage.

APB wrapper documentation is provided in:

```text
docs/APB_REG_MAP.md
docs/APB_TESTPLAN.md
```

## Current Regression Status

### NPU Core UVM Regression

The latest clean NPU core regression contains:

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

Latest NPU functional coverage result:

| Coverage Type | Result |
|---|---:|
| Input Data Coverage | 100% |
| Matrix Pattern Coverage | 100% |
| Scenario Coverage | 100% |
| Output Data Coverage | 100% |

### APB Wrapper UVM Regression

Latest APB wrapper regression result:

| Metric | Result |
|---|---:|
| APB Transactions | 1245 / 1245 PASS |
| C Matrix Checks | 384 / 384 PASS |
| UVM Warnings | 0 |
| UVM Errors | 0 |
| UVM Fatals | 0 |
| APB Functional Coverage | 82.50% |

APB regression scenarios:

| Scenario | Status |
|---|---|
| Register access | PASS |
| Identity matrix compute | PASS |
| Zero matrix compute | PASS |
| Sparse matrix compute | PASS |
| Bounded random-like matrix compute | PASS |
| Signed matrix compute | PASS |
| Status behavior test | PASS |
| APB protocol SVA | PASS |

APB coverage summary:

```text
samples      = 1245
start_writes = 6
status_reads = 81
c_reads      = 384
busy_seen    = 72
done_seen    = 8
slverr_seen  = 0
```

> Note: These numbers refer to the UVM functional coverage and regression logs currently produced by the project. RTL code coverage closure such as statement, branch, condition, expression, and FSM transition coverage is not claimed unless a separate coverage report is generated and committed.

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
├── npu_top_NxN.sv
└── apb_npu_wrapper.sv
```

| File | Description |
|---|---|
| `pe.sv` | Signed multiply-accumulate processing element. |
| `systolic_arr_NxN.sv` | NxN PE interconnection, operand propagation, and valid wavefront. |
| `sa_controller_NxN.sv` | FSM controller for clear, compute, drain, and done sequencing. |
| `npu_top_NxN.sv` | Top-level integration of controller and systolic array. |
| `apb_npu_wrapper.sv` | APB register-mapped wrapper around the NPU top. |

## Verification Architecture

![Verification Architecture](images/dir2.png)

The NPU core UVM environment includes:

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

The APB wrapper UVM environment includes:

- APB sequence item
- APB sequences
- APB sequencer
- APB driver
- APB monitor
- APB agent
- APB environment
- APB scoreboard
- APB functional coverage
- APB protocol SVA checker

## Scoreboard and Golden Model

### NPU Core Scoreboard

The NPU core scoreboard is self-checking.

Input transactions captured by the input monitor are used to compute the expected matrix multiplication result:

```text
C[i][j] = sum(A[i][k] * B[k][j]) for k = 0 to N-1
```

The golden model computes the full-precision result using a 64-bit signed temporary value, then casts the expected result to the DUT accumulator width before comparison. This matches the fixed-width hardware accumulator behavior.

A transaction is reported as PASS only when all matrix elements match.

### APB Wrapper Scoreboard

The APB scoreboard dynamically captures APB writes to the Matrix A and Matrix B regions, stores them internally, and computes the expected Matrix C result.

When Matrix C is read back through APB, the scoreboard compares each read data value against the dynamically computed golden result.

This allows the same APB scoreboard to verify multiple scenarios without hard-coded expected C matrices.

## SystemVerilog Assertions

The project includes SVA checks for important RTL and APB behavior.

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

### APB Protocol

The APB protocol checker verifies basic APB protocol behavior, including:

- `PENABLE` only asserted when `PSEL` is asserted
- Access phase follows setup phase
- Address stability during wait states
- Write data stability during write wait states
- `PWRITE` stability during wait states

## Functional Coverage

### NPU Core Functional Coverage

Functional coverage is used to measure input value classes, matrix patterns, scenario types, and output value ranges.

#### Input Data Coverage

Input operands A and B are categorized into boundary-aware value classes:

- Zero value
- Minimum negative boundary value: `-64`
- Maximum positive boundary value: `63`
- Positive range: `[1:62]`
- Negative range: `[-63:-1]`
- Cross coverage between A and B value classes

#### Matrix Pattern Coverage

Directed matrix patterns include:

- Zero matrix
- Identity matrix
- Min/max boundary matrix
- All-positive matrix
- All-negative matrix
- Sparse matrix
- Random matrix

#### Scenario Coverage

Current scenario coverage includes:

- Normal transaction spacing
- Back-to-back transactions with zero idle gap

#### Output Data Coverage

Output matrix elements are categorized into magnitude-aware classes:

- Zero result
- Small positive result
- Large positive result
- Small negative result
- Large negative result

### APB Functional Coverage

The APB coverage model tracks:

- APB read/write accesses
- CONTROL, STATUS, A, B, and C address regions
- CONTROL.start writes
- STATUS reads
- Matrix C readback count
- Busy and done status observations
- Slave error observation count

Current APB coverage is 82.50%. APB invalid-address and active `pslverr` behavior are not claimed because the current APB wrapper does not implement active error response behavior.

## How to Run

### Run NPU Core UVM regression

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

### Run APB Wrapper UVM regression

```tcl
do scripts/run_apb_uvm.do
```

Expected clean result:

```text
APB transactions: 1245 / 1245 PASS
C matrix checks: 384 / 384 PASS
UVM_WARNING : 0
UVM_ERROR   : 0
UVM_FATAL   : 0
```

### Run NPU coverage

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

### APB Error Response

The current APB wrapper uses a zero-wait-state response and does not claim active `pslverr` error behavior.

Invalid address behavior and APB error-response verification are not claimed in the current APB regression.

### Code Coverage

Functional coverage is reported by the UVM coverage models. Full RTL code coverage closure is not claimed unless the corresponding Questa coverage report is generated and reviewed.

## Future Work

Planned improvements:

- Reset-aware UVM flow for true reset-during-compute testing
- Start-while-busy corner-case testing
- AXI-Lite wrapper verification
- More advanced APB negative/error-response testing if active `pslverr` support is added
- More detailed latency and performance counters
- Formal checks for PE/controller properties
- RTL code coverage closure with committed coverage report
- Regression automation and report generation

## Project Summary

Current verified status:

```text
NPU NxN UVM verification
Configuration: N=8, width=8
Directed tests: 6
Back-to-back random tests: 20
Random tests: 100
Total clean NPU regression: 126 tests
NPU scoreboard: width-accurate golden model
NPU functional coverage: input/matrix/scenario/output coverage all 100%

APB wrapper UVM verification
APB transactions: 1245 / 1245 PASS
C matrix checks: 384 / 384 PASS
APB protocol SVA: PASS
APB functional coverage: 82.50%
UVM warnings/errors/fatals: 0 / 0 / 0

Reset-during-compute: documented as future reset-aware enhancement
APB error-response behavior: not claimed in current wrapper
```
