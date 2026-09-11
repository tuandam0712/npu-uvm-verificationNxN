# NPU reset recovery regression — 2026-09-11

## Scope and reproduction

RTL/UVM implementation: commit `3543bd5`. Tool: QuestaSim 10.7c win64,
UVM 1.1d, N=8, width=8, ACC_WIDTH=19. Reproduced with fixed seed **1**:

```tcl
do scripts/run_npu_reset.do all
# Individual cases: baseline, compute, drain
```

The runner uses `npu_reset_work`, compiles embedded RTL assertions, loads
the bundled UVM DPI DLL, limits each run to 1 ms simulated time, and rejects
missing accounting summaries, nonzero UVM errors/fatals, and simulator errors.
It does not delete the APB `work` library. Requires the Windows Questa 10.7c
layout (or UVM_HOME for UVM sources); no Linux portability claim is made.

## Results

| Case | Requested | Expected / observed aborts | Golden matches | Mismatches | Pending input / output | UVM error / fatal |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 142 | 0 / 0 | 142 | 0 | 0 / 0 | 0 / 0 |
| COMPUTE | 142 | 1 / 1 | 141 | 0 | 0 / 0 | 0 / 0 |
| WAIT_DRAIN | 142 | 1 / 1 | 141 | 0 | 0 / 0 | 0 / 0 |

All three complete normally with no simulator error or assertion failure.
Fresh RTL compilation emits four existing input-port-kind warnings (vlog-13314);
UVM warnings are zero. These are not code-coverage closure runs.

Generated local evidence: `logs/npu_reset_compile.log`,
`logs/npu_reset_baseline.log`, `logs/npu_reset_compute.log`, and
`logs/npu_reset_drain.log`. Logs/databases are ignored by Git; this report
preserves the reviewed summary, and the runner regenerates the raw evidence.

Runner update: new runs use `logs/npu_reset_<case>_seed<seed>.log` to preserve
separate evidence by seed. `do scripts/run_npu_reset.do all sweep` compiles
once and runs all three cases for seeds 1..5. The latest invocation writes
`reports/npu_multiseed_summary.csv`, including observed counts and per-run
coverage. This extends random operand sampling, not reset timing or parameter
coverage. Old unsuffixed logs above identify the original seed-1 milestone.

## Stimulus and checks

- Baseline retains the original 142-transaction directed/random regression.
- Each reset run replaces the initial zero-matrix transaction with a nonzero
  all-positive victim; the subsequent identity operation uses different data.
- COMPUTE: interrupt after four of eight sampled input slices while valid_in=1.
- DRAIN: interrupt after valid_in falls and before done, after the full feed.
- Assert reset on a falling clock edge, hold through three rising edges, and
  check done=0, valid_in=0 and every C element zero after updates settle.
- Driver cancels active work, idles its outputs, and returns item_done once.
  `aborted_cnt` counts cancellations; it is not cleared on reset.
- Monitor tasks restart after reset, dropping partial input/output collection.
- Scoreboard cancels the blocked comparison before flushing both FIFOs, so
  an expected item already removed from the FIFO cannot match a new result.
- Test timeout surrounds seq.start; it no longer waits for a second done pulse.
- Expected abort count is fixed by the scenario, not inferred from observed
  aborts. Completion and FIFO checks are separate from UVM error checks.

## Runtime functional coverage (seed 1)

| Case | Input data | Matrix pattern | Scenario | Output data |
|---|---:|---:|---:|---:|
| Baseline | 89.53% | 100.00% | 100.00% | 100.00% |
| COMPUTE | 89.53% | 92.31% | 100.00% | 100.00% |
| WAIT_DRAIN | 89.53% | 92.31% | 100.00% | 100.00% |

Reset runs replace the initial zero case and are not substitutes for baseline
pattern coverage. Scenario coverage currently classifies normal/back-to-back,
not reset phase/timing; its 100% does not establish reset coverage closure.
Earlier automatic-seed runs reported 90.91% input coverage; do not mix those
percentages with this reproducible seed-1 result. No UCDB merge was performed.

## Limits and next work

This closes two directed core-UVM reset/recovery points, not all reset behavior.
Repeated/random resets, every COMPUTE/drain offset, reset near done/start,
APB-level reset recovery, parameter sweeps, reset-specific coverage crosses,
and end-to-end formal reset proof remain open. Output checks sample after
reset settles; they do not prove continuous-time glitch freedom or recovery/removal timing.
FIFO emptiness alone cannot detect an item held outside a FIFO; cancellation
and expected completion counts are required as well. No RTL was changed.
