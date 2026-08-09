# NPU Verification Plan

Version: 0.7
Status: Draft

---

# 1. Scope

This plan covers the PE, Systolic Array Controller, and Systolic Array
requirements defined in `NPU_SPEC.md`. Verification of NPU top, APB wrapper,
and their UVM environments is outside this revision.

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

# 6. Systolic Array
## 6.1 Scope

This plan defines unit-level verification of `rtl/systolic_arr_NxN.sv`.
The scope includes reset and clear behavior, operand skew and propagation, valid propagation, operand-valid-alignment, PE accumulation, output stability, drain behavior, operation isolation, and parameter-dependent positional latency.
Controller sequencing, NPU Top integration, APB behavior and overlapping matrix operations are outside this unit-level scope.

## 6.2 Verification Methods
### 6.2.1 Simulation

Directed and constrained-random simulation shall verify reset and clear
behavior, operand-valid alignment, matrix computation, drain behavior, output
stability, and back-to-back operations.

An independent reference model shall compute the expected matrix result from
the input matrices using the specified signed, fixed-width arithmetic. The
scoreboard shall compare each actual array output against the corresponding
expected result after the operation has completed.

Directed simulation shall target timing-sensitive and control-sensitive
scenarios that are not adequately demonstrated by broad arithmetic
randomization. These scenarios shall include asynchronous reset during an
active operation, clear during active MAC processing, pipeline drain behavior,
first-to-last PE completion ordering, and back-to-back operations using the
specified clear protocol.

Constrained-random simulation shall exercise a broader range of operand values,
matrix patterns, and legal operation sequences. It shall complement, but not
replace, directed testing of exact timing behavior.

Detailed test scenarios and test-case identifiers shall be maintained in
`NPU_TEST_PLAN.md`.

### 6.2.2 Assertions

SystemVerilog Assertions shall verify cycle-accurate local and positional
behavior within the systolic array.

Assertion checks shall include:

* reset and clear effects and priority;
* one-cycle horizontal propagation of operand A;
* one-cycle vertical propagation of operand B;
* local-valid propagation through the array;
* positional latency of A, B, and valid at selected or generated PE locations;
* alignment of corresponding A and B operands during each local-valid cycle;
* one MAC update per local-valid cycle;
* accumulator hold when local valid is low;
* output stability after completion;
* continued propagation of in-flight valid state after `valid_in` is
  deasserted.

Where practical, properties shall be generated across legal PE coordinates
rather than written only for a single PE location.

Cover properties shall demonstrate that relevant antecedents and positional
scenarios are exercised. Assertion pass results without corresponding
reachability evidence shall not be treated as sufficient evidence of
non-vacuous verification.

End-to-end matrix arithmetic correctness shall remain primarily checked by the
reference model and scoreboard rather than by a single large assertion.

### 6.2.3 Formal

Formal verification shall target local, structural, and bounded temporal
properties that can be proven without enumerating complete matrix operations
through simulation.

The formal scope shall include:

* reset and clear behavior;
* reset and clear priority;
* one-hop A and B propagation;
* one-hop local-valid propagation;
* accumulator hold when local valid is low;
* local MAC state-update behavior;
* selected positional-latency and operand-valid-alignment properties;
* absence of stale local-valid state after reset or clear.

Formal proofs may use reduced array configurations, such as `N=2` or `N=4`,
when the property is structurally representative and the reduction is
documented.

Formal PASS results shall apply only to the parameter configurations and
assumptions used by the corresponding harness. Full matrix arithmetic
correctness across broad operand and parameter spaces shall remain covered by
simulation and regression.

The executable SymbiYosys harness in `formal/sarr` uses Z3 at depth 20. The
`reset`, `clear`, `operand`, `valid`, and `cover` tasks run at `N=2`,
`width=8`, and `ACC_WIDTH=17`. The multiplier-heavy `mac_hold` task runs at
`N=2`, `width=4`, and `ACC_WIDTH=9`. All six tasks have current `PASS`
artifacts. These reduced configurations prove the generated local structure
present in those models; they do not prove every legal parameter combination
or end-to-end matrix multiplication at `N=8`.

### 6.2.4 Functional Coverage

Functional coverage shall measure whether the planned control, data, timing,
matrix-pattern, and parameter scenarios have been exercised.

Coverage goals shall include:

* reset during idle, operand propagation, active valid propagation, active MAC
  processing, and drain;
* clear during idle and active processing;
* reset overlapping clear and valid activity;
* clear overlapping valid activity;
* local-valid activity at representative PE positions;
* first, middle, and last PE completion;
* positive, negative, zero, minimum, and maximum operand values;
* positive, negative, and zero products;
* zero, identity, sparse, dense, and mixed-sign matrix patterns;
* positive and negative accumulator wraparound;
* single-operation and back-to-back-operation scenarios;
* selected `N`, `width`, and `ACC_WIDTH` configurations;
* meaningful crosses between operand classes, matrix patterns, PE positions,
  and control scenarios.

Coverage exclusions and unreachable bins shall be reviewed and documented
rather than silently ignored.

No SARR functional-coverage percentage shall be claimed until coverage has
been collected from executable regressions and the remaining gaps have been
reviewed.

### 6.2.5 Configuration and Regression

Regression shall exercise the systolic array across selected legal parameter
configurations rather than relying only on the primary `N=8`, `width=8`
configuration.

The planned configuration set shall include, at minimum:

* `N=1`, `width=8`;
* `N=2`, `width=8`;
* `N=4`, `width=8`;
* `N=8`, `width=8`;
* at least one additional operand-width configuration.

Each configuration shall run the applicable directed tests,
constrained-random tests, assertions, scoreboard checking, and functional
coverage.

Regression results shall record:

* test name;
* parameter configuration;
* random seed;
* pass or fail status;
* assertion failures;
* scoreboard mismatches;
* functional-coverage summary.

A configuration shall not be classified as verified solely because it
successfully compiles or completes simulation without a fatal error.
## 6.3 Requirement Traceability

The following table maps each SARR requirement group to its planned simulation,
assertion, formal, and regression evidence.

The current classification reflects the reviewed directed testbench and the
current reduced-configuration formal results. The directed testbench is
implemented but no passing simulation transcript is recorded by this
revision, so implementation is not reported as executed evidence.

| Requirement group | Planned simulation evidence                                                                                           | Planned assertion/formal evidence                                                                           | Current classification |
| ----------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------- |
| `SARR_RST_*`      | Directed reset scenarios during operand propagation, active valid propagation, MAC processing, drain, and output hold | Reset-state, reset-retention, and reset-priority checks; formal task `reset` is `PASS` at `N=2`, `width=8` | Partial: reduced formal proof plus implemented directed checks |
| `SARR_CLR_*`      | Directed clear scenarios during idle and active processing, including clear overlapping valid activity                | Clear-state, clear-retention, pipeline-flush, and clear-priority checks; task `clear` is `PASS` at `N=2`, `width=8` | Partial: reduced formal proof plus implemented directed checks |
| `SARR_A_*`        | Tagged operand-A patterns checked at representative and boundary PE locations                                         | Entry/skew and horizontal one-hop checks; task `operand` is `PASS` at `N=2`, `width=8` | Partial: reduced formal proof; dedicated directed checks remain planned |
| `SARR_B_*`        | Tagged operand-B patterns checked at representative and boundary PE locations                                         | Entry/skew and vertical one-hop checks; task `operand` is `PASS` at `N=2`, `width=8` | Partial: reduced formal proof; dedicated directed checks remain planned |
| `SARR_VAL_*`      | Directed valid pulses, contiguous valid streams, reset/clear interruption, and drain scenarios                        | Valid-entry and one-hop checks; task `valid` is `PASS` at `N=2`, `width=8`; reachability task `cover` is `PASS` | Partial: reduced formal proof plus implemented burst/drain checks |
| `SARR_ALIGN_*`    | Tagged A/B input samples checked during local-valid activity at selected PE locations                                 | Local structural propagation and MAC/hold proofs support alignment; exact positional alignment remains planned in the formal harness | Partial |
| `SARR_MAC_001`    | Directed local-valid MAC scenarios and matrix tests                                                                   | Local signed MAC state-update check; task `mac_hold` is `PASS` at `N=2`, `width=4` | Directly proven in the reduced arithmetic model; directed implementation present |
| `SARR_MAC_002`    | Operations containing exactly `N` consecutive valid input samples                                                     | Local-valid count properties and generated completion checks                                                | Planned                |
| `SARR_MAC_003`    | Directed partial-accumulation tests using known operand sequences                                                     | Partial-sum reference properties at selected PE locations                                                   | Planned                |
| `SARR_MAC_004`    | Directed and constrained-random matrix tests using an independent reference model and scoreboard                      | Local arithmetic properties support the result; end-to-end correctness remains primarily simulation-based   | Planned                |
| `SARR_MAC_005`    | Invalid-cycle and post-operation hold scenarios                                                                       | Accumulator-hold and output-stability checks; task `mac_hold` is `PASS` at `N=2`, `width=4` | Directly proven in the reduced model; directed implementation present |
| `SARR_TIME_*`     | First-to-last completion ordering, valid drain, and final-result timing scenarios                                     | First-PE, last-PE, in-flight-valid, and positional-completion properties                                    | Planned                |
| `SARR_OUT_*`      | Output reset, clear, hold, and post-operation stability scenarios                                                     | Reset/clear and output-hold checks in tasks `reset`, `clear`, and `mac_hold` | Partial: reduced formal proof plus implemented directed checks |
| `SARR_PARAM_*`    | Multi-configuration regression across selected `N`, `width`, and `ACC_WIDTH` values                                   | Generated structural and positional properties compiled and checked per configuration                       | Planned                |
| `SARR_OP_*`       | Back-to-back operations using the required clear protocol                                                             | Clear-to-first-MAC, zero-initial-accumulator, and no-stale-valid properties                                 | Planned                |

Detailed test-case identifiers shall be maintained in `NPU_TEST_PLAN.md`.
Assertion and formal property identifiers shall be added to this table after
the corresponding executable checks are implemented.

---

## 6.4 Additional Verification Properties

The following properties are not direct restatements of individual SARR
requirements but are included to improve verification completeness, debug
quality, and confidence in array behavior.

| Property                                                                                    | Classification         | Planned evidence                                          |
| ------------------------------------------------------------------------------------------- | ---------------------- | --------------------------------------------------------- |
| No unknown PE output after reset or clear under legal two-state stimulus                    | Sanity                 | Simulation assertion and regression check                 |
| Every local-valid assertion eventually deasserts after `valid_in` is deasserted             | Drain/liveness         | Bounded SVA or formal property                            |
| Local valid does not duplicate or extend beyond the input valid-stream width                | Consistency            | Pulse-width preservation property                         |
| Operand A never propagates vertically between PE rows                                       | Structural consistency | Structural review or generated assertion where observable |
| Operand B never propagates horizontally between PE columns                                  | Structural consistency | Structural review or generated assertion where observable |
| Every PE receives the same number of local-valid cycles for a legal operation               | Operation consistency  | Generated counters or SVA                                 |
| The final expected result is not compared before the last PE completes                      | Scoreboard timing      | Monitor/scoreboard protocol check                         |
| Scoreboard transactions from consecutive operations cannot be mixed                         | Environment integrity  | Operation identifier and queue-consistency checks         |
| Reference-model arithmetic matches signed `ACC_WIDTH` wraparound rules                      | Model integrity        | Directed boundary and overflow tests                      |
| Every assertion antecedent is exercised in at least one simulation or formal cover scenario | Non-vacuity            | Cover properties and coverage review                      |
| No scoreboard mismatch is suppressed, downgraded, or ignored during regression              | Environment integrity  | Regression log and error-count checks                     |

These properties shall not be used to introduce new architectural requirements.
They are verification controls derived from the specified behavior and the
needs of the verification environment.

---

## 6.5 Pass and Completion Criteria

The SARR verification scope may be declared complete only when all of the
following conditions are satisfied:

* all planned directed SARR tests required for the agreed scope are
  implemented and pass;
* all required constrained-random regressions complete without unresolved
  scoreboard mismatches;
* the independent reference model is reviewed against the signed,
  fixed-width arithmetic defined in `NPU_SPEC.md`;
* all in-scope assertions pass without being disabled, weakened, or made
  vacuous by unintended assumptions;
* all required formal tasks pass for the agreed formal configurations;
* any use of reduced formal configurations is documented together with the
  property scope and structural justification;
* all required parameter configurations compile, run, and pass their
  applicable checks;
* functional coverage is collected from executable regressions;
* uncovered bins, excluded bins, and unreachable bins are reviewed and
  documented;
* reset, clear, operand propagation, valid propagation, alignment, drain,
  matrix computation, output stability, and operation isolation each have
  traceable executable evidence;
* regression logs record test name, configuration, random seed, assertion
  failures, scoreboard mismatches, and final status;
* no unresolved SARR bug remains within the agreed verification scope;
* no test passes solely because checking was skipped, timed out, disabled, or
  performed before the final array result became valid.

Formal PASS results, assertion PASS results, or high functional coverage alone
shall not be treated as sufficient verification closure. Closure requires
consistent evidence from the applicable simulation, assertion, formal,
coverage, and regression methods.

---

## 6.6 Known Gaps and Limitations

Until executable SARR verification is completed, the following limitations
shall be recorded:

* no SARR functional-coverage percentage is currently claimed;
* planned assertion and formal property names may change during
  implementation;
* proofs performed only at reduced `N` values shall not be claimed as complete
  proof of all parameter configurations;
* full matrix arithmetic correctness is not intended to be proven by a single
  end-to-end assertion;
* operation isolation is valid only when the specified clear protocol is
  followed;
* overlapping matrix operations and valid streams containing bubbles are
  outside the current operation protocol;
* NPU Top and controller-to-array integration timing are outside this
  unit-level verification scope.

---

# 7. Revision History

| Version | Date | Summary |
| --- | --- | --- |
| 0.4 | 2026-07-15 | Defined the PE and controller verification plan. |
| 0.5 | 2026-07-18 | Added the Systolic Array unit-level verification plan. |
| 0.6 | 2026-07-20 | Editorial normalization and version alignment; no verification intent changed. |
| 0.7 | 2026-08-08 | Reviewed the SARR directed testbench, added executable reduced-configuration Z3 formal evidence, and corrected SARR scope and traceability status. |
