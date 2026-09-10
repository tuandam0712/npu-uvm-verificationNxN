# NxN Systolic Array NPU Verification Test Plan

## 1. Scope

This document defines the verification strategy for the parameterizable NxN systolic-array-based NPU core.

Current verified configuration:

```text
N     = 8
width = 8
```

The objective is to verify functional correctness, controller sequencing, operand propagation, valid wavefront behavior, accumulator behavior, and end-to-end signed matrix multiplication results using SystemVerilog UVM on QuestaSim / Questa Intel FPGA Edition.

The NPU core UVM testplan is described in this file. APB wrapper verification is a separate layer and is documented in:

```text
docs/APB_TESTPLAN.md
```

## 2. Features Under Verification

| ID | Feature | Scope |
|---|---|---|
| F1 | Processing element reset, clear, hold, and signed MAC behavior | NPU core |
| F2 | A operand horizontal propagation | NPU core |
| F3 | B operand vertical propagation | NPU core |
| F4 | Valid wavefront propagation and operand alignment | NPU core |
| F5 | Controller clear, compute, drain, and done sequencing | NPU core |
| F6 | End-to-end signed INT8 matrix multiplication | NPU core |
| F7 | Back-to-back transaction handling | NPU core |
| F8 | Reset during COMPUTE and WAIT_DRAIN | Directed N=8 recovery verified; exhaustive timing remains open |

## 3. Verification Matrix

| Feature | Directed | Random | Back-to-Back | SVA | Functional Coverage | Status |
|---|---:|---:|---:|---:|---:|---|
| PE reset/clear/hold/MAC behavior | Yes | Yes | Yes | Yes | Partial | Verified in clean regression |
| A operand propagation | Yes | Yes | Yes | Yes | Yes | Verified in clean regression |
| B operand propagation | Yes | Yes | Yes | Yes | Yes | Verified in clean regression |
| Valid wavefront | Yes | Yes | Yes | Yes | Yes | Verified in clean regression |
| Controller sequencing | Yes | Yes | Yes | Yes | Yes | Verified in clean regression |
| End-to-end matrix multiplication | Yes | Yes | Yes | No | Yes | Verified by scoreboard |
| Back-to-back transaction scenario | No | Yes | Yes | No | Yes | Verified in clean regression |
| Reset during COMPUTE / DRAIN | Yes | No | No | Embedded checks plus TB reset-state checks | No dedicated reset cross | PASS at two directed points |

## 4. Risk Analysis

| ID | Risk Description | Detection Method | Current Status |
|---|---|---|---|
| R1 | Accumulator is not cleared correctly. | Directed tests + SVA | Covered |
| R2 | MAC computation is incorrect. | Scoreboard | Covered |
| R3 | Valid propagation is misaligned. | Array SVA + scoreboard | Covered |
| R4 | Controller latency is incorrect. | Controller SVA + directed tests | Covered |
| R5 | Operand skew is mismatched. | Directed tests + scoreboard | Covered |
| R6 | Boundary signed values are not handled correctly. | Directed boundary tests + input coverage | Covered by tests; seed-1 input coverage 89.53% |
| R7 | Sparse or signed matrix patterns are not covered. | Directed pattern tests + matrix coverage | Covered |
| R8 | Back-to-back transactions corrupt internal state. | Back-to-back random tests | Covered |
| R9 | Reset aborts an operation and corrupts UVM pairing. | Task cancellation, FIFO flush, exact abort/completion counts, recovery scoreboard | Directed COMPUTE/DRAIN PASS |

## 5. Test Scenarios

Current clean NPU core regression contains:

| Test Type | Count | Purpose |
|---|---:|---|
| Original directed tests | 6 | Cover baseline known matrix patterns |
| Extended directed tests | 6 | Cover additional zero-row, zero-column, signed, impulse, boundary, and sparse patterns |
| Full signed INT8 random tests | 5 | Exercise full signed INT8 behavior |
| Boundary-biased random tests | 5 | Bias random operands toward important signed boundaries |
| Back-to-back random tests | 20 | Stress transaction-to-transaction continuity with zero idle gap |
| Safe random tests | 100 | Exercise constrained-random signed matrix multiplication |
| Total NPU core transactions | 142 | Combined clean regression |

Directed and extended scenario names:

| Scenario | Purpose |
|---|---|
| `ZERO_TEST` | All-zero matrix behavior |
| `IDENTITY_TEST` | Identity matrix behavior |
| `MIN_MAX_TEST` | Signed min/max boundary behavior |
| `ALL_POSITIVE_TEST` | All-positive operand behavior |
| `ALL_NEGATIVE_TEST` | All-negative operand behavior |
| `SPARSE_TEST` | Sparse matrix behavior |
| `ROW_ZERO_TEST` | Zero-row matrix behavior |
| `COL_ZERO_TEST` | Zero-column matrix behavior |
| `ALTERNATING_SIGN_TEST` | Alternating signed operand behavior |
| `SINGLE_IMPULSE_TEST` | Single non-zero impulse behavior |
| `FULL_INT8_BOUNDARY_TEST` | Full signed INT8 boundary behavior |
| `NON_DIAGONAL_SPARSE_TEST` | Sparse non-diagonal behavior |
| `FULL_INT8_RANDOM_TEST` | Full signed INT8 random behavior |
| `BOUNDARY_RANDOM_TEST` | Boundary-biased random behavior |

Back-to-back tests execute random matrix transactions with zero idle gap in the test flow to check consecutive operation handling and scoreboard pairing.

## 6. Scoreboard Plan

The scoreboard compares actual DUT output against a software golden model:

```text
C[i][j] = sum(A[i][k] * B[k][j]) for k = 0 to N-1
```

The expected result is calculated using a 64-bit signed temporary value, then cast to the DUT accumulator width before comparison. One matrix transaction is reported as PASS only when every output element matches.

## 7. Functional Coverage Plan

### Input Coverage

Input operands A and B are categorized into signed INT8 boundary-aware value classes. The fixed-seed-1 runtime summary reports 89.53%; detailed UCDB/bin-level analysis remains separate work.

Known coverage decision:

- Do not add artificial tests only to force a 100% input coverage number.
- If the regenerated input coverage is below 100%, document it as a known coverage gap for the current scope.
- The gap is tracked as future closure work.

### Matrix Pattern Coverage

| Bin | Description |
|---|---|
| `zero` | Zero matrix pattern. |
| `identity` | Identity matrix pattern. |
| `random` | Random matrix pattern. |
| `all_positive` | All operands are positive. |
| `all_negative` | All operands are negative. |
| `sparse` | Mostly-zero matrix with selected non-zero entries. |

### Scenario Coverage

| Bin | Description |
|---|---|
| `normal` | Normal transaction spacing. |
| `back_to_back` | Back-to-back transaction scenario with zero idle gap in the test flow. |

### Output Coverage

Output matrix elements are categorized into zero, positive, negative, and magnitude-aware result classes.

## 8. Closure Criteria

Verification is considered clean for the current NPU core scope when:

- Baseline: scoreboard reports 142 PASS and driver reports 0 aborts.
- Each reset case: scoreboard reports 141 PASS and driver reports exactly 1 abort, independently required by the scenario.
- Both scoreboard FIFOs are empty at end of test; no simulation assertion error is present.
- Scoreboard reports 0 failing transactions.
- UVM warning count is 0.
- UVM error count is 0.
- UVM fatal count is 0.
- Coverage report is generated and reviewed.
- Baseline matrix pattern coverage is 100%; reset runs replace the zero victim with nonzero operands and report 92.31%, so they are not substitutes for baseline coverage.
- Scenario coverage is 100%.
- Output data coverage is 100%.
- Input coverage gap is documented if input coverage is below 100%.

Blanket 100% NPU functional coverage is not claimed unless every current coverage group in the regenerated report is actually 100%.

## 9. Verification Traceability Matrix

| Feature | Test | Assertion | Coverage | Current Status |
|---|---|---|---|---|
| PE reset/clear/hold/MAC behavior | Directed + random | PE SVA | Partial | PASS in current regression |
| A propagation | Directed + random | Array SVA | Input/matrix coverage | PASS in current regression |
| B propagation | Directed + random | Array SVA | Input/matrix coverage | PASS in current regression |
| Valid wavefront | Directed + random | Array SVA | Matrix/scenario coverage | PASS in current regression |
| Controller sequencing | Directed + random | Controller SVA | Scenario coverage | PASS in current regression |
| Boundary signed values | `MIN_MAX_TEST`, `FULL_INT8_BOUNDARY_TEST`, random tests | None | Input value coverage | PASS in baseline; input bins remain open (89.53% at seed 1) |
| Matrix patterns | Directed pattern tests | None | Matrix pattern coverage | PASS in current regression |
| Output result ranges | Directed + random | None | Output data coverage | PASS in current regression |
| Back-to-back transactions | Back-to-back random tests | None | Scenario coverage | PASS in current regression |
| End-to-end matrix multiply | Directed + random + back-to-back | None | Scoreboard comparison | PASS in current regression |

## 10. Latest Clean Regression Result

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

| Functional Coverage Type | Result |
|---|---:|
| Matrix pattern coverage | 100% |
| Scenario coverage | 100% |
| Output data coverage | 100% |
| Input data coverage | 89.53% (seed-1 runtime summary) |

## 11. Known Coverage Gap

Input coverage is 89.53% at seed 1. Remaining signed INT8 boundary-aware bins are tracked as a current gap; no complete functional-coverage claim is made.

The project intentionally does not chase unsupported or artificial bins only to report a 100% number.

## 12. Directed Reset Recovery

Run `do scripts/run_npu_reset.do all` from the repository root. The script uses Questa 10.7c, seed 1, and N=8/width=8. Baseline completes 142 operations; each of COMPUTE and WAIT_DRAIN runs aborts one nonzero victim and completes 141 operations with zero mismatches and UVM errors/fatals.

COMPUTE reset interrupts after 4/8 slices, testing partial input cancellation. DRAIN reset follows the complete feed, testing cancellation of expected data already received by the scoreboard. Reset is asserted on a falling clock edge and held for three clocks; C, done and valid_in must be zero. The next identity operation and remaining regression results are compared against the golden model.

Driver returns item_done once after completion or abort; the test timeout wraps seq.start. Monitor collection tasks restart after reset. Scoreboard cancellation precedes FIFO flush, discarding the local expected handle as well as queued data. See [the evidence report](../reports/NPU_RESET_REPORT.md).

Limits: no repeated/random reset sweep, near-done race sweep, APB reset recovery, parameter sweep, reset functional cross, or end-to-end formal reset proof is claimed.

## 13. APB Wrapper Verification

The APB wrapper is verified as a separate layer. APB claims are not mixed into NPU core closure.

Latest APB verification result:

```text
APB transactions: 1251 / 1251 PASS
C matrix checks: 384 / 384 PASS
APB protocol SVA: PASS
APB error responses observed: 9
APB functional coverage: 100.00%
UVM_WARNING / UVM_ERROR / UVM_FATAL: 0 / 0 / 0
```

Current APB wrapper protocol scope:

- Unsupported read/write directions, invalid addresses, misaligned addresses, Matrix A/B writes while busy, and repeated start commands while busy are rejected and verified.
- The wrapper uses a zero-wait-state response.
- A two-write, no-wait `psel`-held back-to-back case is verified (one cover hit); wait states and broader direction/length combinations remain open.

## 14. Future Work

Planned verification improvements:

- Extend the passing directed reset recovery to repeated/randomized timings and parameter configurations.
- AXI-Lite wrapper and protocol verification.
- APB wait states and broader back-to-back direction/length combinations.
- Parameter-aware APB address-map generation and overlap checks for non-default `N`.
- RTL code coverage closure with committed coverage report.
- Extend formal verification beyond the existing PE/controller/SARR local proofs as required.
- CI/CD or automated regression publication.
