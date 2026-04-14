from fpga_sim.netlist import LUT, DFF, Netlist
from fpga_sim.simulator import simulate_step


def build_counter() -> Netlist:
    return Netlist(
        luts=[
            LUT(
                id="lut_not_q0",
                truth_table=[1, 0],
                input_wires=["q0"],
                output_wire="next_q0",
            ),
            LUT(
                id="lut_xor_q1_q0",
                truth_table=[0, 1, 1, 0],
                input_wires=["q1", "q0"],
                output_wire="next_q1",
            ),
        ],
        dffs=[
            DFF(id="dff_q0", d_wire="next_q0", q_wire="q0", clk_wire="clk", reset_wire="gnd"),
            DFF(id="dff_q1", d_wire="next_q1", q_wire="q1", clk_wire="clk", reset_wire="gnd"),
        ],
        wires={"clk": 0, "q0": 0, "q1": 0, "next_q0": 0, "next_q1": 0, "gnd": 0},
        inputs=["clk"],
        outputs=["q0", "q1"],
    )


if __name__ == "__main__":
    netlist = build_counter()
    print("tick | q1 q0")
    print("-----|------")
    for tick in range(8):
        simulate_step(netlist, input_values={}, rising_edge=True)
        q0 = netlist.wires["q0"]
        q1 = netlist.wires["q1"]
        print(f"  {tick + 1}  |  {q1}  {q0}")
