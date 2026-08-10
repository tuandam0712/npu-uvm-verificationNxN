# NxN Systolic Array NPU Verification using UVM

## Overview

This project implements and verifies a parameterizable NxN systolic-array-based NPU for signed INT8 matrix multiplication.

Current verified configuration:

```text
N     = 8
width = 8
```

The verification environment is built in SystemVerilog UVM and targets QuestaSim / Questa Intel FPGA Edition.

Current verification techniques:

- Directed testing
- Constrained-random testing
- Boundary-biased random testing
- Back-to-back transaction testing
- Self-checking scoreboard
- SystemVerilog Assertions (SVA)
- Functional coverage

Coverage closure is treated as a measure of meaningful verified behavior. Unsupported behavior and artificial bins are not chased only to report a 100% number. Known coverage gaps are documented and tracked separately.

## Verification Layers

| Layer | Purpose |
|---|---|
| NPU Core UVM | Verifies the systolic-array NPU core through direct matrix-level transactions |
| APB Wrapper UVM | Verifies software-style APB access to CONTROL, STATUS, Matrix A, Matrix B, and Matrix C regions |

The NPU core and APB wrapper are verified as separate layers. APB wrapper documentation is provided in:

```text
docs/APB_REGISTER_MAP.md
docs/APB_TESTPLAN.md
```

## Current Regression Status

### NPU Core UVM Regression

Latest verified NPU core regression:

| Metric | Result |
|---|---:|
| Total NPU core transactions | 142 |
| Original directed tests | 6 |
| Extended directed tests | 6 |
| Full signed INT8 random tests | 5 |
| Boundary-biased random tests | 5 |
| Back-to-back random tests | 20 |
| Safe random tests | 100 |
| Scoreboard pass count | 142 |
| Scoreboard fail count | 0 |
| UVM warnings | 0 |
| UVM errors | 0 |
| UVM fatals | 0 |

Latest NPU functional coverage status:

| Coverage Type | Result |
|---|---:|
| Matrix pattern coverage | 100% |
| Scenario coverage | 100% |
| Output data coverage | 100% |
| Input data coverage | Latest coverage report must be regenerated |

The input coverage model has been strengthened to track full signed INT8 boundary-aware bins. If the regenerated report shows input coverage below 100%, that is documented as an intentional known coverage gap for the current scope instead of adding artificial tests only to close a number.

### APB Wrapper UVM Regression

Latest APB wrapper regression result:

| Metric | Result |
|---|---:|
| APB transactions | 1245 / 1245 PASS |
| C matrix checks | 384 / 384 PASS |
| UVM warnings | 0 |
| UVM errors | 0 |
| UVM fatals | 0 |
| APB functional coverage | 95.00% |

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

The current APB wrapper does not claim write-to-STATUS or write-to-C behavior as supported software flow. Active APB error response behavior is also not claimed because `pslverr` is tied to 0.

## Top Architecture

![Top Architecture](images/dir1.png)

The design consists of these major RTL blocks:

| File | Description |
|---|---|
| `pe.sv` | Signed multiply-accumulate processing element. |
| `systolic_arr_NxN.sv` | NxN PE interconnection, operand propagation, and valid wavefront. |
| `sa_controller_NxN.sv` | FSM controller for clear, compute, drain, and done sequencing. |
| `npu_top_NxN.sv` | Top-level integration of controller and systolic array. |
| `apb_npu_wrapper.sv` | APB register-mapped wrapper around the NPU top. |

## Verification Architecture

![Verification Architecture](images/dir2.png)

The NPU core UVM environment includes sequence items, sequences, driver, monitors, scoreboard, coverage collectors, agent, environment, and tests.

The APB wrapper UVM environment includes APB sequence items, sequences, sequencer, driver, monitor, agent, environment, scoreboard, functional coverage, and APB protocol SVA checker.

## Scoreboard and Golden Model

The NPU core scoreboard is self-checking. Input transactions captured by the input monitor are used to compute the expected matrix multiplication result:

```text
C[i][j] = sum(A[i][k] * B[k][j]) for k = 0 to N-1
```

The golden model computes the full-precision result using a 64-bit signed temporary value, then casts the expected result to the DUT accumulator width before comparison. A transaction is reported as PASS only when all matrix elements match.

The APB scoreboard captures APB writes to the Matrix A and Matrix B regions, computes the expected Matrix C result, and compares Matrix C readback values against the dynamic golden result.

## SystemVerilog Assertions

The project includes SVA checks for:

- PE reset, clear, hold, and MAC behavior
- Controller FSM transition and done sequencing behavior
- Systolic-array valid wavefront propagation and operand alignment
- APB protocol setup/access behavior and signal stability during wait states

## Functional Coverage

### NPU Core Functional Coverage

Functional coverage measures input value classes, matrix patterns, scenario types, and output value ranges.

The strengthened input coverage model tracks full signed INT8 boundary-aware operand classes and cross coverage. The current committed NPU coverage report artifact is stale relative to the 142-transaction regression and must be regenerated before a final input coverage percentage is claimed.

Current documented NPU coverage status:

| Coverage Type | Result |
|---|---:|
| Matrix pattern coverage | 100% |
| Scenario coverage | 100% |
| Output data coverage | 100% |
| Input data coverage | Latest coverage report must be regenerated |

### APB Functional Coverage

The APB coverage model tracks read/write accesses, CONTROL/STATUS/A/B/C address regions, CONTROL.start writes, STATUS reads, Matrix C readback count, busy/done observations, and slave-error observations.

Current APB functional coverage is 95.00%. The uncovered bins are accepted for the current wrapper scope because write-to-STATUS and write-to-C are not claimed as supported software flow, and active `pslverr` behavior is not implemented.

## How to Run

### Run NPU Core UVM regression

```tcl
do scripts/run_uvm.do
```

Expected clean result:

```text
original_directed=6 extended_directed=6 full_int8_random=5 boundary_random=5 btb_random=20 safe_random=100
SCB_PASS trans=142
SCB_FAIL trans=0
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

Expected coverage review:

```text
matrix pattern coverage = 100%
scenario coverage       = 100%
output data coverage    = 100%
input data coverage     = use regenerated report value
```

Do not claim complete NPU functional coverage unless every current coverage group in the regenerated report is actually fully covered.

## Current Limitations

### NPU Input Coverage Gap

The input coverage model was strengthened to track full signed INT8 boundary-aware bins. If the regenerated input coverage is below 100%, the gap is accepted for the current verified scope and tracked as future closure work.

### Reset During Compute

True reset-during-compute is not claimed as a supported verified feature in the current UVM environment. Supporting this correctly requires reset-aware driver, monitor, and scoreboard synchronization.

### APB Wrapper Coverage

The APB wrapper does not claim write-to-STATUS or write-to-C behavior as supported software flow. Active APB error response behavior is not claimed because `pslverr` is tied to 0.

### Code Coverage

Functional coverage is reported by the UVM coverage models. Full RTL code coverage closure is not claimed unless the corresponding Questa coverage report is generated and reviewed.

## Future Work

Planned improvements:

- Reset-aware UVM flow for true reset-during-compute testing
- Start-while-busy corner-case testing
- AXI-Lite wrapper verification
- More advanced APB negative/error-response testing if active `pslverr` support is added
- RTL code coverage closure with committed coverage report
- Formal checks for selected PE/controller properties
- CI/CD or automated regression publication

## Project Summary

```text
NPU NxN UVM verification
Configuration: N=8, width=8
Original directed tests: 6
Extended directed tests: 6
Full signed INT8 random tests: 5
Boundary-biased random tests: 5
Back-to-back random tests: 20
Safe random tests: 100
Total clean NPU regression: 142 transactions
NPU scoreboard pass/fail: 142 / 0
NPU UVM warnings/errors/fatals: 0 / 0 / 0
NPU coverage: matrix pattern 100%, scenario 100%, output 100%, input report must be regenerated

APB wrapper UVM verification
APB transactions: 1245 / 1245 PASS
C matrix checks: 384 / 384 PASS
APB protocol SVA: PASS
APB functional coverage: 95.00%
APB UVM warnings/errors/fatals: 0 / 0 / 0

Known limitations:
Reset-during-compute is future reset-aware work.
NPU input coverage gap is documented if regenerated input coverage is below 100%.
APB write-to-STATUS/write-to-C and active pslverr behavior are not claimed.
```
