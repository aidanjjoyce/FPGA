# FPGA Calculator — Architecture Decisions

This file records interface decisions and rationale agreed during implementation discussion.
It supersedes any conflicting interface details in `plan.md`.

Each section is written as decisions are made — one component at a time.

---

## `LUT` dataclass (`fpga_sim/netlist.py`)

**What it represents:** A Look-Up Table — the primitive combinational logic element in an FPGA.
A LUT with N inputs stores 2^N output bits (one per possible input combination), allowing it
to implement any boolean function of N variables. In real FPGAs, each LUT produces a single
output bit.

**Fields:**

| Field | Type | Notes |
|---|---|---|
| `id` | `str` | Unique identifier within the netlist |
| `truth_table` | `list[int]` | 1D list of length 2^N; each entry is 0 or 1 |
| `input_wires` | `list[str]` | Wire IDs feeding the inputs; length implicitly defines N |
| `output_wire` | `str` | Wire ID the LUT drives |

**Why single output?** Real FPGA LUTs are single-output. Multiple outputs are modelled as
multiple LUTs. This keeps evaluation simple and faithful to hardware.

**Why no `num_inputs` field?** It is redundant — always derivable as `len(input_wires)`.
Storing it separately would require keeping the two in sync.

**Truth table indexing:** The input wire values are interpreted as a binary number where the
first wire in `input_wires` is the MSB. For example, with `input_wires = ["a", "b", "c"]`
and wire values `a=1, b=0, c=1`, the index is `0b101 = 5`, so the output is `truth_table[5]`.

**Validation:** `__post_init__` enforces `len(truth_table) == 2 ** len(input_wires)` and raises
`ValueError` if not. This mirrors the hardware constraint: N input wires require exactly 2^N
SRAM cells in the MUX tree — no more, no less.

**Connectivity model:** The LUT stores the wire IDs it is connected to (`input_wires`,
`output_wire`). The `Netlist` holds the current wire values in a `dict[str, int]`. Evaluation
reads from that dict using the LUT's stored IDs and writes the result back to `output_wire`.
This mirrors hardware: a physical LUT's pins are hardwired to specific nets at manufacture time.

---

## `DFF` dataclass (`fpga_sim/netlist.py`)

**What it represents:** A D flip-flop — the primitive sequential logic element in an FPGA.
A DFF captures the value on its data input `D` at the moment of a rising clock edge and holds
it on its output `Q` until the next rising edge. `Q` is continuously readable at all times;
it only changes at the clock edge.

In a real FPGA, DFFs are dedicated hardened registers built into each logic slice — they are
not implemented from LUTs. This is why they are modelled as a separate primitive rather than
as a LUT with a feedback wire.

**Fields:**

| Field | Type | Notes |
|---|---|---|
| `id` | `str` | Unique identifier within the netlist |
| `d_wire` | `str` | Data input wire ID |
| `q_wire` | `str` | Registered output wire ID |
| `clk_wire` | `str` | Clock input wire ID |
| `reset_wire` | `str` | Synchronous active-high reset wire ID |

**Behaviour:** On a rising clock edge (`clk 0→1`):
- If `reset = 1`: `Q ← 0`
- If `reset = 0`: `Q ← D`
- At all other times: `Q` unchanged

**Why synchronous reset?** Our `dff.v` uses `always @(posedge clk)` with `if (rst)` inside —
the reset is checked only at the clock edge, not continuously. This is the simpler model and
matches the Verilog we are simulating.

**Why `reset_wire` is required:** In real hardware many DFFs omit reset to save routing
resources. In our simulator, if a DFF needs no reset, wire `reset_wire` to a net held
permanently at `0`. This keeps the dataclass uniform — every DFF has the same fields.

**Why `clk_wire` is stored:** The simulator's `simulate_step(netlist, clk)` takes clock as
an external parameter rather than reading it from the wires dict — we cannot simulate
continuous time, so clock transitions are explicit events. However, `clk_wire` is stored for
topology accuracy: `schema()` can report which net each DFF's clock pin connects to, which
the frontend visualiser will use to draw clock connections.

**Connectivity model:** Identical to LUT — the DFF stores wire IDs; the `Netlist` holds
current wire values in `dict[str, int]`. The simulator reads `d_wire` and `reset_wire` from
that dict and writes back to `q_wire` on a rising edge.

---

## `Netlist` dataclass (`fpga_sim/netlist.py`)

**What it represents:** The complete circuit — all components and the current value of every
signal. It is the single object the simulator operates on and the backend serialises.

**Fields:**

| Field | Type | Notes |
|---|---|---|
| `luts` | `list[LUT]` | All LUTs in the circuit |
| `dffs` | `list[DFF]` | All DFFs in the circuit |
| `wires` | `dict[str, int]` | Current value (0 or 1) of every named signal |
| `inputs` | `list[str]` | Wire IDs that are primary inputs (driven from outside) |
| `outputs` | `list[str]` | Wire IDs that are primary outputs (read from outside) |

**Why `list` for components but `dict` for wires?** The simulator always iterates all LUTs
and DFFs in full — it never needs to find one by ID during simulation. A list is sufficient
and avoids duplicating the ID that is already stored on each object. Wire values are accessed
by name on every LUT input evaluation and every DFF latch, so keyed O(1) lookup justifies a
dict.

**Connectivity model:** Wires are named signals with a current value — not explicit edges
between components. Topology is encoded in the components themselves (`input_wires`,
`output_wire` on LUT; `d_wire`, `q_wire` etc. on DFF). To find what drives a wire, inspect
the component that names it as its output.

**`schema()` — static topology:** Returns the fixed structure of the circuit, called once
by the frontend on page load. Includes all LUT/DFF fields needed for visualisation.

**`snapshot()` — dynamic state:** Returns `{"wires": dict}` — the current value of every
signal. The frontend can read any component's output directly from `wires` using the wire ID
stored on the component, so separate `lut_outputs`/`dff_outputs` keys are redundant.

**Why serialisation methods live on `Netlist`, not on `LUT`/`DFF`:** `LUT` and `DFF` are
pure data structures with no knowledge of JSON or HTTP. Serialisation is a transport concern.
`Netlist` exposes `_lut_to_dict()` and `_dff_to_dict()` as private helpers, keeping the
conversion logic close to where it is used without polluting the primitives.

**When to use these methods:** Only at the HTTP boundary (Phase 3 backend). Inside Python —
in the simulator and in tests — access `netlist.luts`, `netlist.dffs`, and `netlist.wires`
directly.

---

## `evaluate_lut()` (`fpga_sim/simulator.py`)

**What it does:** Evaluates a single LUT against the current wire state and writes the result back.

**Signature:** `evaluate_lut(lut: LUT, wires: dict[str, int]) -> None`

**Algorithm:**
1. Read each wire ID in `lut.input_wires` from `wires`
   → produces an ordered list of 0/1 values
2. Compute a binary index from those values, MSB-first
   (first wire = most significant bit)
3. Look up `lut.truth_table[index]`
4. Write the result to `wires[lut.output_wire]`

**Index calculation:** MSB-first means wire `i` contributes bit `(N-1-i)`:
```
index |= wire_values[i] << (N - 1 - i)
```
For `input_wires = ["a", "b", "c"]` with values `a=1, b=0, c=1`:
index = `0b101 = 5`. Matches the indexing convention defined on `LUT`.

**Mutation over return:** `wires` is mutated in place.
Returning a new dict on every call would be wasteful in the convergence loop
inside `simulate_step`.

**Scope — single LUT only:** Iteration over all LUTs lives in `simulate_step`.
This keeps `evaluate_lut` small and directly unit-testable.

**Error handling:** A missing wire ID raises `KeyError` naturally.
This indicates a malformed netlist and should be caught by `Netlist`
structural validation (see tasks.md), not here.

---

## `simulate_step()` and helpers (`fpga_sim/simulator.py`)

**What it does:** Advances the circuit by one time step —
settles combinational logic then latches sequential state.

**Signature:**
`simulate_step(netlist: Netlist, input_values: dict[str, int], rising_edge: bool) -> None`

**Algorithm:**
1. Write `input_values` into `netlist.wires`
2. Call `_evaluate_luts_to_convergence(netlist)`
3. If `rising_edge`: call `_latch_dffs(netlist)`

**Why `rising_edge: bool` rather than passing clock values?**
The caller owns the clock signal and is responsible for detecting the `0→1`
transition. Passing a boolean keeps `simulate_step` free of clock-edge
detection logic.

---

### `_evaluate_luts_to_convergence(netlist)`

Repeatedly evaluates all LUTs until the wire state stabilises.

**Algorithm:** Each iteration snapshots `netlist.wires`, evaluates every LUT
via `evaluate_lut`, then compares the new state to the snapshot. Returns on
the first pass with no changes. Raises `RuntimeError` if convergence is not
reached within `MAX_ITERATIONS` (1000), indicating a combinational feedback
loop in the netlist.

**Why iterative relaxation over topological sort?**
Simpler to implement and correct for any LUT ordering. Topological sort would
require analysis at construction time; relaxation handles it naturally at
simulation time.

---

### `_latch_dffs(netlist)`

Latches all DFFs simultaneously on a rising clock edge.

**Algorithm:** First pass collects all next-Q values into a temporary dict
(reading `d_wire`, or 0 if `reset_wire` is high). Second pass writes them all
to `netlist.wires`. The two-pass approach ensures simultaneity — if DFF A's
`q_wire` feeds DFF B's `d_wire`, B captures A's pre-edge value, not A's new
post-edge value.

**Reset:** Synchronous active-high. If `wires[dff.reset_wire] == 1` at the
clock edge, `q_wire` is set to 0 regardless of `d_wire`.

---
