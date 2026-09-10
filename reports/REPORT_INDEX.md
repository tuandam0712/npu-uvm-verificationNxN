# Evidence index

Updated 2026-09-11. Do not combine numbers from different runs or scopes.

| Artifact | Scope / status |
|---|---|
| `NPU_RESET_REPORT.md` | Current fixed-seed NPU baseline/COMPUTE/DRAIN results and limitations |
| `coverage_summary.txt`, `coverage_report.txt` | Current NPU runtime functional summaries; not UCDB/bin-level code-coverage reports |
| `CLOSURE_REPORT.md` | Existing PE/controller/SARR milestones plus bounded NPU reset milestone |
| `apb_coverage_report.txt`, `apb_coverage_summary.txt`, `apb_func_coverage_report.txt` | Historical simulator-generated APB coverage snapshot; not regenerated for the latest 1251-transfer test; source listings/line numbers may be stale |
| `pe/`, `controller/`, `sarr/` | Existing unit-level evidence, unchanged by core-UVM reset work |

Latest separately observed APB log (2026-09-10, `reports/apb_regression.log`):
1251 transfers PASS, 384 C checks PASS, nine slave errors as expected, one
two-write no-wait back-to-back cover hit, zero UVM errors/fatals and simulator
errors. Core reset changes do not extend APB reset verification.

Raw logs and UCDBs remain generated/ignored artifacts. Historical machine
reports are retained as evidence; their numbers are not manually rewritten
to imitate a fresh simulator report.
