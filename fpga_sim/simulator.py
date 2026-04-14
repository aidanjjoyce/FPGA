from fpga_sim.netlist import LUT, Netlist

MAX_ITERATIONS = 1000


def evaluate_lut(lut: LUT, wires: dict[str, int]) -> None:
    wire_values = [wires[wire_id] for wire_id in lut.input_wires]
    index = 0
    for i, value in enumerate(wire_values):
        index |= value << (len(wire_values) - 1 - i)
    wires[lut.output_wire] = lut.truth_table[index]


def _evaluate_luts_to_convergence(netlist: Netlist) -> None:
    for _ in range(MAX_ITERATIONS):
        prev_wires = dict(netlist.wires)
        for lut in netlist.luts:
            evaluate_lut(lut, netlist.wires)
        if netlist.wires == prev_wires:
            return
    raise RuntimeError(
        f"Combinational loop detected: circuit did not converge after {MAX_ITERATIONS} iterations"
    )


def _latch_dffs(netlist: Netlist) -> None:
    next_q = {
        dff.q_wire: (
            0 if netlist.wires[dff.reset_wire] == 1
            else netlist.wires[dff.d_wire]
        )
        for dff in netlist.dffs
    }
    netlist.wires.update(next_q)


def simulate_step(netlist: Netlist, input_values: dict[str, int], rising_edge: bool) -> None:
    netlist.wires.update(input_values)
    _evaluate_luts_to_convergence(netlist)
    if rising_edge:
        _latch_dffs(netlist)
