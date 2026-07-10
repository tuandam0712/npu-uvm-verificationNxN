# Processing Element Verification Plan

Version: 0.2  
Status: Draft

---

# 1. Scope

This plan covers the PE requirements defined in `NPU_SPEC.md`. Verification of
the systolic array, controller, NPU top, APB wrapper, and their UVM
environments is outside this revision.

The plan distinguishes between:

- **Planned**: verification work identified but not yet demonstrated.
- **Directly proven**: a formal assertion directly checks the requirement.
- **Covered by proof model**: the behavior is part of a wider proven equation,
  but has no independent property.
- **Structural review**: supported by direct RTL construction rather than a
  separate temporal property.

---

# 2. Verification Methods

## 2.1 Simulation

Planned directed PE tests will drive reset, clear, valid, and signed operands.
A reference accumulator will predict the fixed-width result at each relevant
clock edge.

The test cases are defined in `NPU_TEST_PLAN.md`. Listing a test case in that
document does not mean that the test has already been implemented or passed.

## 2.2 Assertions

The PE RTL currently contains the following simulation assertions and cover
properties:

| Assertion/cover | Checked behavior |
| --- | --- |
| `A_PE_HOLD_001` / `C_PE_HOLD_001` | Hold when `clear=0` and `valid=0` |
| `A_PE_RST_002_003` / `C_PE_RST_002_003` | Accumulator is zero while reset is sampled active |
| `A_PE_RST_004` / `C_PE_RST_004` | Reset priority over clear or valid |
| `A_PE_CLR_002_003` / `C_PE_CLR_002_003` | Clear produces a zero accumulator |
| `A_PE_CLR_004` / `C_PE_CLR_004` | Clear priority over valid |
| `A_PE_MAC_001_002_003` / `C_PE_MAC_001_002_003` | MAC state-update equation |

The cover properties record that control situations occurred. They do not by
themselves prove arithmetic correctness or complete functional coverage.

## 2.3 Formal

The formal harness is configured for `N=8`, `width=8`, and
`ACC_WIDTH=2*width+$clog2(N)`. It contains four tasks:

| Formal task | Main property | Committed artifact status |
| --- | --- | --- |
| `reset` | Reset value and priority | PASS |
| `clear` | Clear value and priority | PASS |
| `mac` | MAC update equation | PASS |
| `hold` | Accumulator hold | PASS |

The current reset proof samples behavior at `posedge clk`; it does not
separately prove the time between asynchronous reset assertion and the next
clock edge. The formal results also apply only to the configured parameter
values unless additional parameter configurations are run.

## 2.4 Functional Coverage

Functional coverage for the standalone PE is planned. Coverage goals include:

- Reset, clear, MAC, and hold operations.
- Reset overlapping clear and valid.
- Clear overlapping valid.
- Positive, zero, and negative operands.
- Positive, zero, and negative products.
- Operand boundary values.
- Accumulator overflow and wraparound.
- Consecutive MAC and multi-cycle hold operations.

No standalone PE functional-coverage percentage is claimed by this revision.

---

# 3. Requirement Traceability

| Req ID | Planned simulation | Assertion/formal evidence | Current classification |
| --- | --- | --- | --- |
| `PE_RST_001` | `PE_RST_TC_001` | RTL asynchronous reset event control | Structural review |
| `PE_RST_002` | `PE_RST_TC_002` | Reset proof checks zero at clock samples | Partially proven |
| `PE_RST_003` | `PE_RST_TC_003` | `A_PE_RST_002_003`, task `reset` | Directly proven at clock samples |
| `PE_RST_004` | `PE_RST_TC_004` | `A_PE_RST_004`, task `reset` | Directly proven at clock samples |
| `PE_CLR_001` | `PE_CLR_TC_001` | Clocked clear implementation | Structural review |
| `PE_CLR_002` | `PE_CLR_TC_002` | `A_PE_CLR_002_003`, task `clear` | Directly proven |
| `PE_CLR_003` | `PE_CLR_TC_003` | `A_PE_CLR_002_003`, task `clear` | Directly proven |
| `PE_CLR_004` | `PE_CLR_TC_004` | `A_PE_CLR_004`, task `clear` | Directly proven |
| `PE_MAC_001` | `PE_MAC_TC_001` | `A_PE_MAC_001_002_003`, task `mac` | Directly proven by update equation |
| `PE_MAC_002` | `PE_MAC_TC_002` | Signed reference product in task `mac` | Covered by proof model |
| `PE_MAC_003` | `PE_MAC_TC_003` | `2*width` reference product in task `mac` | Covered by proof model |
| `PE_MAC_004` | `PE_MAC_TC_004` | Sign-extended reference product in task `mac` | Covered by proof model |
| `PE_MAC_005` | `PE_MAC_TC_005` | `A_PE_MAC_001_002_003`, task `mac` | Directly proven |
| `PE_MAC_006` | `PE_MAC_TC_006` | Fixed-width comparison in task `mac` | Covered indirectly; separate overflow check planned |
| `PE_HOLD_001` | `PE_HOLD_TC_001` to `004` | `A_PE_HOLD_001`, task `hold` | Directly proven |
| `PE_OUT_001` | `PE_OUT_TC_001` | RTL continuous assignment | Structural review |

---

# 4. Pass and Completion Criteria

The PE verification scope may be declared complete only when:

- All planned standalone PE tests required for the agreed scope are
  implemented and pass.
- All in-scope assertions pass without being disabled or made vacuous by an
  unintended assumption.
- All formal tasks required for the agreed parameter configurations pass.
- Standalone PE functional coverage is collected and remaining gaps are
  reviewed and documented.
- No unresolved PE bug remains within the agreed scope.

The current formal `PASS` artifacts are positive evidence, but do not alone
satisfy all completion criteria above.

