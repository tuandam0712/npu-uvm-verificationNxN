# Processing Element Test Plan

Version: 0.2  
Status: Draft / Planned

---

# 1. Scope and Test Model

This document defines planned standalone simulation tests for the PE specified
in `NPU_SPEC.md`. A listed test is not considered implemented or passed until a
corresponding executable test and result are available.

Unless a test states otherwise, stimulus shall use legal parameter values,
release `rst_n`, drive inputs before a rising edge of `clk`, and compare `acc`
against a fixed-width signed reference accumulator after the state update.

---

# 2. Reset Tests

| Test ID | Requirement | Stimulus | Expected result |
| --- | --- | --- | --- |
| `PE_RST_TC_001` | `PE_RST_001` | Assert `rst_n=0` without waiting for a clock edge | `acc` becomes zero asynchronously |
| `PE_RST_TC_002` | `PE_RST_002` | First create a nonzero accumulator, then assert `rst_n=0` between clock edges | `acc` becomes zero before the next rising edge |
| `PE_RST_TC_003` | `PE_RST_003` | Hold `rst_n=0` for multiple clock cycles while changing other inputs | `acc` remains zero |
| `PE_RST_TC_004` | `PE_RST_004` | Assert reset while `clear=1` and `valid=1` with nonzero operands | Reset dominates and `acc` remains zero |

---

# 3. Clear Tests

| Test ID | Requirement | Stimulus | Expected result |
| --- | --- | --- | --- |
| `PE_CLR_TC_001` | `PE_CLR_001` | Pulse `clear` across one rising edge after creating a nonzero accumulator | `acc` changes to zero on that rising edge |
| `PE_CLR_TC_002` | `PE_CLR_002` | Perform one or more MAC operations, then assert `clear` | `acc` becomes zero |
| `PE_CLR_TC_003` | `PE_CLR_003` | Hold `clear=1` for multiple rising edges and vary `valid/a_in/b_in` | `acc` is zero after every affected edge |
| `PE_CLR_TC_004` | `PE_CLR_004` | Drive `clear=1`, `valid=1`, and nonzero operands at the same rising edge | Clear wins and no product is accumulated |

---

# 4. MAC Tests

| Test ID | Requirement | Stimulus | Expected result |
| --- | --- | --- | --- |
| `PE_MAC_TC_001` | `PE_MAC_001` | Set `valid=1`, `clear=0`, and use simple nonzero operands | Exactly one product is accumulated per enabled rising edge |
| `PE_MAC_TC_002` | `PE_MAC_002` | Exercise positive×positive, negative×positive, positive×negative, and negative×negative | Product signs and accumulated values match signed arithmetic |
| `PE_MAC_TC_003` | `PE_MAC_003` | Use operand extrema, including the most-negative value | Reference calculation retains the complete `2*width` product |
| `PE_MAC_TC_004` | `PE_MAC_004` | Accumulate negative products into zero and nonzero accumulator values | Negative product is sign-extended to `ACC_WIDTH` before addition |
| `PE_MAC_TC_005` | `PE_MAC_005` | Apply several consecutive valid cycles with varying operands | Every result follows the recurrence equation in the specification |
| `PE_MAC_TC_006` | `PE_MAC_006` | Drive enough positive and negative products to cross both accumulator limits | Result wraps to the corresponding `ACC_WIDTH` two's-complement value |

---

# 5. Hold Tests

| Test ID | Requirement | Stimulus | Expected result |
| --- | --- | --- | --- |
| `PE_HOLD_TC_001` | `PE_HOLD_001` | After reset release, drive `valid=0`, `clear=0` | `acc` retains zero |
| `PE_HOLD_TC_002` | `PE_HOLD_001` | Create a nonzero accumulator, then drive an idle cycle | `acc` retains its previous value |
| `PE_HOLD_TC_003` | `PE_HOLD_001` | Hold `valid=0`, `clear=0` for multiple cycles while changing operands | `acc` remains unchanged |
| `PE_HOLD_TC_004` | `PE_HOLD_001` | Clear the accumulator, then drive idle cycles | `acc` remains zero |

---

# 6. Output Test

| Test ID | Requirement | Stimulus | Expected result |
| --- | --- | --- | --- |
| `PE_OUT_TC_001` | `PE_OUT_001` | Observe `acc` through reset, clear, MAC, and hold operations | `acc` always matches the PE accumulator state |

---

# 7. Parameter Tests

These tests are planned to check that the PE behavior is not limited to the
formal harness configuration.

| Test ID | Stimulus/configuration | Expected result |
| --- | --- | --- |
| `PE_PARAM_TC_001` | `N=1` with default `ACC_WIDTH` | Default accumulator width follows the special-case RTL formula |
| `PE_PARAM_TC_002` | At least one legal `width` other than 8 | Signed MAC behavior remains correct |
| `PE_PARAM_TC_003` | At least one legal `N` other than 8 | Default accumulator width and arithmetic remain correct |
| `PE_PARAM_TC_004` | Legal explicit `ACC_WIDTH` override | Product extension and accumulator wrap follow the configured width |

---

# 8. Regression Entry Criteria

Before running the standalone PE regression:

- The PE RTL and standalone testbench compile successfully.
- Clock and reset generation are available.
- The signed fixed-width reference model and result checker are enabled.
- The selected parameter configuration is legal.

---

# 9. Exit Criteria

The planned standalone PE simulation scope is complete when:

- Every in-scope test listed above has an executable implementation and passes.
- No unexpected assertion failure, simulation error, or fatal error occurs.
- Functional coverage has been collected and reviewed against the verification
  plan.
- Any excluded test, uncovered bin, or known limitation is explicitly
  documented.
- No unresolved PE bug remains within the agreed scope.

These are targets for completion, not claims about the current simulation
status.

