# NPU Functional Specification

Version: 0.2  
Status: Draft

---

# 1. Scope

This revision specifies the functional behavior of the Processing Element (PE)
implemented in `rtl/pe.sv`.

The following RTL blocks exist but are outside the scope of this specification
revision and will be documented later:

- Systolic Array
- Controller
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

