from fpga_sim.netlist import LUT, Netlist


def evaluate_lut(lut: LUT, wires: dict[str, int]) -> None:
    wire_values = [wires[wire_id] for wire_id in lut.input_wires]
    index = 0
    for i, value in enumerate(wire_values):
        index |= value << (len(wire_values) - 1 - i)
    wires[lut.output_wire] = lut.truth_table[index]
