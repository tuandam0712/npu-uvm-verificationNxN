# APB Register Map

This document describes the APB-mapped register interface for the NxN Systolic Array NPU.

## Address Map

The current verified APB configuration is:

```text
N              = 8
DATA_WIDTH     = 8
APB_DATA_WIDTH = 32
```

Each matrix has 64 elements. Each element is mapped to one 32-bit APB word.

| Address Range | Name | Access | Description |
|---|---|---|---|
| `0x0000_0000` | CONTROL | W | Control register |
| `0x0000_0004` | STATUS | R | Status register |
| `0x0000_0010 - 0x0000_010C` | MATRIX_A | W | Matrix A input registers |
| `0x0000_0110 - 0x0000_020C` | MATRIX_B | W | Matrix B input registers |
| `0x0000_0210 - 0x0000_030C` | MATRIX_C | R | Matrix C output registers |

## CONTROL Register - `0x0000_0000`

| Bit | Name | Access | Description |
|---|---|---|---|
| 0 | start | W | Write 1 to start NPU computation |
| 31:1 | reserved | - | Reserved |

`start` is converted into a one-cycle pulse inside the APB wrapper.

## STATUS Register - `0x0000_0004`

| Bit | Name | Access | Description |
|---|---|---|---|
| 0 | done | R | 1 when computation is complete |
| 1 | busy | R | 1 when NPU is running |
| 31:2 | reserved | - | Reserved |

Observed status behavior in the APB UVM regression:

```text
During compute: STATUS = 0x00000002, done=0, busy=1
After done    : STATUS = 0x00000001, done=1, busy=0
```

## Matrix Register Addressing

For `N = 8`, each matrix has 64 elements.

Each element is mapped as one 32-bit APB word.

### Matrix A

```text
A[i][j] address = 0x0000_0010 + 4 * (i*N + j)
```

### Matrix B

```text
B[i][j] address = 0x0000_0110 + 4 * (i*N + j)
```

### Matrix C

```text
C[i][j] address = 0x0000_0210 + 4 * (i*N + j)
```

## Basic Software Flow

1. Write Matrix A through APB
2. Write Matrix B through APB
3. Write `CONTROL.start = 1`
4. Poll `STATUS.done`
5. Read Matrix C through APB
6. Compare Matrix C with the golden model

## Current Verification Status

The APB wrapper is verified using a dedicated APB UVM environment.

Verified APB features:

- APB register access
- Matrix A write through APB
- Matrix B write through APB
- CONTROL.start write
- STATUS.done polling
- STATUS.busy behavior during computation
- Matrix C readback through APB
- Signed matrix data handling
- Dynamic golden model comparison
- APB protocol SVA checking
- Functional coverage collection

Current APB regression scenarios:

| Scenario | Status |
|---|---|
| Register access | PASS |
| Identity matrix compute | PASS |
| Zero matrix compute | PASS |
| Sparse matrix compute | PASS |
| Bounded random-like matrix compute | PASS |
| Signed matrix compute | PASS |
| Status behavior test | PASS |
| APB protocol SVA | PASS |

Latest APB regression result:

```text
APB transactions: 1245 / 1245 PASS
C matrix checks: 384 / 384 PASS
UVM_WARNING: 0
UVM_ERROR  : 0
UVM_FATAL  : 0
APB functional coverage: 95.00%
```

Coverage summary:

```text
samples      = 1245
start_writes = 6
status_reads = 81
c_reads      = 384
busy_seen    = 72
done_seen    = 8
slverr_seen  = 0
```

## Current Limitations

- The APB wrapper currently uses zero-wait-state response.
- The APB wrapper ties `pslverr` to 0, so active APB error response behavior is not implemented.
- The APB coverage model excludes the unsupported `pslverr=1` bin instead of counting it as a missing coverage item.
- Invalid address error behavior is not claimed as verified.
- Full APB VIP-level constrained-random protocol verification is not claimed.