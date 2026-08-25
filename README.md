# NxN Systolic Array NPU: RTL, UVM, SVA, and Formal Verification

## Overview

This project implements and verifies a parameterizable NxN systolic-array-based NPU for signed INT8 matrix multiplication.

Current verified configuration:

```text
N     = 8
width = 8
```

The project combines parameterized RTL design with layered verification. UVM simulation targets QuestaSim / Questa Intel FPGA Edition, while unit-level formal verification uses SymbiYosys, Yosys, SMTBMC, and Z3.

Current verification techniques:

- Directed testing
- Constrained-random testing
- Boundary-biased random testing
- Back-to-back transaction testing
- Self-checking scoreboard
- SystemVerilog Assertions (SVA)
- Functional coverage
- Formal proof and cover
- Requirement traceability and closure reporting

Coverage closure is treated as a measure of meaningful verified behavior. Unsupported behavior and artificial bins are not chased only to report a 100% number. Known coverage gaps are documented and tracked separately.

## Design and Verification Scope

| Layer | Purpose |
|---|---|
| PE unit verification | Verifies signed MAC, reset/clear priority, accumulator hold, and fixed-width behavior using directed tests, SVA, and formal proofs |
| Controller unit verification | Verifies FSM sequencing, phase timing, start handling, output decode, and reachability using directed tests, SVA, and formal proofs |
| Systolic-array unit verification | Verifies operand/valid routing, alignment, local MAC recurrence, matrix patterns, and output hold using directed tests, SVA, and quick/exact formal profiles |
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
| APB transactions | 1249 / 1249 PASS |
| C matrix checks | 384 / 384 PASS |
| UVM warnings | 0 |
| UVM errors | 0 |
| UVM fatals | 0 |
| APB functional coverage | 100.00% |

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
| Invalid, misaligned, and unsupported-direction access | PASS |
| Matrix A write and repeated start while busy | PASS |
| APB protocol SVA | PASS |

APB coverage summary:

```text
samples      = 1249
start_writes = 7
status_reads = 79
c_reads      = 384
busy_seen    = 70
done_seen    = 8
slverr_seen  = 9
```

Write-to-STATUS, write-to-C, read-from-CONTROL/A/B, invalid addresses, misaligned addresses, Matrix A writes while busy, and repeated start commands while busy are rejected with `pslverr`. The negative-access sequences check the expected response, and the scoreboard excludes rejected transfers from its A/B golden model.

## Unit-Level Verification and Closure

Unit-level verification complements the end-to-end UVM regressions. Detailed evidence and accepted gaps are recorded in [`reports/CLOSURE_REPORT.md`](reports/CLOSURE_REPORT.md).

### Processing Element (PE)

Primary configuration: `width=8`, `N=8`, `ACC_WIDTH=19`.

| Metric | Result |
|---|---:|
| Directed checks | 39 PASS, 0 FAIL |
| Formal tasks (`reset`, `clear`, `mac`, `hold`) | 4 / 4 PASS |
| Mutation test of clear priority | Injected bug detected by directed and formal checks |

The PE milestone covers asynchronous reset, reset/clear priority, signed multiply-accumulate behavior, product sign extension, accumulator hold, and fixed-width wraparound for the stated configuration.

### Systolic-Array Controller

| Method | Configuration | Result |
|---|---|---:|
| Formal proof/cover | `N=8`, `DRAIN_MARGIN=10` | 6 / 6 committed artifacts PASS |
| Directed simulation and embedded SVA | `N=4`, `DRAIN_MARGIN=3` | 0 failures across 26 assertions |
| SVA directive coverage | Saved controller run | 96.15% (25 / 26 covers reached) |

The controller milestone covers reset in every phase, start acceptance in IDLE, busy-start handling, exact phase progression, output decode, drain/done sequencing, held-start reacceptance, and back-to-back operations. The one uncovered directive is documented and accepted in the closure report.

### NxN Systolic Array (SARR)

| Metric | Result |
|---|---:|
| Directed regression at `N=8`, `width=8` | 22 PASS, 0 FAIL |
| Simulation assertion instances | 1,348 PASS, 0 FAIL |
| SVA cover-directive instances | 1,585 reached; 100.00% directive coverage |
| Quick formal profile (`N=2`, `width=4`) | 6 / 6 tasks PASS |
| Exact formal profile (`N=8`, `width=8`) | 6 / 6 tasks PASS |
| Formal cover statements | 6 / 6 reached in both profiles |

The exact profile proves the implemented local reset, clear, operand-routing, valid-routing, MAC-recurrence, and accumulator-hold properties on the primary 8x8 RTL configuration. The 100% SARR number is SVA directive coverage for the saved directed run, not functional-covergroup or RTL code coverage.

## Top Architecture

![Top Architecture](images/dir1.png)

The design consists of these major RTL blocks:

| File | Description |
|---|---|
| `pe.sv` | Signed multiply-accumulate processing element. |
| `systolic_arr_NxN.sv` | NxN PE interconnection, operand propagation, and valid wavefront. |
| `sa_controller_NxN.sv` | FSM controller for clear, compute, drain, and done sequencing. |
| `npu_top_NXN.sv` | Top-level integration of controller and systolic array. |
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
- Controller FSM transitions, phase outputs, counter progression, start handling, exact latency, and done sequencing
- Systolic-array reset/clear priority, operand and valid routing, alignment, local MAC recurrence, and output hold
- APB protocol setup/access behavior and signal stability during wait states

Simulation SVA is complemented by cover directives to expose vacuous or unexercised scenarios. Assertion/directive percentages are reported separately from functional coverage.

## Formal Verification

Formal verification is maintained for the PE, controller, and systolic array:

| Scope | Engine | Current result |
|---|---|---:|
| PE | SymbiYosys + Yosys + SMTBMC + Z3 | 4 / 4 tasks PASS |
| Controller | SymbiYosys + Yosys + SMTBMC + Z3 | 5 / 5 prove tasks and cover run PASS |
| SARR quick profile | SymbiYosys + Yosys + SMTBMC + Z3 | 6 / 6 tasks PASS |
| SARR exact 8x8 profile | SymbiYosys + Yosys + SMTBMC + Z3 | 6 / 6 tasks PASS |

The formal harnesses use named assertions aligned with the RTL requirements. Current SARR proofs are local/block-level properties; a single end-to-end formal proof of complete matrix multiplication is not claimed.

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

Current APB functional coverage is 100.00%. Both normal and slave-error response bins are covered. The regression observes nine error responses across unsupported-direction, invalid, misaligned, and busy-state accesses.

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
APB transactions: 1249 / 1249 PASS
C matrix checks: 384 / 384 PASS
PSLVERR observations: 9
APB functional coverage: 100.00%
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

### Run unit formal regressions

Run SymbiYosys from WSL or another Linux environment that provides `sby`, Yosys, SMTBMC, and Z3.

```bash
sby -f formal/pe/pe.sby
sby -f formal/controller/controller.sby
sby -f formal/controller/controller_cover.sby
bash formal/sarr/run_sarr_formal.sh quick
bash formal/sarr/run_sarr_formal.sh 8x8
```

The SARR wrapper runs tasks sequentially to avoid starting every Z3 process at once. The quick profile is intended for fast structural regression; the 8x8 profile uses the primary RTL parameters and task-specific proof/cover depths.

## Current Limitations

### NPU Input Coverage Gap

The input coverage model was strengthened to track full signed INT8 boundary-aware bins. If the regenerated input coverage is below 100%, the gap is accepted for the current verified scope and tracked as future closure work.

### Reset During Compute

True reset-during-compute is not claimed as a supported verified feature in the current UVM environment. Supporting this correctly requires reset-aware driver, monitor, and scoreboard synchronization.

### APB Wrapper Protocol Scope

The implemented APB wrapper uses a zero-wait-state response. Active error responses are verified for unsupported read/write directions, invalid and misaligned addresses, Matrix A/B writes while busy, and repeated start commands while busy. Full wait-state and APB VIP-level constrained-random protocol closure are not claimed.

### Code Coverage

Functional coverage is reported by the UVM coverage models. Full RTL code coverage closure is not claimed unless the corresponding Questa coverage report is generated and reviewed.

### Unit-Level Closure Scope

PE, controller, and SARR closure statements apply only to the configurations documented in `reports/CLOSURE_REPORT.md`. Exhaustive parameter-space closure and a single end-to-end formal proof of complete matrix multiplication are not claimed.

## Future Work

Planned improvements:

- Reset-aware UVM flow for true reset-during-compute testing
- Regenerate and review the strengthened NPU input functional coverage report
- Directed parameter regressions at additional legal `N`, operand-width, and accumulator-width configurations
- Dedicated SARR functional covergroups and additional signed boundary/wraparound tests
- End-to-end formal matrix-result proof if required by the agreed project scope
- AXI-Lite wrapper verification
- APB wait-state and back-to-back-transfer verification with stronger protocol assertions
- Parameter-aware APB address-map generation and overlap checks for non-default `N`
- RTL code coverage closure with committed coverage report
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
APB transactions: 1249 / 1249 PASS
C matrix checks: 384 / 384 PASS
APB protocol SVA: PASS
APB error responses observed: 9
APB functional coverage: 100.00%
APB UVM warnings/errors/fatals: 0 / 0 / 0

Unit-level directed / SVA / formal verification
PE directed checks: 39 PASS, 0 FAIL
PE formal: 4 / 4 tasks PASS
Controller formal: 5 / 5 prove tasks PASS; cover PASS
Controller simulation SVA: 0 failures across 26 assertions; 96.15% directive coverage
SARR directed checks: 22 PASS, 0 FAIL
SARR simulation SVA: 1,348 assertion passes, 0 failures; 1,585 cover hits; 100% directive coverage
SARR formal: 6 / 6 quick tasks PASS; 6 / 6 exact 8x8 tasks PASS

Known limitations:
Reset-during-compute is future reset-aware work.
NPU input coverage gap is documented if regenerated input coverage is below 100%.
APB error responses for unsupported, invalid, misaligned, and busy-state accesses are verified; wait-state and full VIP-level protocol closure are not claimed.
Full RTL code coverage and exhaustive parameter-space closure are not claimed.
End-to-end formal proof of complete matrix multiplication is not claimed.
```
