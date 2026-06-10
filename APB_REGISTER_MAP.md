# APB Register Map
This document describes the APB-mapped register interface for the NxN Systolic Array NPU.

## Address Map

| Address Range | Name | Access | Description |
|---|---|---|---|
| 0x0000_0000 | CONTROL | W | Control register |
| 0x0000_0004 | STATUS | R | Status register |
| 0x0000_0010 - 0x0000_010C | MATRIX_A | W | Matrix A input registers |
| 0x0000_0110 - 0x0000_020C | MATRIX_B | W | Matrix B input registers |
| 0x0000_0210 - 0x0000_030C | MATRIX_C | R | Matrix C output registers |
## CONTROL Register - 0x0000_0000

| Bit | Name | Access | Description |
|---|---|---|---|
| 0 | start | W | Write 1 to start NPU computation |
| 31:1 | reserved | - | Reserved |

`start` is converted into a one-cycle pulse inside the APB wrapper.
## STATUS Register - 0x0000_0004

| Bit | Name | Access | Description |
|---|---|---|---|
| 0 | done | R | 1 when computation is complete |
| 1 | busy | R | 1 when NPU is running |
| 31:2 | reserved | - | Reserved |
## Matrix Register Addressing
For N = 8, each matrix has 64 elements.

Each element is mapped as one 32-bit APB word.
### Matrix A
A[i][j] address = 0x0000_0010 + 4 * (i*N + j)
### Matrix B
B[i][j] address = 0x0000_0110 + 4 * (i*N + j)
### Matrix C
C[i][j] address = 0x0000_0210 + 4 * (i*N + j)
## Basic Software Flow
1. Write Matrix A through APB
2. Write Matrix B through APB
3. Write CONTROL.start = 1
4. Poll STATUS.done
5. Read Matrix C through APB
6. Compare Matrix C with golden model
## Current Verification Status
Current APB smoke test:

A = Identity Matrix
B = Simple Matrix
Expected C = A x B = B
Result: PASS

Verified features:
- APB write CONTROL.start
- APB read STATUS.done/busy
- APB write Matrix A
- APB write Matrix B
- APB read Matrix C
- NPU computation through APB wrapper