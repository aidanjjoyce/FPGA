# FPGA Calculator — Project Plan

## Goal

Build a web application with two panels: a working calculator on the left, and a live circuit
diagram on the right. Every button press on the calculator drives a real software FPGA simulator
running in a Python backend — the result you see came out of simulated LUTs and flip-flops, not
JavaScript arithmetic. The circuit diagram shows what is happening inside that simulation,
with a high-level schematic view and a zoomable raw netlist view.

This is a portfolio piece. The interesting claim it makes is: *the calculator is powered by a
hardware simulator I wrote from scratch*.

**Timeline:** 6–8 weeks part-time (~2–3 hours per session).

**Languages:** Python (simulator + backend), React (frontend).

---

## Architecture

```
Browser (React)
  ├── Calculator panel     — number/op buttons, result display
  └── Circuit panel        — schematic view + raw netlist view
          ↕  JSON over HTTP
Python backend (FastAPI)
  └── fpga_sim/            — your simulator, used as a library
        ├── netlist.py
        ├── simulator.py
        ├── parser.py
        └── synthesiser.py
```

The backend exposes one main endpoint:

```
POST /compute
  body:  { "a": 12, "b": 7, "op": "add" }
  reply: { "result": 19, "netlist_state": { ... } }
```

`netlist_state` is a serialised snapshot of every wire value, LUT, and DFF in the circuit
after the computation. The frontend uses this to colour the circuit diagram.

---

## Phase 0 — Learn enough Verilog (Week 1)

You need a working subset only. Focus on synthesisable RTL; ignore simulation-only constructs
(`$display`, `#delays`, testbench idioms) — those are not part of the language you will be parsing.

### Concepts to learn

**Basics**
- Modules: `module`, `endmodule`, port lists (`input`, `output`, `wire`, `reg`)
- Net types: `wire` vs `reg` and when each is used
- Continuous assignment: `assign y = a & b;`
- Bitwidths: `wire [7:0] bus;`, part-selects `bus[3:0]`

**Behavioural blocks**
- `always @(posedge clk)` — clocked (sequential) logic
- `always @(*)` — combinational logic
- `if / else`, `case / endcase` inside always blocks
- Non-blocking `<=` (use in clocked blocks) vs blocking `=` (use in combinational)

**Structural composition**
- Module instantiation: `and_gate u1 (.a(x), .b(y), .out(z));`

**Operators to know**
- Bitwise: `&`, `|`, `^`, `~`
- Arithmetic: `+`, `-`
- Comparison: `==`, `!=`, `<`, `>`
- Shift: `<<`, `>>`
- Conditional (ternary): `assign out = sel ? a : b;`

### Practice exercises

Write each of these by hand and verify with Icarus Verilog. These are not throwaway exercises —
exercises 3–7 are the building blocks of your final ALU.

1. `and_gate.v` — 2-input AND from a continuous assign
2. `mux2.v` — 2-to-1 mux using the ternary operator
3. `half_adder.v` — sum and carry from two inputs
4. `full_adder.v` — instantiate two half adders structurally
5. `dff.v` — D flip-flop with synchronous reset
6. `counter4.v` — 4-bit counter using a clocked always block
7. `alu8.v` — 8-bit ALU: add, subtract, AND, OR selected by a 2-bit op code

Exercise 7 is your target circuit. Everything in the project exists to parse, simulate,
and visualise this one file.

### Tools to install now

```
pip install lark fastapi uvicorn     # parser + backend
npm create vite@latest frontend      # React frontend
brew install icarus-verilog          # (or: apt install iverilog)
```

Use Icarus Verilog to check your hand-written Verilog before writing the simulator:

```verilog
module tb;
  reg [7:0] a, b;
  reg [1:0] op;
  wire [7:0] result;
  alu8 uut (.a(a), .b(b), .op(op), .result(result));
  initial begin
    a=8'd12; b=8'd7; op=2'b00; #10;  // expect 19
    a=8'd20; b=8'd4; op=2'b01; #10;  // expect 16
    $finish;
  end
endmodule
```

---

## Phase 1 — Build the netlist model (Week 1–2)

> **Note:** Specific interface decisions for Phase 1 are recorded in `architecture.md`,
> agreed through discussion before implementation. That file supersedes any conflicting
> interface details in the code samples below.
>
> Key differences from the samples below: `LUT` has no `num_inputs` field and adds
> `output_wire`; `DFF.reset_wire` is required (not optional); `Netlist.luts`/`dffs` are
> lists not dicts; `evaluate_lut` mutates `wires` in place and returns `None`;
> `simulate_step` takes `rising_edge: bool` not `clk: int`; `snapshot()` returns only
> `{"wires": ...}` with no separate `lut_outputs`/`dff_outputs` keys.

Build the data structures and simulation engine first, before any parsing. This is the core of
the project; the parser and web app are layers on top of it.

### Core data structures

```python
from dataclasses import dataclass, field

@dataclass
class LUT:
    id: str
    num_inputs: int          # usually 4
    truth_table: list[int]   # 2^num_inputs bits
    input_wires: list[str]   # names of driving wires

@dataclass
class DFF:
    id: str
    d_wire: str
    q_wire: str
    clk_wire: str
    reset_wire: str | None
    reset_val: int

@dataclass
class Netlist:
    luts: dict[str, LUT]     = field(default_factory=dict)
    dffs: dict[str, DFF]     = field(default_factory=dict)
    wires: dict[str, int]    = field(default_factory=dict)
    inputs: list[str]        = field(default_factory=list)
    outputs: list[str]       = field(default_factory=list)
```

### The simulator engine

```python
def evaluate_lut(lut: LUT, wires: dict[str, int]) -> int:
    index = 0
    for i, wire in enumerate(lut.input_wires):
        index |= wires.get(wire, 0) << i
    return lut.truth_table[index]

def simulate_step(netlist: Netlist, clk: int) -> None:
    # 1. Evaluate all LUTs to convergence
    changed = True
    while changed:
        changed = False
        for lut in netlist.luts.values():
            val = evaluate_lut(lut, netlist.wires)
            if netlist.wires.get(lut.id) != val:
                netlist.wires[lut.id] = val
                changed = True

    # 2. On rising edge, latch all DFFs simultaneously
    if clk == 1:
        new_q = {dff.q_wire: netlist.wires.get(dff.d_wire, 0)
                 for dff in netlist.dffs.values()}
        netlist.wires.update(new_q)
```

### Netlist serialisation

Add two methods to `Netlist` that the backend will call:

```python
def schema(self) -> dict:
    """Static topology — fetched once on page load."""
    return {
        "luts": {id: {"inputs": l.input_wires, "truth_table": l.truth_table}
                 for id, l in self.luts.items()},
        "dffs": {id: {"d": d.d_wire, "q": d.q_wire}
                 for id, d in self.dffs.items()},
        "inputs": self.inputs,
        "outputs": self.outputs,
    }

def snapshot(self) -> dict:
    """Dynamic wire state — returned after every computation."""
    return {
        "wires": dict(self.wires),
        "lut_outputs": {id: self.wires.get(id, 0) for id in self.luts},
        "dff_outputs": {id: self.wires.get(d.q_wire, 0)
                        for id, d in self.dffs.items()},
    }
```

### Milestone: manually simulated counter

Hardcode a 2-bit counter netlist (4 LUTs + 2 DFFs) in Python and clock it 8 times.
Print wire states each tick. If it counts 00→01→10→11→00 you are on track.

### Unit tests

Write a `tests/` directory with `pytest`. Test each primitive in isolation before
building the parser on top of them. These tests are your safety net for Phase 2.

| Test file | What it covers |
|---|---|
| `test_lut.py` | `evaluate_lut` for AND, OR, XOR, NOT truth tables; correct index calculation |
| `test_dff.py` | DFF latches D→Q only on rising edge; reset holds value; simultaneous DFFs latch together |
| `test_simulator.py` | LUT-only combinational netlist converges correctly; mixed LUT+DFF netlist steps correctly |
| `test_half_adder.py` | Hardcoded half-adder netlist: all four input combinations produce correct sum and carry |
| `test_full_adder.py` | Hardcoded full-adder netlist: all eight input combinations correct |
| `test_alu.py` | Hardcoded ALU netlist: spot-check add, sub, AND, OR with known values |

Keep tests small and self-contained — no file I/O, no parsing. Each test builds its netlist
directly in Python using the dataclasses.

---

## Phase 2 — Parse a Verilog subset (Week 2–3)

Build a parser that reads Verilog source and produces an AST, then walk the AST to synthesise
a Netlist your Phase 1 engine can simulate.

### Parser: Lark (PEG grammar)

```python
from lark import Lark, Transformer

GRAMMAR = r"""
    start: module+
    module: "module" NAME "(" port_list ")" ";" item* "endmodule"
    port_list: port ("," port)*
    port: direction? NAME
    direction: "input" | "output"
    item: wire_decl | reg_decl | assign_stmt | always_block | instance
    wire_decl: "wire" range? NAME ";"
    reg_decl:  "reg"  range? NAME ";"
    range: "[" INT ":" INT "]"
    assign_stmt: "assign" lvalue "=" expr ";"
    lvalue: NAME | NAME "[" INT "]"
    expr: NAME                        -> wire_ref
        | INT                         -> literal
        | expr "&"  expr              -> and_expr
        | expr "|"  expr              -> or_expr
        | expr "^"  expr              -> xor_expr
        | "~" expr                    -> not_expr
        | expr "+"  expr              -> add_expr
        | expr "-"  expr              -> sub_expr
        | expr "?"  expr ":" expr     -> mux_expr
        | "(" expr ")"
    always_block: "always" sensitivity "begin" stmt* "end"
    sensitivity: "@" "(" "posedge" NAME ")" | "@" "(" "*" ")"
    stmt: if_stmt | case_stmt | nb_assign
    nb_assign: lvalue "<=" expr ";"
    if_stmt: "if" "(" expr ")" stmt ("else" stmt)?
    case_stmt: "case" "(" expr ")" case_item+ "endcase"
    case_item: (expr | "default") ":" stmt
    instance: NAME NAME "(" port_conn ("," port_conn)* ")" ";"
    port_conn: "." NAME "(" NAME ")"
    %import common.CNAME -> NAME
    %import common.INT
    %import common.WS
    %import common.CPP_COMMENT
    %ignore WS
    %ignore CPP_COMMENT
"""
```

### Build in three stages

**Stage 2a — combinational only**
- `module` / `endmodule`, `input` / `output` / `wire` declarations (1-bit)
- `assign` with `&`, `|`, `^`, `~`, ternary `?:`
- Map each operator to a LUT

**Stage 2b — multi-bit wires (required for the ALU)**
- `wire [N:0]` and `reg [N:0]` declarations
- Internally expand an N-bit wire into N 1-bit wires named `wire[0]`, `wire[1]`, etc.
- Arithmetic `+` and `-` synthesise as ripple-carry adder chains of full-adder LUTs

**Stage 2c — sequential logic**
- `always @(posedge clk)` with non-blocking `<=`
- `if/else` and `case` inside clocked blocks
- Map each register to a DFF + combinational LUTs for next-state logic

### Synthesis table

| Verilog construct | Synthesises to |
|---|---|
| `assign y = a & b` | 1× LUT (AND truth table) |
| `assign y = sel ? a : b` | 1× LUT (MUX truth table) |
| `assign y = a + b` (8-bit) | 8× full-adder LUT chains |
| `always @(posedge clk) q <= d` | 1× DFF |
| `always @(posedge clk) if(rst) q<=0; else q<=d;` | 1× DFF + 1× MUX LUT |
| `case (op) ... endcase` | tree of MUX LUTs |

### Milestone: parse and simulate `alu8.v`

Parse your hand-written ALU, synthesise it, run it through the simulator with known inputs,
and assert the outputs match your Icarus Verilog results from Phase 0.

---

## Phase 3 — Python backend (Week 3–4)

Wrap the simulator in a small FastAPI server. Keep this layer thin — all logic stays in
`fpga_sim/`, the server just exposes it over HTTP.

### Server

```python
# backend/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fpga_sim.simulator import Simulator

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"])

sim = Simulator("verilog/alu8.v")   # parsed and synthesised at startup

OP_CODES = {"add": 0b00, "sub": 0b01, "and": 0b10, "or": 0b11}

class ComputeRequest(BaseModel):
    a: int
    b: int
    op: str

@app.get("/netlist/schema")
def netlist_schema():
    # Static topology — frontend fetches this once on load
    return sim.netlist.schema()

@app.post("/compute")
def compute(req: ComputeRequest):
    sim.reset()
    sim.set("a", req.a)
    sim.set("b", req.b)
    sim.set("op", OP_CODES[req.op])
    sim.tick()
    return {
        "result": sim.get("result"),
        "netlist_state": sim.netlist.snapshot()
    }
```

`GET /netlist/schema` returns the fixed topology once on page load so the frontend can build
its graph layout. `POST /compute` returns only dynamic wire values on each calculation.
Keeping these separate means the frontend never re-runs layout on every keypress.

### Milestone: curl the backend

```bash
uvicorn backend.main:app --reload

curl -X POST http://localhost:8000/compute \
  -H "Content-Type: application/json" \
  -d '{"a": 12, "b": 7, "op": "add"}'
# → {"result": 19, "netlist_state": {...}}
```

---

## Phase 4 — React frontend (Week 4–6)

### Calculator-to-FPGA data flow

The frontend is responsible for accumulating digit presses into numbers and deciding when to call the backend. The FPGA knows nothing about "pressing buttons" — it only ever sees two 8-bit integers and a 2-bit op code.

**Number accumulation** — the reducer builds the current number digit-by-digit:
```
press 1  →  display = "1",  pendingA = null
press 2  →  display = "12", pendingA = null
press +  →  pendingA = 12,  pendingOp = "add", display clears for next number
press 7  →  display = "7"
press =  →  POST /compute { a: 12, b: 7, op: "add" }
            display = "19"
```

**Constraints from 8-bit arithmetic:**
- Valid input range: 0–255. If a user types a number > 255, cap it and show a warning.
- Subtraction wraps (unsigned): 3 − 7 = 252. Decide upfront whether to treat this as unsigned or show a negative indicator.
- Results > 255 trigger the overflow indicator (Phase 5c).

**Op code mapping** (matches `alu8.v` encoding):

| Button | `op` string | 2-bit code sent to simulator |
|--------|-------------|------------------------------|
| `+`    | `"add"`     | `0b00`                       |
| `−`    | `"sub"`     | `0b01`                       |
| `&`    | `"and"`     | `0b10`                       |
| `\|`   | `"or"`      | `0b11`                       |

The frontend never computes the result itself. Every `=` press is a real round-trip to the simulator. The loading pulse on the display exists to make that visible.

---

### Component structure

```
App
├── CalculatorPanel
│   ├── Display            — shows current input and result
│   └── ButtonGrid         — number/op/equals buttons
└── CircuitPanel
    ├── ViewToggle          — "Schematic" | "Netlist" tab
    ├── SchematicView       — hand-authored SVG, coloured by wire state
    └── NetlistView         — auto-laid-out graph of LUT/DFF nodes
```

### State

A single `useReducer` at App level — no Redux needed:

```javascript
{
  display: "0",
  pendingA: null,
  pendingOp: null,       // "add" | "sub" | "and" | "or"
  netlistState: null,    // latest snapshot from /compute
  loading: false
}
```

On equals press: call `POST /compute`, update `display` with `result`,
update `netlistState` with the snapshot.

### Calculator panel

Standard calculator layout. The result comes from the backend, so there is a brief
loading state between pressing `=` and the answer appearing. Make this visible — a subtle
pulse on the display — because it is the interesting part: it shows a round trip to a
hardware simulator just happened.

### Circuit panel — schematic view

A hand-authored SVG showing the ALU at a readable level of abstraction:

```
[A input] ──┐
             ├──► [8-bit Adder] ──┐
[B input] ──┤                     ├──► [4-to-1 MUX] ──► [Result]
             ├──► [8-bit Sub  ] ──┤
             ├──► [8-bit AND  ] ──┤         ↑
             └──► [8-bit OR   ] ──┘      [op select]
```

Each block is an SVG `<rect>` with a label. After a computation, blocks and wires are
coloured based on `netlistState` — a wire carrying `1` goes blue, `0` stays grey. The
active operation block (the one whose output feeds the MUX) gets a highlighted border.

Hand-place the blocks once in SVG coordinates. No layout library needed for this view.

### Circuit panel — netlist view

The raw graph of LUTs and DFFs, automatically laid out with `elkjs`:

```bash
npm install elkjs
```

Each node is a small card showing the LUT's ID and its current output bit. Edges are SVG
paths between them, coloured by wire value. A LUT outputting `1` is filled blue; `0` nodes
are grey. Clicking a node shows a tooltip with its truth table.

The graph topology is fetched once via `GET /netlist/schema`. On each compute, only the
colouring updates — diff `netlistState.wires` and repaint the relevant elements. Do not
re-run layout on every keypress.

### Milestone: end-to-end working demo

- Press `1`, `2`, `+`, `7`, `=`
- Display shows `19`
- Schematic view highlights the adder block and its output wire
- Netlist view shows the carry-chain LUTs lit up

---

## Phase 5 — Polish (Week 6–8)

These turn a working prototype into a portfolio piece worth showing.

### 5a — Step-through mode
Add a "Step" button that advances the simulator one LUT evaluation at a time instead of
running to convergence in one shot. The netlist view updates after each step, letting you
watch signals propagate through the circuit gate by gate. This is the most compelling demo
feature — it makes the simulation viscerally visible.

### 5b — Accumulator register
Implement chained operations using a real DFF in `alu8.v`:
`always @(posedge clk) accumulator <= result;`
The schematic gains an accumulator block with a clock arrow. The sequential behaviour of the
hardware becomes visible in the UI.

### 5c — Overflow indicator
Add an overflow output to `alu8.v` and surface it as a warning badge on the display when
the result overflows 8 bits. Computed by the simulator, not by JavaScript.

### 5d — README and portfolio write-up
Write a README that explains the architecture clearly — what the simulator does, how the
Verilog maps to LUTs, what the two views are showing. This is what a recruiter reads first.
Consider a short screen recording as well.

---