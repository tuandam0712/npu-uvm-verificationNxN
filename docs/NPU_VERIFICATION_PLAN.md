# NPU Verification Plan

Version: 0.4
Status: Draft

---

# 1. Scope

This plan covers the PE and Systolic Array Controller requirements defined in
`NPU_SPEC.md`. Verification of the systolic-array datapath, NPU top, APB
wrapper, and their UVM environments is outside this revision.

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

---

# 5. Controller Verification Plan

## 5.1 Scope

This plan covers the controller requirements defined in `NPU_SPEC.md`.

Verification of the systolic array datapath, PE arithmetic behavior, top-level
integration timing, APB functionality, and UVM infrastructure is outside the
scope of this revision.

The controller verification scope focuses on:

* reset behavior;
* start acceptance behavior;
* state sequencing;
* output decode behavior;
* exact phase durations;
* completion signaling.

---

## 5.2 Verification Methods

### 5.2.1 Simulation

The directed controller testbench `tb/tb_controller_directed.sv` drives reset
and start requests while observing state transitions, output behavior, and
timing at `N=4`, `DRAIN_MARGIN=3`.

The planned tests include:

* reset assertion during every controller phase;
* accepted and rejected start requests;
* exact phase-duration measurements;
* state-transition verification;
* completion timing verification;
* restart scenarios.

Detailed controller test definitions and their implementation mapping are in
`NPU_TEST_PLAN.md`. The directed checks are implemented, but this revision does
not claim a saved passing simulator run.

### 5.2.2 Assertions

The controller RTL contains embedded assertion/cover pairs for reset state and
outputs, start handling in every phase, output decode in every phase, exact
counter progression and terminal transitions, IDLE retention, and exact
start-to-DONE latency (`N + (2*N + DRAIN_MARGIN) + 2` cycles). These properties
are excluded from the Yosys/SymbiYosys build by `SA_CTRL_FORMAL_SBY`; equivalent
immediate assertions are implemented in the formal harness.

### 5.2.3 Formal

The harness `formal/controller/controller_formal.sv` runs at `N=8`,
`DRAIN_MARGIN=10`. Committed artifacts report `PASS` for all tasks:

| Task | Evidence | Status |
| --- | --- | --- |
| `reset` | Reset state and decoded outputs | PASS |
| `start` | IDLE acceptance and IDLE retention | PASS |
| `phase` | Exact counter progression and all phase exits | PASS |
| `start_busy` | Busy-phase `start` does not alter progress | PASS |
| `output` | Output decode for every legal phase | PASS |
| `controller_cover` | Reachability and start-in-phase cover statements | PASS |

These proofs apply only to that parameter configuration. The formal reset task
samples at rising edges and therefore does not replace the directed
between-edge asynchronous-reset check. The embedded exact latency property is
not duplicated in the current formal harness.

### 5.2.4 Functional Coverage

Coverage goals include:

* reset assertion in every controller phase;
* start assertion in every controller phase;
* every legal controller transition;
* every controller phase being reached;
* exact duration scenarios;
* completion and restart scenarios.

The cover task reaches all phases and selected start scenarios, but no
controller functional-coverage percentage is claimed by this revision.

---

## 5.3 Requirement Traceability

| Req ID         | Planned simulation | Assertion/formal evidence            | Current classification |
| -------------- | ------------------ | ------------------------------------ | ---------------------- |
| `CTRL_RST_001` | `CTRL_RST_TC_001`  | RTL asynchronous reset event control | Structural review      |
| `CTRL_RST_002` | `CTRL_RST_TC_002`  | `A_CTRL_RST_002`, formal task `reset` | Directly proven at clock samples |
| `CTRL_RST_003` | `CTRL_RST_TC_003`  | `A_CTRL_RST_003`, formal task `reset` | Directly proven at clock samples |
| `CTRL_RST_004` | `CTRL_RST_TC_004`  | `A_CTRL_RST_004`; directed test implemented | Partial: embedded SVA plus directed implementation |

| Req ID           | Planned simulation  | Assertion/formal evidence           | Current classification |
| ---------------- | ------------------- | ----------------------------------- | ---------------------- |
| `CTRL_START_001` | `CTRL_START_TC_001` | Formal tasks `start`, `start_busy` | Directly proven for legal states |
| `CTRL_START_002` | `CTRL_START_TC_002` | `A_CTRL_START_002`, task `start` | Directly proven |
| `CTRL_START_003` | `CTRL_START_TC_003` | `A_CTRL_START_003_*`, task `start_busy` | Directly proven |
| `CTRL_START_004` | `CTRL_START_TC_004`, `CTRL_START_TC_005` | `A_CTRL_START_004_*`; directed restart tests | Assertion and directed checks implemented |

| Req ID         | Planned simulation | Assertion/formal evidence              | Current classification |
| -------------- | ------------------ | -------------------------------------- | ---------------------- |
| `CTRL_CLR_001` | `CTRL_CLR_TC_001`  | `A_CTRL_START_002`, task `start` | Directly proven |
| `CTRL_CLR_002` | `CTRL_CLR_TC_002`  | `A_CTRL_CLR_002_OUTPUT`, task `output` | Directly proven |
| `CTRL_CLR_003` | `CTRL_CLR_TC_003`  | `A_CTRL_CLR_003`, task `phase` | Directly proven |
| `CTRL_CLR_004` | `CTRL_CLR_TC_004`  | `A_CTRL_CLR_003`, task `phase` | Directly proven |

| Req ID          | Planned simulation | Assertion/formal evidence                   | Current classification |
| --------------- | ------------------ | ------------------------------------------- | ---------------------- |
| `CTRL_COMP_001` | `CTRL_COMP_TC_001` | `A_CTRL_COMP_001`, task `output` | Directly proven |
| `CTRL_COMP_002` | `CTRL_COMP_TC_002` | `A_CTRL_COMP_002_*`, task `phase` | Directly proven |
| `CTRL_COMP_003` | `CTRL_COMP_TC_003` | `A_CTRL_COMP_002_EXIT`, task `phase` | Directly proven |

| Req ID           | Planned simulation  | Assertion/formal evidence                | Current classification |
| ---------------- | ------------------- | ---------------------------------------- | ---------------------- |
| `CTRL_DRAIN_001` | `CTRL_DRAIN_TC_001` | `A_CTRL_DRAIN_001`, task `output` | Directly proven |
| `CTRL_DRAIN_002` | `CTRL_DRAIN_TC_002` | `A_CTRL_DRAIN_002_*`, task `phase` | Directly proven |
| `CTRL_DRAIN_003` | `CTRL_DRAIN_TC_003` | `A_CTRL_DRAIN_002_EXIT`, task `phase` | Directly proven |

| Req ID          | Planned simulation | Assertion/formal evidence          | Current classification |
| --------------- | ------------------ | ---------------------------------- | ---------------------- |
| `CTRL_DONE_001` | `CTRL_DONE_TC_001` | `A_CTRL_DONE_001`, task `output` | Directly proven |
| `CTRL_DONE_002` | `CTRL_DONE_TC_002` | `A_CTRL_DONE_002`, task `phase` | Directly proven |
| `CTRL_DONE_003` | `CTRL_DONE_TC_003` | `A_CTRL_DONE_002`, task `phase` | Directly proven |

| Req ID          | Planned simulation | Assertion/formal evidence    | Current classification |
| --------------- | ------------------ | ---------------------------- | ---------------------- |
| `CTRL_IDLE_001` | `CTRL_IDLE_TC_001` | `A_CTRL_IDLE_001`, task `output` | Directly proven |
| `CTRL_IDLE_002` | `CTRL_IDLE_TC_002` | `A_CTRL_IDLE_002`, task `start` | Directly proven |

---

## 5.3.1 Additional Verification Properties

The following properties are not directly derived from specification
requirements but are included to improve verification completeness and increase
confidence in controller correctness.

| Property | Classification | Planned evidence |
|----------|---------------|------------------|
| Accepted start reaches DONE at exact configured latency | Timing | Embedded `A_CTRL_LATENCY`; separate formal proof proposed |
| Controller state always remains within legal enum values | Sanity | Proposed explicit invariant; legal-state decode is indirectly covered |
| Control outputs are mutually exclusive | Consistency | Proven indirectly by formal task `output`; explicit invariant proposed |
| Every assertion antecedent is exercised at least once | Non-vacuity | Cover task is partial; per-antecedent review proposed |

## 5.4 Pass and Completion Criteria

The controller verification scope may be declared complete only when:

* all planned controller tests required for the agreed scope are implemented
  and pass;
* all in-scope assertions pass without unintended vacuity;
* all required formal tasks pass;
* controller functional coverage is collected and reviewed;
* no unresolved controller bug remains within the agreed scope;
* all controller phase durations and transitions are demonstrated by
  executable evidence.

Formal `PASS` results alone do not satisfy controller closure requirements.
