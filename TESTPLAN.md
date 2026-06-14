# NxN Systolic Array NPU Verification Test Plan

## 1. Scope

This document defines the verification strategy for the parameterizable NxN systolic-array-based NPU.

The current verified configuration is:

```text
N     = 8
width = 8
```

The objective is to verify functional correctness, controller sequencing, operand propagation, valid wavefront behavior, accumulator behavior, and end-to-end signed matrix multiplication results.

Verification methods used:

- Directed testing
- Constrained-random testing
- Back-to-back transaction testing
- Scoreboard checking
- SystemVerilog Assertions (SVA)
- Functional coverage

## 2. Features Under Verification

### F1. Processing Element

The PE shall:

- Clear accumulator correctly.
- Hold accumulator when not computing.
- Perform signed MAC operation when valid.
- Reset accumulator on reset.

### F2. Systolic Array

The array shall:

- Propagate A operands horizontally.
- Propagate B operands vertically.
- Propagate valid wavefront correctly.
- Maintain operand alignment across the array.

### F3. Controller FSM

The controller shall:

- Transition through the expected states.
- Generate clear pulse correctly.
- Generate `valid_in` during input loading.
- Assert `done` after compute and drain latency.

### F4. End-to-End Matrix Multiplication

The NPU shall produce output matrix values matching the scoreboard golden model.

### F5. Back-to-Back Operation

The NPU shall process multiple matrix multiplication transactions with zero idle gap between transactions in the test flow.

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
| R6 | Boundary signed values are not handled correctly. | Directed boundary test + input coverage | Covered |
| R7 | Sparse or signed matrix patterns are not covered. | Directed pattern tests + matrix coverage | Covered |
| R8 | Back-to-back transactions corrupt internal state. | Back-to-back random tests | Covered |
| R9 | Reset during active compute aborts transaction and breaks UVM pairing. | Requires reset-aware UVM flow | Not claimed; future work |

## 5. Test Scenarios

Current clean regression contains:

| Test Type | Count | Purpose |
|---|---:|---|
| Directed tests | 6 | Cover known matrix patterns and boundary cases |
| Back-to-back random tests | 20 | Stress transaction-to-transaction continuity with zero idle gap |
| Random tests | 100 | Exercise constrained-random signed matrix multiplication |
| Total tests | 126 | Combined clean regression |

Directed test patterns:

- `ZERO_TEST`
- `IDENTITY_TEST`
- `MIN_MAX_TEST`
- `ALL_POSITIVE_TEST`
- `ALL_NEGATIVE_TEST`
- `SPARSE_TEST`

Back-to-back tests:

- Random matrix transactions executed with zero idle gap in the test flow.
- Used to check whether the DUT and UVM environment can process consecutive operations without corrupting scoreboard pairing.

## 6. Scoreboard Plan

The scoreboard compares actual DUT output against a software golden model.

Golden model behavior:

```text
C[i][j] = sum(A[i][k] * B[k][j]) for k = 0 to N-1
```

The expected result is calculated using a 64-bit signed temporary value, then cast to the DUT accumulator width before comparison. This models the fixed-width hardware accumulator behavior.

Scoreboard pass criteria:

- All output matrix elements must match the expected matrix.
- One matrix transaction is reported as PASS only when every element matches.

## 7. Functional Coverage Plan

### Input Coverage

Input operands A and B are categorized into boundary-aware value classes:

| Bin | Description |
|---|---|
| `zero` | Operand value is 0. |
| `min_negative` | Operand value is `-64`. |
| `max_positive` | Operand value is `63`. |
| `positive` | Operand value is in `[1:62]`. |
| `negative` | Operand value is in `[-63:-1]`. |
| `cross_a_b_value` | Cross coverage between A and B value classes. |

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

Output matrix elements are categorized into magnitude-aware result classes:

| Bin | Description |
|---|---|
| `zero` | Output value is 0. |
| `small_positive` | Output value is in `[1:100]`. |
| `large_positive` | Output value is greater than 100. |
| `small_negative` | Output value is in `[-100:-1]`. |
| `large_negative` | Output value is less than -100. |

## 8. Closure Criteria

Verification is considered clean for the current scope when:

- All 6 directed tests pass.
- All 20 back-to-back random tests pass.
- All 100 random tests pass.
- Scoreboard reports 126 passing transactions.
- Functional coverage reaches 100% for input, matrix pattern, scenario, and output coverage.
- No UVM warnings are reported.
- No UVM errors are reported.
- No UVM fatals are reported.

## 9. Verification Traceability Matrix

| Feature | Test | Assertion | Coverage | Current Status |
|---|---|---|---|---|
| PE reset/clear/hold/MAC behavior | Directed + random | PE SVA | Partial | PASS in current regression |
| A propagation | Directed + random | Array SVA | Input/matrix coverage | PASS in current regression |
| B propagation | Directed + random | Array SVA | Input/matrix coverage | PASS in current regression |
| Valid wavefront | Directed + random | Array SVA | Matrix/scenario coverage | PASS in current regression |
| Controller sequencing | Directed + random | Controller SVA | Scenario coverage | PASS in current regression |
| Boundary signed values | `MIN_MAX_TEST` | — | Input value coverage | PASS in current regression |
| Matrix patterns | Directed pattern tests | — | Matrix pattern coverage | PASS in current regression |
| Output result ranges | Directed + random | — | Output data coverage | PASS in current regression |
| Back-to-back transactions | Back-to-back random tests | — | Scenario coverage | PASS in current regression |
| End-to-end matrix multiply | Directed + random + back-to-back | — | Scoreboard comparison | PASS in current regression |

## 10. Latest Clean Regression Result

| Metric | Result |
|---|---:|
| Total tests | 126 |
| Directed tests | 6 |
| Back-to-back random tests | 20 |
| Random tests | 100 |
| Scoreboard pass count | 126 |
| UVM warnings | 0 |
| UVM errors | 0 |
| UVM fatals | 0 |

| Functional Coverage Type | Result |
|---|---:|
| Input data coverage | 100% |
| Matrix pattern coverage | 100% |
| Scenario coverage | 100% |
| Output data coverage | 100% |

## 11. Known Limitation: Reset During Compute

True reset-during-compute is not claimed as verified in the current clean regression.

Reason:

The current UVM environment is transaction-based. The driver, input monitor, output monitor, and scoreboard are designed around normal transactions where a started operation eventually reaches `done` and produces one output transaction. A reset in the middle of computation aborts the active transaction and may legally produce no valid output. Handling that correctly requires reset-aware cancellation and synchronization across the driver, monitors, and scoreboard.

Current decision:

- Do not claim reset-during-compute support.
- Keep the clean regression stable.
- List reset-aware UVM support as future work.

## 12. Future Work

Planned verification improvements:

- Reset-aware UVM architecture for true reset-during-compute testing.
- Start-while-busy corner-case test.
- APB or AXI-Lite wrapper and protocol verification.
- Protocol-level assertions.
- RTL code coverage closure with committed coverage report.
- Formal verification for selected PE/controller properties.
- Regression automation and report generation.
