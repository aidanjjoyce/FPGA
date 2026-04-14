# FPGA Calculator — Project Write-up

A web application that runs a working calculator through a software FPGA simulator built from scratch. Every button press drives a real simulation of LUTs and flip-flops in a Python backend — the result comes from simulated hardware, not JavaScript arithmetic. A live circuit diagram visualises the internal state of the simulation after each computation.

---

## Phase 0 — Verilog

### What was built
Seven synthesisable RTL modules written by hand in Verilog, verified with a custom PowerShell test harness running Icarus Verilog:

| Module | Description |
|---|---|
| `and_gate.v` | 2-input AND gate via continuous assignment |
| `mux2.v` | 2-to-1 multiplexer using the ternary operator |
| `half_adder.v` | 1-bit adder producing sum and carry outputs |
| `full_adder.v` | 1-bit adder with carry-in, composed from two half adders |
| `dff.v` | D flip-flop with synchronous reset |
| `counter4.v` | 4-bit wrapping counter driven by a clock |
| `alu8.v` | 8-bit ALU supporting add, subtract, AND, OR via 2-bit op select |

`alu8.v` is the target circuit for the whole project — every subsequent phase exists to parse, simulate, and visualise this one file.

### Skills
- **Verilog (synthesisable RTL subset)** — modules, port declarations, continuous assignment, always blocks, case statements, non-blocking vs blocking assignment, multi-bit signals, structural composition via module instantiation
- **Digital logic fundamentals** — combinational vs sequential logic, LUTs (look-up tables: the fundamental FPGA building block that implements any logic function via a stored truth table), flip-flops, ripple-carry addition (chaining full adders so carry-out of each bit feeds carry-in of the next), ALU design
- **Hardware simulation** — Icarus Verilog, testbench authoring using simulation-only constructs (`$display` for terminal output, `$finish` to end simulation, `posedge` event triggers); testbench scaffolding was generated, module implementations written by hand
- **PowerShell scripting** — automated multi-module test harness with pass/fail reporting

---

## Phase 1 — Netlist Model + Simulator

### What was built

Three data structures and a simulation engine in `fpga_sim/`:

| Component | Description |
|---|---|
| `LUT` | Look-up table primitive — stores a truth table and the wire IDs it reads and drives |
| `DFF` | D flip-flop primitive — stores wire IDs for D, Q, clock, and synchronous reset |
| `Netlist` | Complete circuit — holds all LUTs, DFFs, and a dict of current wire values |
| `evaluate_lut()` | Evaluates one LUT against current wire state; writes result back to wires |
| `simulate_step()` | Advances the circuit one time step: settles combinational logic to convergence, then latches DFFs on a rising clock edge |

`Netlist` also exposes `schema()` (static topology for the frontend) and `snapshot()` (current wire values after each computation).

### Skills
- **Python dataclasses** — modelling hardware primitives as typed data structures with validation in `__post_init__`
- **Simulation fundamentals** — iterative relaxation for combinational settling; two-phase clocked simulation (combinational first, sequential latch second)
- **Digital logic** — translating hardware concepts (LUT truth tables, DFF synchronous reset, simultaneous register latching) into a software model that faithfully reproduces their behaviour
- **Software design** — separating concerns between data (netlist), computation (simulator), and serialisation; keeping primitives free of transport logic

### Design decisions

- **MSB-first truth table indexing** — the first wire in `input_wires` is the most significant bit of the index into `truth_table`, matching standard hardware convention.
- **Iterative relaxation for convergence** — LUTs are evaluated repeatedly until the wire state stabilises, rather than pre-sorting into topological order. Simpler to implement and correct for any ordering.
- **Simultaneous DFF latching** — all DFF next-Q values are collected before any are written, ensuring correct behaviour when DFFs are chained.
- **`rising_edge: bool`** — the caller detects clock transitions and passes a boolean, keeping the simulator free of clock-edge detection logic.

---

## Phase 2 — Verilog Parser

*Coming soon.*

---

## Phase 3 — Python Backend

*Coming soon.*

---

## Phase 4 — React Frontend

*Coming soon.*

---

## Phase 5 — Polish

*Coming soon.*
