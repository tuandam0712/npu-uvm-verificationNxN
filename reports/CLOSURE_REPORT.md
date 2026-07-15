# PE Verification Closure Report

Version: 1.1
Status: Closed for the stated PE unit-level configuration

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
