# NxN Systolic Array NPU Verification Test Plan

## 1. Scope

This document defines the verification strategy for the parameterizable NxN systolic-array-based NPU.

The objective is to verify functional correctness, timing behavior, control sequencing, operand propagation, and accumulator behavior across supported configurations.

Verification methods include:

- Directed testing
- Constrained-random testing
- Scoreboard checking
- SystemVerilog Assertions (SVA)
- Functional coverage

## 2. Features Under Verification

### F1. Processing Element (PE)

The PE shall:

- Clear accumulator correctly.
- Hold accumulator when `valid = 0`.
- Perform MAC operation when `valid = 1`.
- Reset accumulator on reset.

### F2. Systolic Array

The array shall:

- Propagate A operands horizontally.
- Propagate B operands vertically.
- Propagate valid wavefront correctly.
- Maintain operand alignment.

### F3. Controller FSM

The controller shall:

- Transition through all states correctly.
- Generate clear pulse correctly.
- Generate `valid_in` correctly.
- Assert `done` after computation completion.

### F4. End-to-End Matrix Multiplication

The NPU shall produce matrix multiplication results matching the golden model.

## 3. Verification Matrix

| Feature | Directed | Random | SVA | Coverage |
|---|---:|---:|---:|---:|
| PE Reset | Yes | No | Yes | No |
| PE Clear | Yes | No | Yes | No |
| PE Hold | Yes | No | Yes | No |
| PE MAC | Yes | Yes | Yes | No |
| A Propagation | Yes | Yes | Yes | Yes |
| B Propagation | Yes | Yes | Yes | Yes |
| Valid Wavefront | Yes | Yes | Yes | Yes |
| Controller FSM | Yes | Yes | Yes | Yes |
| Matrix Multiply | Yes | Yes | No | Yes |

## 4. Risk Analysis

| ID | Risk Description | Detection Method |
|---|---|---|
| R1 | Accumulator is not cleared correctly. | Directed test + SVA |
| R2 | MAC computation is incorrect. | Scoreboard |
| R3 | Valid propagation is misaligned. | Array SVA |
| R4 | Drain latency is incorrect. | Controller SVA |
| R5 | Operand skew is mismatched. | Directed test + SVA |
| R6 | Boundary INT8 values are not handled correctly. | Boundary coverage + directed MIN_MAX test |
| R7 | Sparse or signed matrix patterns are not covered. | Matrix pattern coverage + directed tests |

## 5. Directed and Random Tests

Current regression contains:

| Test Type | Count | Purpose |
|---|---:|---|
| Directed tests | 6 | Zero, identity, min/max boundary, all-positive, all-negative, sparse |
| Random tests | 100 | Constrained-random matrix multiplication scenarios |
| Total tests | 106 | Combined directed and random regression |

Directed test patterns:

- `ZERO_TEST`
- `IDENTITY_TEST`
- `MIN_MAX_TEST`
- `ALL_POSITIVE_TEST`
- `ALL_NEGATIVE_TEST`
- `SPARSE_TEST`

## 6. Functional Coverage Plan

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
| `sparse` | Most operands are zero with selected non-zero entries. |

### Output Coverage

Output matrix elements are categorized into magnitude-aware result classes:

| Bin | Description |
|---|---|
| `zero` | Output value is 0. |
| `small_positive` | Output value is in `[1:100]`. |
| `large_positive` | Output value is in `[101:32767]`. |
| `small_negative` | Output value is in `[-100:-1]`. |
| `large_negative` | Output value is in `[-32768:-101]`. |

## 7. Closure Criteria

Verification is considered complete when:

- All directed tests pass.
- Random regression passes.
- All assertions pass.
- Functional coverage reaches 100%.
- No UVM errors are reported.
- No UVM fatals are reported.

## 8. Verification Traceability Matrix

| Feature | Test | Assertion | Coverage | Status |
|---|---|---|---|---|
| PE Reset | Directed reset test | `p_pe_rstn` | — | PASS |
| PE Clear | Directed clear test | `p_pe_clear` | — | PASS |
| PE Hold | Directed hold test | `p_pe_stable` | — | PASS |
| PE MAC | Directed + random | `p_pe_math` | Input data coverage | PASS |
| A Propagation | Directed + random matrix tests | `p_a_delay` | Input coverage | PASS |
| B Propagation | Directed + random matrix tests | `p_b_delay` | Input coverage | PASS |
| Valid Wavefront | Directed + random | `p_valid_wavefront` | Matrix coverage | PASS |
| No-X Operation | Random matrix tests | `p_no_x_when_valid` | — | PASS |
| Controller FSM | Directed + random | `p_state_transition` | Matrix coverage | PASS |
| Done Pulse | Directed tests | `p_done_one_cycle` | — | PASS |
| Start-to-Done Latency | Directed tests | `p_start_to_done_latency` | — | PASS |
| Boundary INT8 Values | `MIN_MAX_TEST` | — | Input value cross coverage | PASS |
| Matrix Patterns | Directed pattern tests | — | Matrix pattern coverage | PASS |
| Output Result Ranges | Directed + random | — | Output data coverage | PASS |
| End-to-End Matrix Multiply | Directed + random | — | Scoreboard comparison | PASS |

## 9. Coverage Closure

The final coverage database is generated by merging:

1. UVM normal regression coverage
2. RTL reset-abort coverage

This allows the verification environment to cover both normal computation paths and reset recovery transitions.

| Coverage Type | Result |
|---|---:|
| Statement Coverage | 100% |
| Branch Coverage | 100% |
| Condition Coverage | 100% |
| Expression Coverage | 100% |
| FSM State Coverage | 100% |
| FSM Transition Coverage | 100% |
| Functional Coverage | 100% |

The controller FSM reached 100% state and transition coverage after adding directed reset-abort tests for CLEAR, COMPUTE, and WAIT_DRAIN states.
