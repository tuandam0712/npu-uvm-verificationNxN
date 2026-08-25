# APB Wrapper Verification Testplan

## 1. Scope

This testplan covers the APB wrapper verification layer for the NxN Systolic Array NPU.

The APB wrapper provides software-style access to:

- CONTROL register
- STATUS register
- Matrix A write region
- Matrix B write region
- Matrix C read region

The current verified APB configuration is:

```text
N              = 8
DATA_WIDTH     = 8
APB_DATA_WIDTH = 32
```

## 2. Features Under Verification

| ID | Feature | Status |
|---|---|---|
| APB_F1 | APB register access | Verified |
| APB_F2 | Matrix A write access | Verified |
| APB_F3 | Matrix B write access | Verified |
| APB_F4 | CONTROL.start behavior | Verified |
| APB_F5 | STATUS.done polling | Verified |
| APB_F6 | STATUS.busy behavior | Verified |
| APB_F7 | Matrix C readback | Verified |
| APB_F8 | Signed data handling | Verified |
| APB_F9 | APB protocol SVA | Verified |
| APB_F10 | APB error response | Verified |

## 3. APB UVM Environment

The APB UVM environment includes:

- APB sequence item
- APB sequences
- APB sequencer
- APB driver
- APB monitor
- APB agent
- APB environment
- APB scoreboard
- APB functional coverage
- APB protocol SVA checker

## 4. Test Scenarios

| Test ID | Test Name | Purpose | Status |
|---|---|---|---|
| APB_TC_001 | Register Access Test | Basic access to CONTROL, STATUS, A, B, and C regions | PASS |
| APB_TC_002 | Identity Matrix Test | Verify `A = I`, `C = B` | PASS |
| APB_TC_003 | Zero Matrix Test | Verify `A = 0`, `C = 0` | PASS |
| APB_TC_004 | Sparse Matrix Test | Verify sparse matrix behavior | PASS |
| APB_TC_005 | Bounded Random-like Matrix Test | Verify non-trivial positive matrix data | PASS |
| APB_TC_006 | Signed Matrix Test | Verify negative input and negative output readback | PASS |
| APB_TC_007 | Status Behavior Test | Verify busy/done status behavior | PASS |
| APB_TC_008 | APB Protocol SVA | Verify setup/access phase and signal stability | PASS |
| APB_TC_009 | Negative Access Test | Verify unsupported-direction, invalid, misaligned, and busy-state error responses | PASS |

## 5. Scoreboard Plan

The APB scoreboard dynamically captures APB writes to Matrix A and Matrix B regions.

For every Matrix C readback transaction, the scoreboard computes the expected value using:

```text
C[i][j] = sum(A[i][k] * B[k][j])
```

The expected value is compared against the APB readback data.

The APB scoreboard is intentionally dynamic and does not use hard-coded expected Matrix C values. This allows the same scoreboard to verify identity, zero, sparse, bounded random-like, signed, and status-driven compute scenarios.

## 6. Coverage Plan

The APB coverage model tracks:

- APB read/write accesses
- CONTROL, STATUS, A, B, and C address regions
- CONTROL.start writes
- STATUS reads
- busy/done status observations
- Matrix C readback count
- slave error observation count

The APB coverage summary also reports:

```text
samples
start_writes
status_reads
c_reads
busy_seen
done_seen
slverr_seen
```
### Error Response Coverage

The coverage model contains active normal-response and slave-error bins. Negative sequences exercise unsupported read/write directions, invalid and misaligned addresses, Matrix A writes while busy, and repeated start commands while busy.

Expected error responses are checked in the sequence. The scoreboard discards rejected transfers before updating its A/B model or comparing Matrix C.

## 7. APB Protocol SVA Plan

The APB protocol SVA checker verifies basic APB protocol behavior:

- `PENABLE` should only be high when `PSEL` is high
- Access phase should follow setup phase
- Address should stay stable during wait states
- Write data should stay stable during write wait states
- `PWRITE` should stay stable during wait states

## 8. Pass Criteria

The APB regression is considered passing when:

- All APB transactions complete successfully
- All Matrix C readback values match the dynamic golden model
- No UVM errors or fatals are reported
- APB protocol SVA reports no assertion failures
- Functional coverage is collected and reported
- Every expected and unexpected APB error response is checked by the sequence

## 9. Latest Result

```text
APB transactions: 1249 / 1249 PASS
C matrix checks: 384 / 384 PASS
UVM_WARNING: 0
UVM_ERROR  : 0
UVM_FATAL  : 0
APB functional coverage: 100.00%
```

Coverage summary:

```text
samples      = 1249
start_writes = 7
status_reads = 79
c_reads      = 384
busy_seen    = 70
done_seen    = 8
slverr_seen  = 9
```

## 10. Current Limitations

- APB zero-wait-state response is used.
- Wait-state insertion and wait-state response timing are not implemented.
- The current driver returns to IDLE after each transfer and does not generate `psel`-held back-to-back accesses.
- Full APB VIP-level random protocol verification is not claimed.
- AXI-Lite wrapper verification is not included in the current APB verification scope.
