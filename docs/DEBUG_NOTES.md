# Debug Notes

This document records real debug issues encountered during the development of the NxN Systolic Array NPU UVM environment and APB wrapper verification.

The goal of this file is to document not only the final clean result, but also the actual bring-up/debug process, including symptoms, root causes, and fixes.

---

## 1. Accumulator Not Reset Between Transactions (2x2)

| Item | Detail |
|---|---|
| Symptom | The result of a later transaction was accumulated on top of the previous transaction result. |
| Root Cause | The PE accumulator did not have a proper `clear` mechanism between transactions. |
| How It Was Found | Waveform debug showed `acc_reg` continuing to increase across different tests instead of restarting from zero. |
| Fix | Added a `clear` signal into the PE and updated the controller to assert `clear=1` before starting a new computation. |

### Lesson Learned

For MAC-based datapaths, reset is not enough. A transaction-level clear is needed so consecutive computations do not corrupt each other.

---

## 2. Monitor Read Output Too Early (2x2)

| Item | Detail |
|---|---|
| Symptom | The scoreboard reported mismatches even though the DUT waveform showed the correct final result. |
| Root Cause | The monitor read `c00..c11` immediately when `done=1`, but the output data became stable one clock later. |
| How It Was Found | Waveform comparison showed the correct C values appeared one cycle after `done`. |
| Fix | Added one `@(posedge clk)` after detecting `done` before sampling output values. |

### Lesson Learned

A monitor must sample at the correct transaction boundary. Detecting `done` and sampling output are not always the same cycle.

---

## 3. PE Reset Assertion Timing Bug

| Item | Detail |
|---|---|
| Symptom | 64 assertion failures such as `[PE BUG] reset failed` appeared at around 5 ns. |
| Root Cause | The reset assertion used overlapped implication `|->`, checking `acc==0` in the same cycle as `!rst_n`. The registered accumulator updates on the next clock edge. |
| How It Was Found | The transcript showed assertion failures immediately at reset time. |
| Fix | Changed the assertion implication from `|->` to `|=>`. |

### Lesson Learned

For sequential logic, reset effect should often be checked on the next clock cycle, not the same cycle.

---

## 4. UVM Test Not Found Due to Parameterized Test Class

| Item | Detail |
|---|---|
| Symptom | Simulation stopped with `UVM_FATAL: Requested test not found`. |
| Root Cause | The test class was parameterized, for example `npu_test #(N, WIDTH)`, and `run_test()` could not parse a parameterized class name string directly. |
| How It Was Found | The simulation failed before running any sequence. |
| Fix | Created wrapper test classes such as `npu_test_N4 extends npu_test #(4,8)` and registered them with `uvm_component_utils`. |

### Lesson Learned

UVM factory registration works best with concrete, registered class names. Parameterized test classes should be wrapped if they are selected through `+UVM_TESTNAME`.

---

## 5. Monitor Missed Done Pulse (NxN)

| Item | Detail |
|---|---|
| Symptom | The controller asserted `done=1`, but the monitor did not detect it and simulation hung. |
| Root Cause | The monitor sampled `done` through the clocking block, and the one-cycle pulse could be missed due to sampling timing. |
| How It Was Found | The waveform and transcript showed `done` inside the controller, but no corresponding “DONE detected” message from the monitor. |
| Fix | Read `vif.done` directly and used edge/event-based detection instead of relying only on the clocking block sampled value. |

### Lesson Learned

Short pulses can be missed when sampled through a clocking block if the sampling timing is not aligned with the intended observation point.

---

## 6. Clocking Block Array Declaration Compile Error

| Item | Detail |
|---|---|
| Symptom | Compile error: `near "[": syntax error, unexpected '['`. |
| Root Cause | A clocking block attempted to redeclare signal types/dimensions instead of listing existing interface signals. |
| Incorrect Style | `output logic [WIDTH-1:0] a [N-1:0];` |
| Correct Style | `output a;` |
| Fix | Declared the signal type outside the clocking block and only referenced the signal name inside the clocking block. |

### Lesson Learned

A SystemVerilog clocking block does not redeclare the full type of signals. It only specifies clocking direction and timing for already-declared signals.

---

## 7. Compile / Cache Issue: Updated RTL Not Loaded

| Item | Detail |
|---|---|
| Symptom | RTL was modified multiple times, but simulation behavior did not change. |
| Root Cause | Questa `work` library still contained previously compiled objects, or the compile script pointed to the wrong file path. |
| How It Was Found | The waveform/transcript did not match the edited RTL source. |
| Fix | Deleted/recreated the `work` library using `vdel -lib work -all`, `vlib work`, and recompiled from a clean state. Also checked the current working directory and compile paths. |

### Lesson Learned

When debugging RTL changes, always verify that the simulator is compiling the intended source file from the intended path.

---

## 8. Reset During Compute Attempt

| Item | Detail |
|---|---|
| Symptom | Reset in the middle of an active transaction caused unstable UVM behavior and scoreboard mismatches. |
| Root Cause | The current UVM environment is transaction-based and expects each started transaction to eventually produce a valid `done` and output transaction. A mid-compute reset aborts the transaction and requires reset-aware cancellation logic. |
| Current Status | Rolled back from the clean regression. Not claimed as verified. |
| Future Fix | Add reset-aware driver, monitor, and scoreboard synchronization before claiming reset-during-compute support. |

### Lesson Learned

Reset-during-compute is not just another random scenario. It changes transaction lifetime and must be handled explicitly across the whole UVM environment.

---

## 9. APB Address Map Overlap / Wrong Base Address

| Item | Detail |
|---|---|
| Symptom | APB matrix regions were initially too close together, causing address overlap or incorrect access behavior for an 8x8 matrix. |
| Root Cause | The original APB base addresses were suitable for smaller testing but not for a full 8x8 matrix where each matrix occupies `64 * 4 = 256` bytes. |
| Fix | Updated APB regions to non-overlapping ranges: `A_BASE=0x0010`, `B_BASE=0x0110`, `C_BASE=0x0210`. |
| Verification | APB scoreboard later confirmed correct A/B capture and C readback across multiple compute scenarios. |

### Lesson Learned

A register map must be sized from actual matrix dimensions, not from a small smoke-test assumption.

---

## 10. APB Read C Before Compute Caused False Scoreboard Check

| Item | Detail |
|---|---|
| Symptom | The APB scoreboard could check C before the NPU had computed a valid output. |
| Root Cause | A register-access sequence included an early read from the C region before a valid compute operation. |
| Fix | Removed the pre-compute C read from the register-access sequence. C readback is now performed after `CONTROL.start` and `STATUS.done`. |

### Lesson Learned

A scoreboard should only check output regions when the design contract says the output is valid.

---

## 11. APB Scoreboard Initially Used Hard-Coded Golden Results

| Item | Detail |
|---|---|
| Symptom | The APB scoreboard could pass a specific identity test, but it was not general enough for other matrix patterns. |
| Root Cause | Expected C values were initially tied to a specific directed scenario. |
| Fix | Reworked the APB scoreboard into a dynamic model that stores Matrix A and Matrix B APB writes, then computes expected Matrix C internally. |

### Lesson Learned

A reusable scoreboard should model the intended behavior, not a single expected answer.

---

## 12. APB Scoreboard Report Condition Failed After Multiple Compute Sequences

| Item | Detail |
|---|---|
| Symptom | The log showed all transactions and C checks passing, but the final scoreboard summary still printed FAIL. |
| Example | `C MATRIX CHECK SUMMARY: checked=128 pass=128 fail=0`, followed by `APB SCOREBOARD FAIL`. |
| Root Cause | The report condition expected exactly `N*N` C checks, which was only valid for one compute sequence. After adding multiple APB compute sequences, the number of C checks became `2*N*N`, `3*N*N`, etc. |
| Fix | Changed the pass condition to require `fail_cnt==0`, `c_fail_cnt==0`, and `c_check_cnt>0` instead of requiring exactly one matrix worth of C checks. |

### Lesson Learned

Scoreboard report logic must match the regression structure. Multi-scenario tests should not be limited by single-transaction assumptions.

---

## 13. APB Sequence Accidentally Pasted Into Scoreboard File

| Item | Detail |
|---|---|
| Symptom | The simulation log showed `APB_SEQ` messages coming from `apb_scoreboard.sv`. |
| Root Cause | A new APB sequence class was accidentally pasted into the scoreboard file. |
| Fix | Moved all APB sequence classes back into `apb_sequence.sv` and kept `apb_scoreboard.sv` dedicated to scoreboard logic only. |

### Lesson Learned

File organization matters. A simulation may still pass even when code structure is messy, but repo maintainability suffers.

---

## 14. APB Signed Data Verification

| Item | Detail |
|---|---|
| Symptom / Risk | APB tests initially used mostly positive values, so signed input/output behavior was not strongly verified. |
| Fix | Added a signed matrix sequence using `A` diagonal values of `-1` encoded as `8'hFF`, with positive Matrix B values. |
| Result | The APB dynamic scoreboard passed signed readback checking, confirming negative input handling and signed output readback. |

### Lesson Learned

For signed INT8 designs, positive-only testing is not sufficient. Negative input and negative output readback must be explicitly verified.

---

## 15. APB Status Behavior Verification

| Item | Detail |
|---|---|
| Symptom / Risk | STATUS was initially used only for polling `done`, but `busy` behavior was not explicitly demonstrated. |
| Fix | Added an APB status behavior sequence that reads STATUS before a new start, during computation, and after done. |
| Observed Result | During compute: `done=0`, `busy=1`. After done: `done=1`, `busy=0`. |
| Final Coverage Counters | `status_reads=81`, `busy_seen=72`, `done_seen=8`. |

### Lesson Learned

Control/status registers should be verified as behavior, not only used as helper signals for test flow.

---

## 16. APB Coverage Initially Too Shallow

| Item | Detail |
|---|---|
| Symptom | APB coverage only reported a single percentage and did not explain what was actually covered. |
| Root Cause | Coverage counters and report breakdown were missing. Address coverage also focused on base addresses rather than clearly explaining matrix-region behavior. |
| Fix | Added counters for samples, start writes, status reads, C reads, busy seen, done seen, and slave errors seen. |
| Result | APB coverage report became easier to interpret and correlate with scoreboard totals. |

## APB Coverage Included Unsupported `pslverr=1` Bin

| Item | Detail |
|---|---|
| Symptom | APB functional coverage was limited because the coverage model included an error bin for `pslverr=1`. |
| Root Cause | The current APB wrapper ties `pslverr` to 0, so `pslverr=1` is not reachable in the implemented design. |
| How It Was Found | Coverage report showed a missing error bin even though APB error response behavior is not implemented or claimed. |
| Fix | Changed the coverage model to ignore the unsupported `pslverr=1` bin instead of counting it as a required coverage target. |
| Result | APB functional coverage increased to 95.00% while keeping the limitation clearly documented. |

### Lesson Learned

Coverage should measure implemented and claimed behavior. Unsupported behavior should be documented and excluded from the coverage target, not silently counted as a missing bin.
### Lesson Learned

Coverage is useful only when it explains what behavior was observed. A single percentage is not enough for debug or review.

---

## 17. APB Protocol SVA Integration

| Item | Detail |
|---|---|
| Symptom / Risk | The APB wrapper function worked, but protocol behavior was not independently checked. |
| Fix | Added an APB protocol SVA checker for setup/access phase behavior and signal stability. |
| Result | APB protocol SVA compiled and ran cleanly with no assertion failures. |

### Lesson Learned

A passing scoreboard proves functional result correctness, but protocol assertions add independent confidence in bus behavior.

---

## 18. Questa Report Generation Was Manual

| Item | Detail |
|---|---|
| Symptom | Regression and coverage results were manually copied from the transcript into documentation. |
| Risk | Manual copy-paste can introduce stale or inconsistent reports. |
| Fix | Added report-oriented `.do` scripts that write transcripts and coverage reports into the `reports/` folder. |

### Lesson Learned

A DV repo should be reproducible. Reports should be generated by scripts whenever possible, not manually typed.
