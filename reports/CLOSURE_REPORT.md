# PE and Controller Verification Closure Report

Version: 1.3
Status: PE closed; controller closed with one documented directive-coverage gap

---

## 1. Scope

This report records unit-level verification results for the Processing Element
implemented in `rtl/pe.sv`. The closure statements in this report apply only to
the configuration and checks identified below; they do not claim exhaustive
verification of every legal parameter combination or of the integrated NPU.

The closed scope includes:

* asynchronous active-low reset;
* reset priority;
* synchronous clear;
* clear priority;
* signed multiply-accumulate behavior;
* product sign extension;
* accumulator hold;
* fixed-width wraparound;
* direct accumulator output behavior.

---

## 2. Verified Configuration

Primary configuration:

* `width = 8`
* `N = 8`
* `ACC_WIDTH = 19`

No additional parameter configuration is claimed by this report.

---

## 3. Simulation Results

| Item                              | Result          |
| --------------------------------- | --------------- |
| RTL compile                       | PASS            |
| Standalone directed PE regression | PASS            |
| Directed checks                   | 39 PASS, 0 FAIL |
| Simulation assertions in this run | PASS            |
| Asynchronous reset test           | PASS            |
| Reset priority test               | PASS            |
| Clear priority test               | PASS            |
| Signed arithmetic tests           | PASS            |
| Most-negative operand test        | PASS            |
| Hold-after-MAC test               | PASS            |
| Positive wraparound test          | PASS            |

The directed regression observed positive accumulator overflow and verified the
resulting fixed-width two's-complement wraparound.

---

## 4. Formal Results

Formal engine:

* SymbiYosys
* Yosys
* SMTBMC
* Z3
* configured proof depth: 20

| Formal task | Result |
| ----------- | ------ |
| `reset`     | PASS   |
| `clear`     | PASS   |
| `mac`       | PASS   |
| `hold`      | PASS   |

---

## 5. Mutation Test

Mutation applied:

```text
MAC priority was intentionally moved above Clear priority.
```

Expected behavior:

```text
The directed clear-priority test and formal clear properties must fail.
```

Observed result:

| Checker                       | Result   |
| ----------------------------- | -------- |
| Directed test `PE_CLR_TC_004` | DETECTED |
| `A_PE_CLR_002_003`            | DETECTED |
| `A_PE_CLR_004`                | DETECTED |

The directed test observed:

```text
expected acc = 0
observed acc = 146
```

The formal clear task returned `FAIL` and generated a counterexample trace.

The mutation was removed after detection. The `clear` formal task was rerun on
the restored RTL and completed with `PASS` for both basecase and induction.

---

## 6. Requirement Closure

| Requirement group | Unit-level result |
| ----------------- | ----------------- |
| Reset             | CLOSED            |
| Clear             | CLOSED            |
| MAC               | CLOSED            |
| Hold              | CLOSED            |
| Output            | COVERED           |

These results indicate closure against the listed directed checks and formal
properties for the primary configuration. They are not a claim of exhaustive
behavioral or parameter-space coverage.

---

## 7. Known Limitations

* Formal proofs are tied to the parameter values instantiated by the current
  formal harness.
* Illegal parameter combinations are not checked by the RTL.
* X/Z behavior is outside the current specification.
* Saturation arithmetic and overflow flags are not implemented.
* Standalone functional coverage is not yet maintained as a separate PE
  covergroup.
* Asynchronous reset behavior between clock edges is verified by directed
  simulation; the current formal reset properties are clock-sampled.

---

## 8. Closure Decision

The available unit-level results support proceeding with integration
verification in the stated NPU configuration. Final integrated-NPU approval
depends on the applicable array, controller, and end-to-end verification
results.

Any change to the following requires rerunning PE simulation and formal
regression:

* interface;
* reset behavior;
* operation priority;
* signed arithmetic;
* product width or sign extension;
* accumulator width;
* overflow behavior.

---

## 9. Controller Scope

This section records unit-level verification evidence for the Systolic Array
Controller implemented in `rtl/sa_controller_NxN.sv`. It is traced to the
`CTRL_*` requirements in `docs/NPU_SPEC.md`, the verification strategy in
`docs/NPU_VERIFICATION_PLAN.md`, and the executable tests mapped in
`docs/NPU_TEST_PLAN.md`.

The reviewed controller scope includes:

* asynchronous active-low reset and reset priority;
* start acceptance in `IDLE` and rejection while busy;
* held-start reacceptance and absence of a pending-request queue;
* `IDLE -> CLEAR -> COMPUTE -> WAIT_DRAIN -> DONE -> IDLE` sequencing;
* phase output decode;
* exact phase durations and counter progression;
* completion and restart behavior.

## 10. Controller Verified Configurations

| Method | `N` | `DRAIN_MARGIN` | Derived `DRAIN_CYCLES` |
| --- | ---: | ---: | ---: |
| Formal proof and cover | 8 | 10 | 26 |
| Directed testbench implementation | 4 | 3 | 11 |

The formal results apply only to the instantiated `N=8`, `DRAIN_MARGIN=10`
configuration. The `N=4`, `DRAIN_MARGIN=3` directed simulation has a saved UCDB
and assertion/directive report under `reports/controller/`.

## 11. Controller SVA and Formal Results

The controller RTL contains embedded assertion/cover pairs for reset, start
handling, phase outputs, counter progression, phase exits, IDLE retention, and
exact start-to-DONE latency. SymbiYosys uses equivalent immediate assertions in
`formal/controller/controller_formal.sv` because the embedded concurrent SVA
is excluded from that build by `SA_CTRL_FORMAL_SBY`.

Formal engine configuration:

* SymbiYosys with Yosys, SMTBMC, and Z3;
* proof depth: 20;
* cover depth: 45.

| Formal task | Main evidence | Artifact result |
| --- | --- | --- |
| `reset` | Reset state and decoded outputs | PASS |
| `start` | IDLE acceptance and IDLE retention | PASS |
| `phase` | Counter progression and all phase exits | PASS |
| `start_busy` | Busy-phase start does not alter progress | PASS |
| `output` | Output decode in every legal phase | PASS |
| `controller_cover` | Phase reachability and selected start scenarios | PASS |

All six committed controller formal artifacts contain `PASS`. The reset proof
is clock-sampled and does not independently prove the interval between an
asynchronous reset assertion and the next rising edge. The embedded exact
latency SVA is also not duplicated in the current formal harness.

## 12. Controller Simulation Status

`tb/tb_controller_directed.sv` implements checks for:

* asynchronous reset asserted between clock edges;
* reset from `CLEAR`, `COMPUTE`, `WAIT_DRAIN`, and `DONE`;
* reset priority over an active operation and `start`;
* accepted start in `IDLE` and ignored start in every busy phase;
* exact `CLEAR`, `COMPUTE`, `WAIT_DRAIN`, and `DONE` durations;
* a busy pulse not being queued;
* held-high start reacceptance;
* back-to-back operations.

| Item | Closure result |
| --- | --- |
| Directed test implementation review | COMPLETE |
| Saved simulation database | AVAILABLE: `reports/controller/controller.ucdb` |
| Saved SVA report | AVAILABLE: `reports/controller/controller_coverage.txt` |
| Assertion failures | 0 across all 26 reported assertions |
| Assertions with a recorded pass | 25 of 26 |
| Directive coverage | 96.15%: 25 of 26 covers hit |
| Saved directed checker summary | Not included in the saved coverage report |

The saved report provides direct evidence that the controller simulation ran
with embedded SVA enabled. Every reported assertion has zero failures. The
assertion `A_CTRL_START_003_COMPUTE_EXIT` has pass count zero because its
antecedent was not exercised; the matching cover
`C_CTRL_START_003_COMPUTE_EXIT` is the only uncovered directive.

The UCDB/report does not preserve the testbench's final
`[TB_CTRL] PASS checks=... errors=0` line, so the directed checker total is not
quoted numerically in this closure report.

## 13. Controller Requirement Closure

| Requirement group | Current result | Basis |
| --- | --- | --- |
| Reset | CLOSED | Formal checks pass; saved simulation exercises asynchronous reset and reset in every phase with zero assertion failures |
| Start acceptance | FORMALLY CLOSED | `start` and `start_busy` tasks pass |
| Clear phase | FORMALLY CLOSED | `start`, `phase`, and `output` tasks pass |
| Compute phase | FORMALLY CLOSED | `phase` and `output` tasks pass |
| Wait-drain phase | FORMALLY CLOSED | `phase` and `output` tasks pass |
| Done phase | FORMALLY CLOSED | `phase` and `output` tasks pass |
| Idle phase | FORMALLY CLOSED | `start` and `output` tasks pass |
| Exact end-to-end latency | CLOSED BY SIMULATION SVA | `A_CTRL_LATENCY` has zero failures and its matching cover is hit 14 times |
| Parameter space | PARTIAL | Formal evidence at `N=8/10`; directed implementation at `N=4/3`; wider legal sweep not run |
| Directive coverage | ACCEPTED WITH GAP | 96.15%; only busy start on the final COMPUTE cycle is not hit |

## 14. Controller Known Limitations and Open Items

* Run a standalone simulation at the primary `N=8`, `DRAIN_MARGIN=10`
  configuration, or explicitly waive it from the agreed closure scope.
* Add stimulus for `start=1` on the final `COMPUTE` cycle if 100% directive
  coverage is required. The current zero-hit item is
  `C_CTRL_START_003_COMPUTE_EXIT`.
* Preserve the controller simulator transcript in future regressions so the
  final directed checker count can be quoted independently of the UCDB.
* Add an explicit legal-state invariant and complete non-vacuity review if they
  are required by the project sign-off criteria.
* Invalid parameters, X/Z input behavior, and reset-deassertion/start timing
  races remain outside the specified scope.

## 15. Controller Closure Decision

The committed artifacts support controller unit closure across complementary
primary configurations:

* formal proof and cover at `N=8`, `DRAIN_MARGIN=10`;
* directed simulation and embedded SVA at `N=4`, `DRAIN_MARGIN=3`.

All formal tasks pass, all simulation assertions report zero failures, exact
latency is exercised, and directive coverage reaches 96.15%. The single
uncovered busy-start/final-COMPUTE directive is accepted as a documented
coverage gap because equivalent terminal COMPUTE behavior and busy-start
handling are formally proven.

The controller scope is therefore closed for the stated configurations, subject
to the parameter-space and coverage limitations above. This decision does not
claim exhaustive verification of every legal parameter combination.

Any change to the following requires rerunning the applicable controller
simulation and formal regression:

* interface or reset behavior;
* start acceptance or restart semantics;
* state transition logic;
* output decode;
* phase counters or latency formulas;
* `N`, `DRAIN_MARGIN`, or counter sizing.
