# NPU Unit Test Plan

Version: 0.7
Status: Draft; PE primary configuration executed, controller and Systolic Array standalone tests implemented but not recorded as executed

---

# 1. Scope and Current Status

This document defines standalone simulation tests for the Processing Element
(PE), Systolic Array Controller, and Systolic Array specified in
`NPU_SPEC.md`.

The current repository contains a directed PE testbench at
`tb/tb_pe_directed.sv`. The committed closure report records 39 checks passed
and 0 failed for `width=8`, `N=8`, and `ACC_WIDTH=19`. Committed formal
artifacts also report `PASS` for the PE reset, clear, MAC, and hold tasks.
These results do not cover every test case or parameter configuration listed
below.

The repository contains the standalone controller testbench
`tb/tb_controller_directed.sv` at `N=4`, `DRAIN_MARGIN=3`. It implements reset,
start/busy handling, exact phase-duration, output-decode, and restart checks.
No saved simulator result for this testbench is claimed by this revision.
The controller formal harness in `formal/controller/controller_formal.sv` is
configured at `N=8`, `DRAIN_MARGIN=10`; all five prove tasks and the cover task
have committed `PASS` status artifacts.

The implementation labels used below mean:

- **Implemented**: matching directed stimulus and a result check exist in a
  standalone testbench; this does not imply a saved passing run.
- **Partial**: only part of the listed stimulus is implemented, or the behavior
  is checked only by an assertion, formal task, or indirect integration test.
- **Planned**: no matching standalone executable test was found.

Unless a test states otherwise, stimulus uses legal parameter values, drives
inputs before a rising edge of `clk`, and compares the observed result with a
fixed-width signed reference value after the state update.

---

# 2. PE Reset Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `PE_RST_TC_001` | `PE_RST_001` | Assert `rst_n=0` without waiting for a clock edge | `acc` becomes zero asynchronously | Implemented by `test_async_reset_between_edges` |
| `PE_RST_TC_002` | `PE_RST_002` | First create a nonzero accumulator, then assert `rst_n=0` between clock edges | `acc` becomes zero before the next rising edge | Implemented by `test_async_reset_between_edges` |
| `PE_RST_TC_003` | `PE_RST_003` | Hold `rst_n=0` for multiple clock cycles while changing other inputs | `acc` remains zero | Partial: clock-sampled assertion/formal evidence exists; the full directed stimulus is not implemented |
| `PE_RST_TC_004` | `PE_RST_004` | Assert reset while `clear=1` and `valid=1` with nonzero operands | Reset dominates and `acc` remains zero | Implemented by `test_reset_priority` |

---

# 3. PE Clear Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `PE_CLR_TC_001` | `PE_CLR_001` | Pulse `clear` across one rising edge after creating a nonzero accumulator | `acc` changes to zero on that rising edge | Implemented by `test_clear_priority` |
| `PE_CLR_TC_002` | `PE_CLR_002` | Perform one or more MAC operations, then assert `clear` | `acc` becomes zero | Implemented by `test_clear_priority` |
| `PE_CLR_TC_003` | `PE_CLR_003` | Hold `clear=1` for multiple rising edges and vary `valid`, `a_in`, and `b_in` | `acc` is zero after every affected edge | Partial: assertion/formal evidence exists; the multi-cycle directed stimulus is not implemented |
| `PE_CLR_TC_004` | `PE_CLR_004` | Drive `clear=1`, `valid=1`, and nonzero operands at the same rising edge | Clear wins and no product is accumulated | Implemented by `test_clear_priority` |

---

# 4. PE MAC Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `PE_MAC_TC_001` | `PE_MAC_001` | Set `valid=1`, `clear=0`, and use simple nonzero operands | Exactly one product is accumulated per enabled rising edge | Implemented by several directed tasks |
| `PE_MAC_TC_002` | `PE_MAC_002` | Exercise positive-positive, negative-positive, positive-negative, and negative-negative operand pairs | Product signs and accumulated values match signed arithmetic | Implemented by `test_signed_comb` |
| `PE_MAC_TC_003` | `PE_MAC_003` | Exercise operand extrema, including the most-negative value | Reference calculation retains the full `2*width` product | Partial: `test_most_neg` checks the most-negative operand multiplied by `-1`, but not all extrema |
| `PE_MAC_TC_004` | `PE_MAC_004` | Accumulate negative products into zero and nonzero accumulator values | Negative product is sign-extended to `ACC_WIDTH` before addition | Implemented by `test_hold_after_mac` and `test_signed_comb` |
| `PE_MAC_TC_005` | `PE_MAC_005` | Apply several consecutive valid cycles with varying operands | Every result follows the recurrence equation in the specification | Implemented by `test_signed_comb`; the MAC assertion/formal task provides additional evidence |
| `PE_MAC_TC_006` | `PE_MAC_006` | Drive products that cross both positive and negative accumulator limits | Results wrap to the corresponding `ACC_WIDTH` two's-complement values | Partial: `test_wrap` crosses the positive limit; a negative-limit directed case is not implemented |

---

# 5. PE Hold Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `PE_HOLD_TC_001` | `PE_HOLD_001` | After reset release, drive `valid=0`, `clear=0` | `acc` retains zero | Partial: covered by the hold assertion/formal task; no dedicated directed check |
| `PE_HOLD_TC_002` | `PE_HOLD_001` | Create a nonzero accumulator, then drive an idle cycle | `acc` retains its previous value | Implemented by `test_hold_after_mac` |
| `PE_HOLD_TC_003` | `PE_HOLD_001` | Hold `valid=0`, `clear=0` for multiple cycles while changing operands | `acc` remains unchanged | Partial: general hold assertion/formal evidence exists; the full directed stimulus is not implemented |
| `PE_HOLD_TC_004` | `PE_HOLD_001` | Clear the accumulator, then drive idle cycles | `acc` remains zero | Planned |

---

# 6. PE Output Test

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `PE_OUT_TC_001` | `PE_OUT_001` | Observe `acc` through reset, clear, MAC, and hold operations | `acc` matches the PE accumulator state | Partial: exercised by directed result checks and supported by the RTL continuous assignment; no separate output test |

---

# 7. PE Parameter Tests

No standalone PE parameter test below is implemented in the current
regression. The reported PE results apply only to `width=8`, `N=8`, and
`ACC_WIDTH=19`.

| Test ID | Stimulus/configuration | Expected result | Current implementation |
| --- | --- | --- | --- |
| `PE_PARAM_TC_001` | `N=1` with default `ACC_WIDTH` | Default accumulator width follows the RTL special-case formula | Planned |
| `PE_PARAM_TC_002` | At least one legal `width` other than 8 | Signed MAC behavior remains correct | Planned |
| `PE_PARAM_TC_003` | At least one legal `N` other than 8 | Default accumulator width and arithmetic remain correct | Planned |
| `PE_PARAM_TC_004` | Legal explicit `ACC_WIDTH` override | Product extension and accumulator wrap follow the configured width | Planned |

---

# 8. Controller Reset Tests

Controller tests in Sections 8 through 14 are implemented by
`tb/tb_controller_directed.sv` unless a row states otherwise. Formal `PASS`
artifacts provide independent clock-sampled evidence at `N=8`, but do not
replace the directed asynchronous-reset test or parameter regression.

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `CTRL_RST_TC_001` | `CTRL_RST_001` | Assert `rst_n=0` between clock edges while the controller is in `COMPUTE` | The state and decoded outputs change to reset values without waiting for a rising edge | Implemented by `test_async_reset_between_edges` |
| `CTRL_RST_TC_002` | `CTRL_RST_002` | Assert `rst_n=0` during `CLEAR`, `COMPUTE`, `WAIT_DRAIN`, and `DONE` | Controller returns to `IDLE` in every phase | Implemented by `test_reset_in_state` |
| `CTRL_RST_TC_003` | `CTRL_RST_003` | Hold `rst_n=0` for multiple cycles while varying `start` | `clear`, `valid_in`, and `done` remain zero | Partial: held reset/start is checked; varying `start` throughout reset is not |
| `CTRL_RST_TC_004` | `CTRL_RST_004` | Assert `rst_n=0` while `start=1` or while an operation is active | Reset dominates all controller behavior and no request is accepted during reset | Implemented by `test_reset_priority_with_start` |

---

# 9. Controller Start Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `CTRL_START_TC_001` | `CTRL_START_001` | Assert `start=1` in `IDLE` and separately while busy | Start is accepted only in `IDLE` | Implemented by `test_start_at_idle` and `test_busy_start_ignored` |
| `CTRL_START_TC_002` | `CTRL_START_002`, `CTRL_CLR_001` | Assert `start=1` at a rising edge in `IDLE` | Controller enters `CLEAR` after the accepting edge | Implemented by `accept_start`; formal task `start` is `PASS` |
| `CTRL_START_TC_003` | `CTRL_START_003` | Pulse `start` during `CLEAR`, `COMPUTE`, `WAIT_DRAIN`, and `DONE` | The active operation is not altered | Implemented by `test_busy_start_ignored`; formal task `start_busy` is `PASS` |
| `CTRL_START_TC_004` | `CTRL_START_004` | Pulse `start` while busy and deassert it before return to `IDLE` | No pending request is stored | Implemented by `test_busy_pulse_not_queued` |
| `CTRL_START_TC_005` | `CTRL_START_004` | Hold `start=1` until the controller returns to `IDLE` | A new operation is accepted on the next `IDLE` sampling edge | Implemented by `test_held_start_reaccepted` |

`CTRL_START_TC_004` and `CTRL_START_TC_005` intentionally map to the same
requirement. They distinguish two consequences of the level-sensitive
interface: a pulse that ends while the controller is busy is not retained,
whereas a level that is still high when `IDLE` is sampled is accepted as a new
request. There is no `CTRL_START_005` requirement.

---

# 10. Controller Clear Phase Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `CTRL_CLR_TC_001` | `CTRL_CLR_001` | Issue a legal start request from `IDLE` | Controller enters `CLEAR` | Implemented by `accept_start` |
| `CTRL_CLR_TC_002` | `CTRL_CLR_002` | Observe outputs during `CLEAR` | `clear=1`, `valid_in=0`, and `done=0` | Implemented by `accept_start`; formal task `output` is `PASS` |
| `CTRL_CLR_TC_003` | `CTRL_CLR_003` | Measure consecutive cycles in `CLEAR` | `CLEAR` lasts exactly one cycle | Implemented by `test_exact_phase_durations` |
| `CTRL_CLR_TC_004` | `CTRL_CLR_004` | Observe the state after `CLEAR` | Next phase is `COMPUTE` | Implemented by `test_exact_phase_durations`; formal task `phase` is `PASS` |

---

# 11. Controller Compute Phase Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `CTRL_COMP_TC_001` | `CTRL_COMP_001` | Observe outputs during `COMPUTE` | `clear=0`, `valid_in=1`, and `done=0` | Implemented by `test_exact_phase_durations`; formal task `output` is `PASS` |
| `CTRL_COMP_TC_002` | `CTRL_COMP_002` | Count consecutive cycles in `COMPUTE` | `COMPUTE` lasts exactly `N` cycles | Implemented by `test_exact_phase_durations`; formal task `phase` is `PASS` |
| `CTRL_COMP_TC_003` | `CTRL_COMP_003` | Observe the state after the final compute cycle | Next phase is `WAIT_DRAIN` | Implemented by `test_exact_phase_durations`; formal task `phase` is `PASS` |

---

# 12. Controller Wait-Drain Phase Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `CTRL_DRAIN_TC_001` | `CTRL_DRAIN_001` | Observe outputs during `WAIT_DRAIN` | `clear=0`, `valid_in=0`, and `done=0` | Implemented by `test_exact_phase_durations`; formal task `output` is `PASS` |
| `CTRL_DRAIN_TC_002` | `CTRL_DRAIN_002` | Count consecutive cycles in `WAIT_DRAIN` | `WAIT_DRAIN` lasts exactly `2*N + DRAIN_MARGIN` cycles | Implemented by `test_exact_phase_durations`; formal task `phase` is `PASS` |
| `CTRL_DRAIN_TC_003` | `CTRL_DRAIN_003` | Observe the state after the final drain cycle | Next phase is `DONE` | Implemented by `test_exact_phase_durations`; exact exit is proven by task `phase` |

---

# 13. Controller Done Phase Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `CTRL_DONE_TC_001` | `CTRL_DONE_001` | Observe outputs during `DONE` | `clear=0`, `valid_in=0`, and `done=1` | Implemented by `test_exact_phase_durations`; formal task `output` is `PASS` |
| `CTRL_DONE_TC_002` | `CTRL_DONE_002` | Measure consecutive cycles in `DONE` | `DONE` lasts exactly one cycle | Implemented by `test_exact_phase_durations` |
| `CTRL_DONE_TC_003` | `CTRL_DONE_003` | Observe the state after `DONE` | Next phase is `IDLE` | Implemented by `test_exact_phase_durations`; formal task `phase` is `PASS` |

---

# 14. Controller Idle Phase Tests

| Test ID | Requirement | Stimulus | Expected result | Current implementation |
| --- | --- | --- | --- | --- |
| `CTRL_IDLE_TC_001` | `CTRL_IDLE_001` | Observe outputs while in `IDLE` | `clear=0`, `valid_in=0`, and `done=0` | Implemented by `apply_reset`; formal task `output` is `PASS` |
| `CTRL_IDLE_TC_002` | `CTRL_IDLE_002` | Keep `start=0` while in `IDLE` | Controller remains in `IDLE` | Implemented throughout reset/release helpers; formal task `start` is `PASS` |

---

# 15. Controller Parameter Tests

| Test ID | Stimulus/configuration | Expected result | Current implementation |
| --- | --- | --- | --- |
| `CTRL_PARAM_TC_001` | `N=2` | `COMPUTE` lasts 2 cycles and `WAIT_DRAIN` lasts `2*N + DRAIN_MARGIN` cycles | Planned |
| `CTRL_PARAM_TC_002` | `N=4` | `COMPUTE` lasts 4 cycles and `WAIT_DRAIN` lasts `2*N + DRAIN_MARGIN` cycles | Implemented by the directed testbench |
| `CTRL_PARAM_TC_003` | `N=8` | Phase durations follow the configured formulas | Formal tasks are implemented and have `PASS` artifacts; standalone simulation remains planned |
| `CTRL_PARAM_TC_004` | A legal `DRAIN_MARGIN` value other than 10 | `WAIT_DRAIN` duration follows the configured value | Implemented at `DRAIN_MARGIN=3` by the directed testbench |

---
# 16. Systolic Array Reset Tests

| Test ID           | Requirement                                                    | Stimulus                                                                                                                                            | Expected result                                                                                                               | Current implementation |
| ----------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_RST_TC_001` | `SARR_RST_001`, `SARR_RST_002`, `SARR_RST_003`, `SARR_RST_004` | First create nonzero operand-pipeline, local-valid, accumulator, and output state. Assert `rst_n=0` between rising edges while the array is active. | All A/B pipeline state, local-valid state, PE accumulators, and outputs become zero without waiting for the next rising edge. | Implemented; execution result not recorded |
| `SARR_RST_TC_002` | `SARR_RST_005`                                                 | Hold `rst_n=0` for multiple cycles while changing `clear`, `valid_in`, `a_in`, and `b_in`.                                                          | All operand pipelines, local-valid state, accumulators, and outputs remain zero while reset is asserted.                      | Implemented; execution result not recorded |
| `SARR_RST_TC_003` | `SARR_RST_006`                                                 | Assert `rst_n=0` while `clear=1`, `valid_in=1`, nonzero operands are present, and one or more PEs contain partial accumulated results.              | Reset dominates clear, propagation, and MAC behavior. The complete array remains in the reset state.                          | Implemented; execution result not recorded |
| `SARR_RST_TC_004` | `SARR_RST_002` to `SARR_RST_006`                               | Assert reset at several operation points: before valid entry, during early propagation, during middle-array MAC activity, and during drain.         | Reset clears all in-flight state and aborts the current operation regardless of the wavefront position.                       | Partial: active-state reset is implemented; all listed operation points are not targeted separately |

---

# 17. Systolic Array Clear Tests

| Test ID           | Requirement                                                    | Stimulus                                                                                                                | Expected result                                                                                                  | Current implementation |
| ----------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_CLR_TC_001` | `SARR_CLR_001`, `SARR_CLR_002`, `SARR_CLR_003`, `SARR_CLR_004` | Create nonzero pipeline, valid, accumulator, and output state. Assert `clear=1` before one rising edge while `rst_n=1`. | All A/B pipeline state, local-valid state, PE accumulators, and outputs become zero on the affected rising edge. | Implemented; execution result not recorded |
| `SARR_CLR_TC_002` | `SARR_CLR_005`                                                 | Hold `clear=1` across multiple rising edges while varying `valid_in`, `a_in`, and `b_in`.                               | All cleared state remains zero after every rising edge for which `clear=1`.                                      | Implemented; execution result not recorded |
| `SARR_CLR_TC_003` | `SARR_CLR_006`                                                 | Assert `clear=1` while `valid_in=1` and active MAC or operand propagation is present.                                   | Clear prevents propagation and MAC updates on the affected edge and has priority over normal array behavior.     | Implemented; execution result not recorded |
| `SARR_CLR_TC_004` | `SARR_CLR_001` to `SARR_CLR_006`                               | Assert clear during early propagation, middle-array MAC activity, and drain.                                            | All in-flight state and partial results are synchronously removed at the next rising edge.                       | Planned                |

---

# 18. Systolic Array Operand Propagation Tests

| Test ID          | Requirement                | Stimulus                                                                                                   | Expected result                                                                                         | Current implementation |
| ---------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_A_TC_001`  | `SARR_A_001`, `SARR_A_002` | Drive unique tagged A values on every row while keeping B and valid inactive. Observe entry into column 0. | `a_in[i]` reaches `PE[i][0]` after exactly `i+1` rising edges.                                          | Planned                |
| `SARR_A_TC_002`  | `SARR_A_003`               | Drive a unique A tag into a selected row and observe consecutive PE columns.                               | The A value propagates exactly one column to the right per rising edge.                                 | Planned                |
| `SARR_A_TC_003`  | `SARR_A_004`               | Drive changing A values while local valid is low.                                                          | A skew and propagation continue independently of local valid until reset or clear flushes the pipeline. | Planned                |
| `SARR_B_TC_001`  | `SARR_B_001`, `SARR_B_002` | Drive unique tagged B values on every column while keeping A and valid inactive. Observe entry into row 0. | `b_in[j]` reaches `PE[0][j]` after exactly `j+1` rising edges.                                          | Planned                |
| `SARR_B_TC_002`  | `SARR_B_003`               | Drive a unique B tag into a selected column and observe consecutive PE rows.                               | The B value propagates exactly one row downward per rising edge.                                        | Planned                |
| `SARR_B_TC_003`  | `SARR_B_004`               | Drive changing B values while local valid is low.                                                          | B skew and propagation continue independently of local valid until reset or clear flushes the pipeline. | Planned                |
| `SARR_AB_TC_001` | `SARR_A_*`, `SARR_B_*`     | Simultaneously drive distinct tagged values across all A rows and B columns.                               | No A value crosses into another row and no B value crosses into another column.                         | Planned                |

---

# 19. Systolic Array Valid Propagation Tests

| Test ID           | Requirement                    | Stimulus                                                                                                    | Expected result                                                                                                                                  | Current implementation |
| ----------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------- |
| `SARR_VAL_TC_001` | `SARR_VAL_001`, `SARR_VAL_004` | Pulse `valid_in=1` for one cycle after clear and observe representative PE positions.                       | The valid pulse reaches `PE[i][j]` after exactly `i+j+1` rising edges.                                                                           | Planned                |
| `SARR_VAL_TC_002` | `SARR_VAL_002`, `SARR_VAL_003` | Drive a one-cycle valid pulse and observe propagation through column 0 and then across each row.            | Local valid propagates one hop per rising edge along the specified route.                                                                        | Planned                |
| `SARR_VAL_TC_003` | `SARR_VAL_005`                 | Hold `valid_in=1` for exactly `M` consecutive cycles, where `M` includes `1`, `N`, and another legal value. | Every PE receives a contiguous local-valid pulse of width `M`, delayed by its positional latency.                                                | Partial: bursts of 1, N, and N+1 are driven, but internal pulse width is only checked after drain |
| `SARR_VAL_TC_004` | `SARR_VAL_006`                 | Assert reset and separately assert clear while valid state is present inside the array.                     | Reset asynchronously clears all local-valid state. Clear synchronously clears all local-valid state and blocks propagation on the affected edge. | Planned                |
| `SARR_VAL_TC_005` | `SARR_VAL_*`                   | Deassert `valid_in` after a legal `N`-cycle stream and continue clocking without clear.                     | In-flight local-valid state continues propagating and eventually deasserts at every PE without duplication or extension.                         | Implemented for eventual drain; exact no-duplication/no-extension timing remains unchecked |

---

# 20. Systolic Array Operand-Valid Alignment Tests

| Test ID             | Requirement                                          | Stimulus                                                                                                                              | Expected result                                                                                                                        | Current implementation |
| ------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_ALIGN_TC_001` | `SARR_ALIGN_001`, `SARR_ALIGN_002`, `SARR_ALIGN_003` | Drive uniquely tagged A and B samples on every valid input cycle. Observe local A, local B, and local valid at selected PE positions. | Whenever local valid is high at `PE[i][j]`, local A and B correspond to the same original input sample cycle delayed by `i+j+1` edges. | Planned                |
| `SARR_ALIGN_TC_002` | `SARR_ALIGN_001` to `SARR_ALIGN_003`                 | Use distinct sample indices for all `k` values in one legal operation.                                                                | Each PE receives the operand pairs in the expected `k=0` through `N-1` order without duplication, omission, or reordering.             | Planned                |
| `SARR_ALIGN_TC_003` | `SARR_ALIGN_004`                                     | Propagate nonzero operands through selected PEs while local valid is low.                                                             | PE accumulators do not update even though operand values continue moving through the array.                                            | Planned                |
| `SARR_ALIGN_TC_004` | `SARR_ALIGN_*`                                       | Use row-unique A tags and column-unique B tags across the entire array.                                                               | No PE combines an A sample from the wrong row, a B sample from the wrong column, or operands from different input cycles.              | Planned                |

---

# 21. Systolic Array MAC and Matrix Computation Tests

| Test ID           | Requirement                    | Stimulus                                                                                                        | Expected result                                                                                       | Current implementation |
| ----------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_MAC_TC_001` | `SARR_MAC_001`                 | Clear the array, then apply one valid cycle with simple nonzero operands.                                       | Every PE whose local valid is asserted performs exactly one signed MAC update on that edge.           | Planned                |
| `SARR_MAC_TC_002` | `SARR_MAC_002`                 | Apply exactly `N` consecutive valid input cycles for one legal matrix operation.                                | Every PE receives exactly `N` consecutive local-valid cycles and performs exactly `N` MAC operations. | Partial: N-cycle matrix streams and final results are checked; per-PE MAC counts are not observed |
| `SARR_MAC_TC_003` | `SARR_MAC_003`                 | Use a small deterministic matrix with known products and observe selected PE accumulators after each valid MAC. | After the `m`-th MAC, the accumulator equals the fixed-width sum of the first `m` valid products.     | Planned                |
| `SARR_MAC_TC_004` | `SARR_MAC_004`                 | Multiply two simple known matrices, such as identity, zero, diagonal, or small signed matrices.                 | Every `c[i][j]` matches the independent reference-model result after completion.                      | Implemented for identity and deterministic signed matrices; execution result not recorded |
| `SARR_MAC_TC_005` | `SARR_MAC_004`                 | Run constrained-random signed matrices across multiple seeds.                                                   | The complete output matrix matches the independent fixed-width reference model for every operation.   | Planned                |
| `SARR_MAC_TC_006` | `SARR_MAC_004`                 | Exercise positive, negative, zero, minimum, and maximum operand values.                                         | Signed multiplication, accumulation, and result signs match the specified arithmetic.                 | Partial: positive, negative, and zero values are implemented; minimum/maximum values are not targeted |
| `SARR_MAC_TC_007` | `SARR_MAC_003`, `SARR_MAC_004` | Drive values that cross the positive accumulator limit and separately the negative accumulator limit.           | Accumulators and outputs wrap according to signed `ACC_WIDTH` two's-complement arithmetic.            | Planned                |
| `SARR_MAC_TC_008` | `SARR_MAC_005`                 | Create a nonzero result, then keep local valid inactive while changing operands for multiple cycles.            | Every affected accumulator and output retains its previous value.                                     | Implemented; execution result not recorded |

---

# 22. Systolic Array Drain and Output Tests

| Test ID            | Requirement     | Stimulus                                                                                          | Expected result                                                                                    | Current implementation |
| ------------------ | --------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_TIME_TC_001` | `SARR_TIME_001` | Apply a legal operation and monitor valid MAC counts across representative PE positions.          | `PE[0][0]` is the first PE to complete its `N` valid MAC operations.                               | Planned                |
| `SARR_TIME_TC_002` | `SARR_TIME_002` | Apply a legal operation and monitor the final PE.                                                 | `PE[N-1][N-1]` is the last PE to complete its `N` valid MAC operations.                            | Planned                |
| `SARR_TIME_TC_003` | `SARR_TIME_003` | Deassert `valid_in` after the final input sample while operands and valid state remain in flight. | In-flight operands and valid continue propagating until all pending MAC operations complete.       | Planned                |
| `SARR_TIME_TC_004` | `SARR_TIME_004` | Compare the complete matrix before and after the last PE finishes.                                | The complete matrix is accepted as final only after `PE[N-1][N-1]` completes its `N`-th valid MAC. | Planned                |
| `SARR_OUT_TC_001`  | `SARR_OUT_001`  | Observe `c[i][j]` during reset, clear, MAC, and hold behavior.                                    | Each `c[i][j]` continuously reflects the corresponding PE accumulator.                             | Partial: output behavior is checked in those phases, but direct internal accumulator aliasing is structural |
| `SARR_OUT_TC_002`  | `SARR_OUT_002`  | Create nonzero outputs, then drive cycles with local valid low and reset/clear inactive.          | Outputs remain stable.                                                                             | Implemented; execution result not recorded |
| `SARR_OUT_TC_003`  | `SARR_OUT_003`  | Complete an operation and continue clocking without reset, clear, or new valid MAC activity.      | The full output matrix remains stable after completion.                                            | Implemented; execution result not recorded |

---

# 23. Systolic Array Operation Isolation Tests

| Test ID          | Requirement   | Stimulus                                                                                          | Expected result                                                                                          | Current implementation |
| ---------------- | ------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_OP_TC_001` | `SARR_OP_001` | Complete one operation, assert clear for at least one rising edge, then start a second operation. | The second operation begins with zero operand-pipeline, local-valid, and accumulator state.              | Implemented; execution result not recorded |
| `SARR_OP_TC_002` | `SARR_OP_002` | Run two distinct matrices back to back using the specified clear protocol.                        | No operand, valid, partial sum, or output from the first operation contributes to the second result.     | Implemented for identity followed by signed matrix; execution result not recorded |
| `SARR_OP_TC_003` | `SARR_OP_003` | After clear, observe the first valid MAC at selected PE positions.                                | The first valid MAC begins from an accumulator value of zero.                                            | Planned                |
| `SARR_OP_TC_004` | `SARR_OP_*`   | Run repeated back-to-back operations with different matrix patterns and signs.                    | Every operation is independently matched with its own expected scoreboard transaction and result matrix. | Planned                |

---

# 24. Systolic Array Parameter Tests

| Test ID             | Stimulus/configuration                           | Expected result                                                                                                                             | Current implementation |
| ------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_PARAM_TC_001` | `N=1`, `width=8`                                 | A single PE performs one valid MAC, positional latency follows the `i+j+1` rule, and the default accumulator-width special case is correct. | Planned                |
| `SARR_PARAM_TC_002` | `N=2`, `width=8`                                 | Propagation, alignment, MAC count, drain, and final matrix result are correct for a small array.                                            | Planned                |
| `SARR_PARAM_TC_003` | `N=4`, `width=8`                                 | All applicable directed and constrained-random checks pass.                                                                                 | Planned                |
| `SARR_PARAM_TC_004` | `N=8`, `width=8`                                 | All applicable directed and constrained-random checks pass for the primary configuration.                                                   | Partial: directed testbench is parameterized at this configuration; constrained-random testing and a recorded run remain planned |
| `SARR_PARAM_TC_005` | At least one legal operand width other than 8    | Signed propagation, multiplication, accumulation, and scoreboard arithmetic follow the configured width.                                    | Planned                |
| `SARR_PARAM_TC_006` | Legal explicit `ACC_WIDTH` override              | Accumulation and wraparound follow the configured accumulator width.                                                                        | Planned                |
| `SARR_PARAM_TC_007` | Multiple random seeds per selected configuration | No seed-dependent assertion failure, timeout, or scoreboard mismatch occurs.                                                                | Planned                |

# 25. Regression Entry Criteria

Before running a standalone unit regression:

- The selected RTL and testbench compile successfully.
- Clock and reset generation are available.
- Reference models and result checkers required by the selected tests are
  enabled.
- The parameter configuration is legal.
- Assertions used as supporting evidence are compiled and enabled.

---

# 26. Exit Criteria

A unit scope is complete only when:

- Every in-scope test has an executable implementation and passes.
- No unexpected assertion failure, simulation error, or fatal error occurs.
- Required functional coverage is collected and reviewed; missing coverage is
  documented rather than inferred from test names.
- Excluded tests, uncovered bins, parameter limitations, and known defects are
  recorded.
- No unresolved defect remains within the agreed scope.

The current PE evidence supports the primary configuration described in
Section 1. Controller directed checks are implemented but do not have a saved
passing simulation result in this revision; parameter and functional-coverage
gaps remain open, so the standalone controller scope is not complete.

---

# 27. Revision History

| Version | Date | Summary |
| --- | --- | --- |
| 0.2 | Not recorded | Initial standalone PE test list |
| 0.3 | 2026-07-13 | Added formatted controller tests and aligned implementation claims with repository evidence |
| 0.4 | 2026-07-15 | Aligned controller tests with the directed testbench and formal PASS artifacts |
| 0.5 | 2026-07-18 | Added Systolic Array unit-level test cases and traceability. |
| 0.6 | 2026-07-20 | Editorial normalization and version alignment; no test intent or expected result changed. |
| 0.7 | 2026-08-08 | Reviewed the SARR directed implementation, corrected stale scope/status text, and recorded implementation gaps without claiming an unexecuted simulation pass. |
