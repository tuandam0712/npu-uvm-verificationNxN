# NPU Functional Specification

Version: 0.6
Status: Draft

---

# 1. Scope

This revision specifies the functional behavior of the following blocks:

- Processing Element (PE), implemented in `rtl/pe.sv`.
- Systolic Array Controller, implemented in `rtl/sa_controller_NxN.sv`.
- Systolic Array, implemented in `rtl/systolic_arr_NxN.sv`.

The following RTL blocks exist but are outside the scope of this specification
revision and will be documented later:

- NPU Top
- APB Wrapper

## 1.1 Revision History

| Version | Date | Summary |
| --- | --- | --- |
| 0.4 | Previous revision | Specified the PE and Systolic Array Controller. |
| 0.5 | 2026-07-18 | Added the Systolic Array (SARR) functional specification and integrated it into the document scope. |
| 0.6 | 2026-07-20 | Editorial normalization and version alignment; no functional requirements changed. |

---

# 2. Processing Element (PE)

## 2.1 Overview

The PE contains a signed accumulator and performs one signed
multiply-accumulate operation on each rising edge of `clk` for which `valid` is
asserted and `clear` is deasserted.

The state-update priority is:

```text
Asynchronous reset > synchronous clear > MAC > hold
```

Except for asynchronous reset assertion, accumulator state changes occur on a
rising edge of `clk`.

## 2.2 Parameters

| Parameter | Default | Description |
| --- | ---: | --- |
| `width` | 8 | Signed operand width in bits |
| `N` | 8 | Array dimension used to derive the default accumulator width |
| `ACC_WIDTH` | See below | Signed accumulator width in bits |
| `ROW` | 0 | PE row identifier used in assertion diagnostics |
| `COL` | 0 | PE column identifier used in assertion diagnostics |

The RTL default for `ACC_WIDTH` is:

```text
ACC_WIDTH = 2*width + ((N > 1) ? ceil(log2(N)) : 1)
```

`ROW` and `COL` do not affect the arithmetic behavior.

This revision assumes legal parameter values and an `ACC_WIDTH` not smaller
than `2*width`. Illegal parameter combinations are not checked by the RTL.

## 2.3 Interface

| Signal | Direction | Width/type | Description |
| --- | --- | --- | --- |
| `clk` | input | 1 bit | Clock |
| `rst_n` | input | 1 bit | Active-low asynchronous reset |
| `clear` | input | 1 bit | Synchronous accumulator clear |
| `valid` | input | 1 bit | MAC enable |
| `a_in` | input | signed `[width-1:0]` | Operand A |
| `b_in` | input | signed `[width-1:0]` | Operand B |
| `acc` | output | signed `[ACC_WIDTH-1:0]` | Accumulator value |

## 2.4 Functional Requirements

### Reset

#### PE_RST_001

`rst_n` shall be active-low and asynchronously asserted.

#### PE_RST_002

When `rst_n` is asserted low, the accumulator register shall be cleared to
zero without waiting for a rising edge of `clk`.

#### PE_RST_003

The accumulator shall remain zero while `rst_n` remains asserted.

#### PE_RST_004

Reset shall have higher priority than Clear, MAC, and Hold operations.

### Clear

#### PE_CLR_001

`clear` shall be sampled on the rising edge of `clk` when `rst_n` is high.

#### PE_CLR_002

If `clear=1` at a rising edge of `clk`, the accumulator shall be updated to
zero.

#### PE_CLR_003

The accumulator shall be updated to zero on every rising edge for which
`clear=1` and `rst_n=1`.

#### PE_CLR_004

Clear shall have higher priority than MAC and Hold operations.

### MAC

#### PE_MAC_001

If `rst_n=1`, `clear=0`, and `valid=1` at a rising edge of `clk`, the PE
shall execute one MAC operation.

#### PE_MAC_002

The multiplication of `a_in` and `b_in` shall use signed arithmetic.

#### PE_MAC_003

The multiplication result shall have a width of `2*width` bits.

#### PE_MAC_004

The signed product shall be sign-extended to `ACC_WIDTH` before accumulation.

#### PE_MAC_005

The accumulator update shall be:

```text
acc_next = acc_current + sign_extend(a_in * b_in, ACC_WIDTH)
```

#### PE_MAC_006

The accumulator shall use fixed-width two's-complement arithmetic. A result
outside the `ACC_WIDTH` signed range shall wrap around; saturation and an
overflow indication are not implemented.

### Hold

#### PE_HOLD_001

If `rst_n=1`, `clear=0`, and `valid=0` at a rising edge of `clk`, the
accumulator shall retain its previous value.

### Output

#### PE_OUT_001

`acc` shall continuously reflect the internal accumulator register value.

## 2.5 Unsupported or Unspecified Behavior

- Saturation arithmetic is not supported.
- Overflow flag generation is not supported.
- X/Z input behavior is unspecified.
- Illegal parameter combinations are unspecified.

## 2.6 Current Verification Evidence

The formal harness in `formal/pe/pe_formal.sv` contains four proof tasks. The
committed formal artifacts report `PASS` for `reset`, `clear`, `mac`, and
`hold` at the configured PE parameters `N=8` and `width=8`.

| Requirement | Current evidence | Status |
| --- | --- | --- |
| `PE_RST_001` | RTL event control and interface inspection | Structural review |
| `PE_RST_002` | Reset proof observes zero at clock sampling points | Partially proven; asynchronous timing is not separately proven |
| `PE_RST_003` | `A_PE_RST_002_003` in reset proof | Directly proven at clock sampling points |
| `PE_RST_004` | `A_PE_RST_004` in reset proof | Directly proven at clock sampling points |
| `PE_CLR_001` | RTL clocked implementation | Structural review |
| `PE_CLR_002` | `A_PE_CLR_002_003` in clear proof | Directly proven |
| `PE_CLR_003` | `A_PE_CLR_002_003` in clear proof | Directly proven |
| `PE_CLR_004` | `A_PE_CLR_004` in clear proof | Directly proven |
| `PE_MAC_001` | `A_PE_MAC_001_002_003` in MAC proof | Directly proven by update equation |
| `PE_MAC_002` | Signed reference product used by MAC proof | Covered by MAC proof model |
| `PE_MAC_003` | `2*width` reference product used by MAC proof | Covered by MAC proof model |
| `PE_MAC_004` | Sign-extended reference product used by MAC proof | Covered by MAC proof model |
| `PE_MAC_005` | `A_PE_MAC_001_002_003` in MAC proof | Directly proven |
| `PE_MAC_006` | Fixed-width result is part of the MAC proof model | Covered indirectly; no separate overflow property |
| `PE_HOLD_001` | `A_PE_HOLD_001` in hold proof | Directly proven |
| `PE_OUT_001` | Continuous assignment in RTL | Structural review; no separate formal property |

These statuses describe the current evidence only. They are not a claim of
complete verification across every legal parameter configuration.

# 3. Systolic Array Controller

## 3.1 Overview

`sa_controller_NxN` controls one systolic-array matrix multiplication operation.

For each accepted start request, the controller shall perform the following phases in order:

```text
IDLE
→ CLEAR
→ COMPUTE
→ WAIT_DRAIN
→ DONE
→ IDLE
```

The controller does not process matrix data directly. It generates the control outputs:

* `clear`
* `valid_in`
* `done`

---

## 3.2 Parameters

| Parameter      | Default              | Description                                                     |
| -------------- | -------------------- | --------------------------------------------------------------- |
| `N`            | `8`                  | Matrix dimension and number of valid input cycles per operation |
| `DRAIN_MARGIN` | `10`                 | Additional drain latency in clock cycles                        |
| `DRAIN_CYCLES` | `2*N + DRAIN_MARGIN` | Total drain duration in clock cycles                            |

This specification requires:

```text
N >= 1
DRAIN_MARGIN >= 0
```

`CNT_W` is an implementation-sizing parameter and does not alter externally visible controller behavior.

---

## 3.3 Interface

| Signal     | Direction | Description                                                |
| ---------- | --------- | ---------------------------------------------------------- |
| `clk`      | input     | Controller clock. State transitions occur on rising edges. |
| `rst_n`    | input     | Active-low asynchronous reset.                             |
| `start`    | input     | Request to start one matrix multiplication operation.      |
| `clear`    | output    | Active-high processing-element clear command.              |
| `valid_in` | output    | Active-high indication that one input data cycle is valid. |
| `done`     | output    | Active-high completion indication.                         |

---

## 3.4 Reset Behavior

### CTRL_RST_001

`rst_n` shall be active-low and asynchronously asserted.

### CTRL_RST_002

When `rst_n` is asserted low, the controller shall immediately return to the `IDLE` phase.

### CTRL_RST_003

While reset is asserted:

```text
clear    = 0
valid_in = 0
done     = 0
```

### CTRL_RST_004

Reset shall have priority over all controller behavior.

A start request shall not be accepted while reset is asserted.

---

## 3.5 Start Acceptance

### CTRL_START_001

A start request shall be accepted only while the controller is in `IDLE`.

### CTRL_START_002

If `start` is sampled high at a rising edge while the controller is in `IDLE`, the controller shall enter `CLEAR` immediately after that edge.

### CTRL_START_003

A start request sampled while the controller is not in `IDLE` shall not alter the operation currently in progress.

### CTRL_START_004

`start` is level-sensitive while the controller is in `IDLE`.

If `start` remains high until the controller returns to `IDLE`, it shall be accepted again as a new request.

---

## 3.6 Clear Phase

### CTRL_CLR_001

After a start request is accepted, the controller shall enter `CLEAR`.

### CTRL_CLR_002

During `CLEAR`:

```text
clear    = 1
valid_in = 0
done     = 0
```

### CTRL_CLR_003

The clear phase shall last exactly one clock cycle.

### CTRL_CLR_004

After the clear phase completes, the controller shall enter `COMPUTE`.

---

## 3.7 Compute Phase

### CTRL_COMP_001

During `COMPUTE`:

```text
clear    = 0
valid_in = 1
done     = 0
```

### CTRL_COMP_002

The compute phase shall last exactly `N` consecutive clock cycles.

### CTRL_COMP_003

Immediately after the `N`th valid input cycle completes, the controller shall enter `WAIT_DRAIN`.

---

## 3.8 Wait Drain Phase

### CTRL_DRAIN_001

During `WAIT_DRAIN`:

```text
clear    = 0
valid_in = 0
done     = 0
```

### CTRL_DRAIN_002

The wait-drain phase shall last exactly `DRAIN_CYCLES` clock cycles.

### CTRL_DRAIN_003

After the wait-drain phase completes, the controller shall enter `DONE`.

---

## 3.9 Done Phase

### CTRL_DONE_001

During `DONE`:

```text
clear    = 0
valid_in = 0
done     = 1
```

### CTRL_DONE_002

The done phase shall last exactly one clock cycle.

### CTRL_DONE_003

After the done phase completes, the controller shall return to `IDLE`.

---

## 3.10 Idle Phase

### CTRL_IDLE_001

During `IDLE`:

```text
clear    = 0
valid_in = 0
done     = 0
```

### CTRL_IDLE_002

The controller shall remain in `IDLE` until a start request is accepted.

---

## 3.11 Operation Latency

Let `DRAIN_CYCLES = 2*N + DRAIN_MARGIN`. If a start request is accepted on
edge `E0`, the externally visible phases sampled after subsequent rising edges
are:

```text
E0                    CLEAR
E0 + 1                first COMPUTE cycle
E0 + N                final COMPUTE cycle
E0 + N + 1            first WAIT_DRAIN cycle
E0 + N + DRAIN_CYCLES final WAIT_DRAIN cycle
E0 + N + DRAIN_CYCLES + 1  DONE (`done=1`)
E0 + N + DRAIN_CYCLES + 2  IDLE
```

Equivalently, the pre-edge observation of `IDLE && start` and the observation
of `DONE && done` are separated by `N + DRAIN_CYCLES + 2` rising-edge samples,
which is the convention used by the embedded SVA latency property.

The implementation enum name `DONE_STATE` denotes the specified `DONE` phase;
it is not a separate externally visible phase.

---

## 3.12 Interface Limitation and Unspecified Behavior

The controller does not contain a request queue or pending-request register. A
`start` pulse that is asserted and then deasserted entirely while the
controller is busy is not retained. In contrast, a `start` level that remains
high when the controller is in `IDLE` is a current request and is accepted as
specified by `CTRL_START_004`.

The following behavior is intentionally unspecified:

* Invalid parameter values.
* X/Z behavior on inputs.
* Simultaneous reset deassertion and start assertion timing races.

---

# 4. Systolic Array

## 4.1 Overview

`systolic_arr_NxN` implements a parameterized `N × N` systolic array for signed
matrix multiplication.

The array contains `N × N` Processing Elements (PEs). Operand `A` enters from
the left boundary of each row and propagates from left to right. Operand `B`
enters from the top boundary of each column and propagates from top to bottom.

The input operands are skewed before entering the array so that the
corresponding `A[i][k]` and `B[k][j]` values arrive at `PE[i][j]` during the
same local-valid cycle.

`valid_in` is registered at `PE[0][0]`, propagates downward through column `0`,
and then propagates from left to right across each row. This produces a delayed
valid wavefront across the array.

Each PE performs a signed multiply-accumulate operation when its local valid
state is asserted:

```text
acc[i][j] = acc[i][j] + A_local[i][j] × B_local[i][j]
```

Under the operation protocol defined in Section 4.14, one `N × N` matrix
multiplication supplies exactly `N` consecutive valid input samples. Each PE
therefore performs exactly `N` valid MAC operations. After all in-flight
operands and valid state have drained through the array, output `c[i][j]`
represents the corresponding matrix result.

Reset and clear flush all operand pipeline state, local valid state, PE
accumulators, and array outputs.

---

## 4.2 Parameters

| Parameter   | Description                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------ |
| `N`         | Number of rows and columns in the systolic array. The array contains `N × N` PEs.                |
| `width`     | Signed bit width of each input operand in `a_in` and `b_in`.                                     |
| `ACC_WIDTH` | Signed accumulator and output width of every PE. Default: `2*width + ((N > 1) ? $clog2(N) : 1)`. |

The current primary configuration is:

```text
N         = 8
width     = 8
ACC_WIDTH = 19
```

---

## 4.3 Interface

| Port       | Direction | Type/Width                               | Description                                                                                                                           |
| ---------- | --------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `clk`      | Input     | `logic`                                  | Rising-edge clock for operand pipelines, valid propagation, and PE accumulation.                                                      |
| `rst_n`    | Input     | `logic`                                  | Active-low asynchronous reset.                                                                                                        |
| `valid_in` | Input     | `logic`                                  | Global input-valid signal. It is registered at `PE[0][0]` and propagated through the local-valid pipeline.                            |
| `clear`    | Input     | `logic`                                  | Active-high synchronous clear. It flushes operand pipelines, local valid state, PE accumulators, and outputs at the next rising edge. |
| `a_in[i]`  | Input     | signed `width` bits, `N` entries         | Operand-A input for row `i`.                                                                                                          |
| `b_in[j]`  | Input     | signed `width` bits, `N` entries         | Operand-B input for column `j`.                                                                                                       |
| `c[i][j]`  | Output    | signed `ACC_WIDTH` bits, `N × N` entries | Current accumulator/output value of `PE[i][j]`.                                                                                       |

---

## 4.4 Reset Behavior

### SARR_RST_001 — Reset polarity and assertion

`rst_n` shall be active-low and asynchronously asserted.

### SARR_RST_002 — Operand pipeline reset

When `rst_n` is asserted low, all internal state used to skew and propagate
operands `A` and `B` shall be cleared to zero without waiting for a rising edge
of `clk`.

### SARR_RST_003 — Valid-state reset

When `rst_n` is asserted low, all local valid state within the array shall be
cleared to zero without waiting for a rising edge of `clk`.

### SARR_RST_004 — PE and output reset

When `rst_n` is asserted low, every PE accumulator and corresponding output
`c[i][j]` shall be cleared to zero without waiting for a rising edge of `clk`.

### SARR_RST_005 — Reset-state retention

While `rst_n` remains asserted low, all operand pipeline state, valid state,
PE accumulators, and outputs shall remain in their reset state.

### SARR_RST_006 — Reset priority

Reset shall have priority over clear, operand propagation, valid propagation,
and PE accumulation.

---

## 4.5 Clear Behavior

### SARR_CLR_001 — Clear polarity and sampling

`clear` shall be active-high and synchronously sampled on the rising edge of
`clk`.

### SARR_CLR_002 — Operand pipeline clear

When `clear` is sampled high while `rst_n` is high, all state used to skew and
propagate operands `A` and `B` shall be cleared to zero.

### SARR_CLR_003 — Valid-state clear

When `clear` is sampled high while `rst_n` is high, all local valid state shall
be cleared to zero.

### SARR_CLR_004 — PE and output clear

When `clear` is sampled high while `rst_n` is high, every PE accumulator and
corresponding output `c[i][j]` shall be cleared to zero.

### SARR_CLR_005 — Clear-state retention

While `clear` remains high across successive rising edges and `rst_n` remains
high, all operand pipeline state, valid state, PE accumulators, and outputs
shall remain zero.

### SARR_CLR_006 — Clear priority

Reset shall have priority over clear. When reset is inactive, clear shall have
priority over operand propagation, valid propagation, and PE accumulation.

---

## 4.6 Operand-A Skew and Propagation

### SARR_A_001 — Entry direction

For each row `i`, operand `A` shall enter the array at `PE[i][0]` and propagate
from left to right through increasing column indices.

### SARR_A_002 — Row skew

Operand `a_in[i]` sampled on a rising edge shall reach `PE[i][0]` after exactly
`i + 1` rising clock edges.

### SARR_A_003 — One-hop propagation

When reset and clear are inactive, an operand-A value at `PE[i][j]` shall
propagate to `PE[i][j+1]` on the next rising edge, for every `j < N-1`.

### SARR_A_004 — Valid independence

Operand-A skew and propagation shall not be gated by local valid state. Reset
or clear may flush the operand pipeline.

---

## 4.7 Operand-B Skew and Propagation

### SARR_B_001 — Entry direction

For each column `j`, operand `B` shall enter the array at `PE[0][j]` and
propagate from top to bottom through increasing row indices.

### SARR_B_002 — Column skew

Operand `b_in[j]` sampled on a rising edge shall reach `PE[0][j]` after exactly
`j + 1` rising clock edges.

### SARR_B_003 — One-hop propagation

When reset and clear are inactive, an operand-B value at `PE[i][j]` shall
propagate to `PE[i+1][j]` on the next rising edge, for every `i < N-1`.

### SARR_B_004 — Valid independence

Operand-B skew and propagation shall not be gated by local valid state. Reset
or clear may flush the operand pipeline.

---

## 4.8 Valid Propagation

### SARR_VAL_001 — Valid entry

`valid_in` shall be synchronously registered into the local valid state of
`PE[0][0]`.

### SARR_VAL_002 — First-column propagation

When reset and clear are inactive, local valid state shall propagate downward
through column `0`, from `PE[i-1][0]` to `PE[i][0]`, on the next rising edge,
for every `i > 0`.

### SARR_VAL_003 — Row propagation

When reset and clear are inactive, local valid state shall propagate from left
to right across each row, from `PE[i][j-1]` to `PE[i][j]`, on the next rising
edge, for every `j > 0`.

### SARR_VAL_004 — Valid latency

A `valid_in` value sampled on a rising edge shall reach `PE[i][j]` after
exactly:

```text
i + j + 1
```

rising clock edges.

### SARR_VAL_005 — Valid pulse width

A contiguous `valid_in` assertion lasting `M` cycles shall produce a contiguous
local-valid assertion lasting `M` cycles at every PE, delayed according to that
PE's position.

### SARR_VAL_006 — Reset and clear effect

Reset shall asynchronously clear all local valid state. Clear shall
synchronously clear all local valid state and shall prevent valid propagation
on the edge where clear is sampled high.

---

## 4.9 Operand and Valid Alignment

### SARR_ALIGN_001 — A alignment

When local valid at `PE[i][j]` is asserted, the local operand A shall equal
`a_in[i]` sampled exactly `i + j + 1` rising edges earlier.

### SARR_ALIGN_002 — B alignment

When local valid at `PE[i][j]` is asserted, the local operand B shall equal
`b_in[j]` sampled exactly `i + j + 1` rising edges earlier.

### SARR_ALIGN_003 — Operand pairing

When local valid is asserted at `PE[i][j]`, the local operands A and B shall
correspond to the same original input sample cycle.

### SARR_ALIGN_004 — Invalid behavior

When local valid is low while reset and clear are inactive, the PE accumulator
shall not be modified even though operands may continue to propagate through
the array.

---

## 4.10 MAC Behavior

### SARR_MAC_001 — Local MAC enable

When reset is inactive, clear is low, and local valid at `PE[i][j]` is high,
that PE shall perform one signed multiply-accumulate operation on the local A
and B operands at the rising edge of `clk`.

### SARR_MAC_002 — MAC count

For an operation that follows Section 4.14 and supplies exactly `N` consecutive
valid input samples, every PE shall receive exactly `N` consecutive local-valid
cycles and shall therefore perform exactly `N` MAC operations.

### SARR_MAC_003 — Partial accumulation

After the `m`-th valid MAC operation, where `1 ≤ m ≤ N`, the accumulator shall
equal the fixed-width sum of the first `m` valid products received by that PE.

### SARR_MAC_004 — Final result

After the `N`-th valid MAC operation, output `c[i][j]` shall equal:

```text
C[i][j] = Σ A[i][k] × B[k][j], for k = 0 ... N-1
```

subject to signed fixed-width two's-complement wraparound at `ACC_WIDTH`.

### SARR_MAC_005 — Hold

When local valid is low while reset and clear are inactive, the accumulator
and output `c[i][j]` shall retain their previous value.

---

## 4.11 Completion and Drain Behavior

### SARR_TIME_001 — First completed PE

`PE[0][0]` shall be the first PE to complete its `N` valid MAC operations.

### SARR_TIME_002 — Last completed PE

`PE[N-1][N-1]` shall be the last PE to complete its `N` valid MAC operations.

### SARR_TIME_003 — In-flight data

After `valid_in` is deasserted, operand and local-valid values already present
inside the array shall continue propagating until all in-flight data has been
processed.

### SARR_TIME_004 — Array completion

The complete array result shall be considered valid only after
`PE[N-1][N-1]` completes its `N`-th valid MAC operation.

---

## 4.12 Output Behavior

### SARR_OUT_001 — Direct accumulator output

Each output `c[i][j]` shall directly reflect the current accumulator value of
`PE[i][j]`.

### SARR_OUT_002 — Stable hold

When reset, clear, and local valid are inactive, output `c[i][j]` shall retain
its previous value.

### SARR_OUT_003 — Post-operation stability

After an operation completes, all outputs shall remain stable until reset,
clear, or a subsequent valid MAC operation modifies the corresponding
accumulator.

---

## 4.13 Parameterization

### SARR_PARAM_001 — Array dimensions

The implementation shall instantiate exactly `N × N` PEs.

### SARR_PARAM_002 — Operand width

All A and B operands shall use signed `width`-bit representation.

### SARR_PARAM_003 — Accumulator width

All PE accumulators and outputs shall use signed `ACC_WIDTH`-bit
representation.

### SARR_PARAM_004 — Positional latency

For every legal PE coordinate:

```text
0 ≤ i < N
0 ≤ j < N
```

the latency of A, B, and valid from the corresponding array input to
`PE[i][j]` shall be exactly:

```text
i + j + 1 rising clock edges
```

---

## 4.14 Operation Protocol and Isolation

The matrix-level requirements in Sections 4.10 and 4.11 apply when the array
is driven with the following protocol. The array itself has no `start`, `done`,
or backpressure port and does not enforce this protocol independently.

### SARR_OP_001 — Initial cleared state

Before the first valid sample of a new matrix operation, `clear` shall be
sampled high for at least one rising edge so that operand pipeline state, local
valid state, and all PE accumulators are cleared.

### SARR_OP_002 — No stale contribution

Data remaining from a previous operation shall not contribute to the result of
a later operation.

### SARR_OP_003 — First MAC after clear

The first valid MAC operation at every PE after clear shall begin from an
accumulator value of zero.

---

## 4.15 Out of Scope

The following behaviors are outside the current SARR specification:

* saturation arithmetic;
* overflow indication;
* X/Z input behavior;
* illegal parameter combinations;
* independent backpressure at individual PEs;
* matrix operations whose `valid_in` stream contains bubbles (the array can
  propagate bubbles, but the current controller generates `N` consecutive
  valid cycles);
* multiple overlapping matrix operations.
