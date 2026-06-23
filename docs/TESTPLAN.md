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
| F8 | True reset during active compute | Not claimed; future reset-aware work |

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
| True reset during compute | No | No | No | No | No | Not claimed; future work |

## 4. Risk Analysis

| ID | Risk Description | Detection Method | Current Status |
|---|---|---|---|
| R1 | Accumulator is not cleared correctly. | Directed tests + SVA | Covered |
| R2 | MAC computation is incorrect. | Scoreboard | Covered |
| R3 | Valid propagation is misaligned. | Array SVA + scoreboard | Covered |
| R4 | Controller latency is incorrect. | Controller SVA + directed tests | Covered |
| R5 | Operand skew is mismatched. | Directed tests + scoreboard | Covered |
| R6 | Boundary signed values are not handled correctly. | Directed boundary tests + input coverage | Covered by tests; coverage value requires regenerated report |
| R7 | Sparse or signed matrix patterns are not covered. | Directed pattern tests + matrix coverage | Covered |
| R8 | Back-to-back transactions corrupt internal state. | Back-to-back random tests | Covered |
| R9 | Reset during active compute aborts transaction and breaks UVM pairing. | Requires reset-aware UVM flow | Not claimed; future work |

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

Input operands A and B are categorized into strengthened full signed INT8 boundary-aware value classes. The current input coverage value must come from the regenerated coverage report.

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

- Scoreboard reports 142 passing transactions.
- Scoreboard reports 0 failing transactions.
- UVM warning count is 0.
- UVM error count is 0.
- UVM fatal count is 0.
- Coverage report is generated and reviewed.
- Matrix pattern coverage is 100%.
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
| Boundary signed values | `MIN_MAX_TEST`, `FULL_INT8_BOUNDARY_TEST`, random tests | None | Input value coverage | PASS in current regression; coverage report must be regenerated |
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
| Input data coverage | Latest coverage report must be regenerated |

## 11. Known Coverage Gap

Input coverage may be below 100% because the coverage model was strengthened to track full signed INT8 boundary-aware bins. This is accepted for the current scope and tracked as future closure work.

The project intentionally does not chase unsupported or artificial bins only to report a 100% number.

## 12. Known Limitation: Reset During Compute

True reset-during-compute is not claimed as verified in the current clean regression.

The current UVM environment is transaction-based. The driver, input monitor, output monitor, and scoreboard are designed around normal transactions where a started operation eventually reaches `done` and produces one output transaction. A reset in the middle of computation aborts the active transaction and may legally produce no valid output. Handling that correctly requires reset-aware cancellation and synchronization across the driver, monitors, and scoreboard.

## 13. APB Wrapper Verification

The APB wrapper is verified as a separate layer. APB claims are not mixed into NPU core closure.

Latest APB verification result:

```text
APB transactions: 1245 / 1245 PASS
C matrix checks: 384 / 384 PASS
APB protocol SVA: PASS
APB functional coverage: 95.00%
UVM_WARNING / UVM_ERROR / UVM_FATAL: 0 / 0 / 0
```

Current APB wrapper limitations:

- Write-to-STATUS is not claimed as supported software flow.
- Write-to-C is not claimed as supported software flow.
- Active APB error response behavior is not claimed because `pslverr` is tied to 0.

## 14. Future Work

Planned verification improvements:

- Reset-aware UVM architecture for true reset-during-compute testing.
- Start-while-busy corner-case test.
- AXI-Lite wrapper and protocol verification.
- More advanced APB negative/error-response testing if active `pslverr` support is added.
- RTL code coverage closure with committed coverage report.
- Formal verification for selected PE/controller properties.
- CI/CD or automated regression publication.
