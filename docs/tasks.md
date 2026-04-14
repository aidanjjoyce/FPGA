> **Agent instructions:** At the start of each session, ask the user which phase or task they want to work on. Work through the relevant items. When you believe a task is complete, ask the user to confirm before marking it done. Once confirmed, update the checkbox in this file from `- [ ]` to `- [x]`.

---

# FPGA Calculator — Task Tracker

Reference: `plan.md` has full architecture details, code samples, and diagrams for each phase.

---

## Phase 0 — Learn Verilog

**Learn concepts** (read / experiment as you go)
- [x] Modules, port lists, `input` / `output` / `wire` / `reg`
- [x] Continuous assignment (`assign`) and bitwidths
- [x] `always @(posedge clk)` and `always @(*)` blocks
- [x] `if/else` and `case/endcase` inside always blocks
- [x] Non-blocking `<=` vs blocking `=`
- [x] Module instantiation
- [x] Operators: bitwise (`&`, `|`, `^`, `~`), arithmetic (`+`, `-`), ternary (`?:`)
- [ ] Operators: comparison (`==`, `!=`, `<`, `>`), shift (`<<`, `>>`)

**Install tools**
- [x] Install Icarus Verilog

**Practice exercises** (write each by hand and verify with Icarus)
- [x] `and_gate.v` — 2-input AND via continuous assign
- [x] `mux2.v` — 2-to-1 mux via ternary operator
- [x] `half_adder.v` — sum and carry
- [x] `full_adder.v` — instantiate two half adders structurally
- [x] `dff.v` — D flip-flop with synchronous reset
- [x] `counter4.v` — 4-bit counter with clocked always block
- [x] `alu8.v` — 8-bit ALU: add, sub, AND, OR with 2-bit op select

- [x] **MILESTONE:** `alu8.v` produces correct output via Icarus testbench (12+7=19, 20-4=16)

---

## Phase 1 — Netlist Model + Simulator

> Architecture decisions for this phase are discussed and recorded in `architecture.md`
> before implementation. That file is the authoritative interface reference.

**Data structures** (`fpga_sim/netlist.py`)
- [x] Implement `LUT` dataclass (id, truth_table, input_wires, output_wire)
- [ ] Implement `DFF` dataclass (id, d_wire, q_wire, clk_wire, reset_wire, reset_val)
- [ ] Implement `Netlist` dataclass (luts, dffs, wires, inputs, outputs)

**Simulator engine** (`fpga_sim/simulator.py`)
- [ ] Implement `evaluate_lut()` — index truth table from wire values
- [ ] Implement `simulate_step()` — LUT evaluation to convergence, then DFF latch on rising edge

**Serialisation** (methods on `Netlist`)
- [ ] Implement `schema()` — static topology (luts, dffs, inputs, outputs)
- [ ] Implement `snapshot()` — dynamic wire state (wires, lut_outputs, dff_outputs)

- [ ] **MILESTONE:** Hardcoded 2-bit counter (4 LUTs + 2 DFFs) clocked 8 times prints 00→01→10→11→00

**Unit tests** (`tests/` with pytest — build netlists directly in Python, no parsing)
- [ ] `test_lut.py` — `evaluate_lut` for AND, OR, XOR, NOT truth tables; correct index calculation
- [ ] `test_dff.py` — DFF latches D→Q only on rising edge; reset holds value; simultaneous DFFs latch together
- [ ] `test_simulator.py` — LUT-only netlist converges; mixed LUT+DFF netlist steps correctly
- [ ] `test_half_adder.py` — hardcoded half-adder netlist: all four input combos correct
- [ ] `test_full_adder.py` — hardcoded full-adder netlist: all eight input combos correct
- [ ] `test_alu.py` — hardcoded ALU netlist: spot-check add, sub, AND, OR with known values

---

## Phase 2 — Verilog Parser

**Install tools**
- [ ] `pip install lark fastapi uvicorn`

**Stage 2a — Combinational only**
- [ ] Lark grammar: `module`/`endmodule`, `input`/`output`/`wire` declarations (1-bit)
- [ ] Parse `assign` with `&`, `|`, `^`, `~`, ternary `?:`
- [ ] Synthesise each operator to a LUT with correct truth table

**Stage 2b — Multi-bit wires**
- [ ] `wire [N:0]` and `reg [N:0]` declarations
- [ ] Expand N-bit wire into N 1-bit wires named `wire[0]`, `wire[1]`, etc.
- [ ] Synthesise `+` and `-` as ripple-carry adder chains of full-adder LUTs

**Stage 2c — Sequential logic**
- [ ] `always @(posedge clk)` with non-blocking `<=`
- [ ] `if/else` and `case` inside clocked blocks
- [ ] Map each register to a DFF + combinational LUTs for next-state logic

- [ ] **MILESTONE:** Parse `alu8.v`, simulate with known inputs, assert outputs match Phase 0 Icarus results

---

## Phase 3 — Python Backend

**Server** (`backend/main.py`)
- [ ] FastAPI app with CORS middleware
- [ ] Instantiate simulator from `verilog/alu8.v` at startup
- [ ] `GET /netlist/schema` — return static topology (called once on page load)
- [ ] `POST /compute` — accept `{a, b, op}`, run simulator, return `{result, netlist_state}`

- [ ] **MILESTONE:** `curl POST /compute` with `{a:12, b:7, op:"add"}` returns `{"result": 19, "netlist_state": {...}}`

---

## Phase 4 — React Frontend

**Install tools**
- [ ] `npm create vite@latest frontend`

**Project setup**
- [ ] Vite + React project scaffolded
- [ ] Fetch wrappers for `/netlist/schema` and `/compute`

**Calculator data flow**
- [ ] Decide on unsigned vs signed display for subtraction results (e.g. 3−7 = 252 unsigned or show negative?)
- [ ] Cap input at 255; show a warning if the user types beyond the 8-bit range
- [ ] Map op buttons to op strings: `+` → `"add"`, `−` → `"sub"`, `&` → `"and"`, `|` → `"or"`

**App state**
- [ ] `useReducer` at App level with: display, pendingA, pendingOp, netlistState, loading

**Calculator panel** (`CalculatorPanel` → `Display` + `ButtonGrid`)
- [ ] Digit accumulation: each digit press appends to current number string, converts to integer on op/equals
- [ ] Op press: saves `pendingA` + `pendingOp`, clears display for next number entry
- [ ] `=` press: sends `{a: pendingA, b: currentNumber, op: pendingOp}` to `POST /compute`, updates display + netlistState
- [ ] Loading pulse on display during backend round-trip

**Circuit panel — schematic view** (`SchematicView`)
- [ ] Hand-authored SVG: Adder, Sub, AND, OR blocks + MUX + op select
- [ ] Wire and block colouring driven by `netlistState` (1 = blue, 0 = grey)
- [ ] Active operation block gets a highlighted border

**Circuit panel — netlist view** (`NetlistView`)
- [ ] `npm install elkjs`
- [ ] Fetch topology from `GET /netlist/schema` once on load, run ELK layout
- [ ] Each LUT/DFF rendered as a node card; edges as SVG paths
- [ ] Node/edge colouring updated from `netlistState` on each compute (no re-layout)
- [ ] Clicking a node shows a tooltip with its truth table

**View toggle**
- [ ] `ViewToggle` tab switches between Schematic and Netlist views

- [ ] **MILESTONE:** Press 1, 2, +, 7, = → display shows 19, schematic highlights adder block, netlist shows carry-chain LUTs lit

---

## Phase 5 — Polish

- [ ] **5a — Step-through mode:** "Step" button advances simulator one LUT evaluation at a time; netlist view updates after each step
- [ ] **5b — Accumulator register:** Add DFF to `alu8.v` for chained ops; schematic shows accumulator block with clock arrow
- [ ] **5c — Overflow indicator:** Add overflow output to `alu8.v`; surface as warning badge on display when result overflows 8 bits
- [ ] **5d — README:** Explain architecture (simulator, Verilog→LUT mapping, two views); consider a short screen recording
