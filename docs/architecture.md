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
