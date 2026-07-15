# NPU Functional Specification

Version: 0.4
Status: Draft

---

# 1. Scope

This revision specifies the functional behavior of the following blocks:

- Processing Element (PE), implemented in `rtl/pe.sv`.
- Systolic Array Controller, implemented in `rtl/sa_controller_NxN.sv`.

The following RTL blocks exist but are outside the scope of this specification
revision and will be documented later:

- Systolic Array
- NPU Top
- APB Wrapper

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
