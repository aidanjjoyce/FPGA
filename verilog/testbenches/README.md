# Testbenches

> The files in this folder were generated as scaffolding for a Verilog learning exercise.
> The seven module implementations in `verilog/` were written by hand; these testbenches
> were created to verify them.

---

## What's here

| File | Tests |
|---|---|
| `testbench_and_gate.v` | All 4 input combinations |
| `testbench_mux2.v` | Both select paths across all input combinations |
| `testbench_half_adder.v` | All 4 input combinations, checks sum and carry |
| `testbench_full_adder.v` | All 8 combinations of a/b/cin |
| `testbench_dff.v` | Reset behaviour, rising-edge latch, stability between edges |
| `testbench_counter4.v` | Reset to 0, correct increment through all 16 values, wrap |
| `testbench_alu8.v` | Spot-checks all 4 ops with known values including overflow |
| `verify.ps1` | Runs all testbenches and reports PASS/FAIL for each |

## Running the tests

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File verilog/testbenches/verify.ps1
```

Requires [Icarus Verilog](http://bleyer.org/icarus) to be installed and on PATH.

## How a testbench works

Each testbench is a Verilog module with no ports — it exists only for simulation.
It instantiates the module under test, drives inputs, and uses `$display` to print
`PASS <module>` or `FAIL <module>` to the terminal. `$finish` ends the simulation.
These are simulation-only constructs and do not exist in real hardware.
