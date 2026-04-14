from dataclasses import dataclass, field


@dataclass
class LUT:
    id: str
    truth_table: list[int]
    input_wires: list[str]
    output_wire: str

    def __post_init__(self):
        expected_size = 2 ** len(self.input_wires)
        if len(self.truth_table) != expected_size:
            raise ValueError(
                f"LUT '{self.id}': truth_table has {len(self.truth_table)} entries, "
                f"expected {expected_size} (2 ** {len(self.input_wires)} inputs)"
            )


@dataclass
class DFF:
    id: str
    d_wire: str
    q_wire: str
    clk_wire: str
    reset_wire: str


@dataclass
class Netlist:
    luts: list[LUT]       = field(default_factory=list)
    dffs: list[DFF]       = field(default_factory=list)
    wires: dict[str, int] = field(default_factory=dict)
    inputs: list[str]     = field(default_factory=list)
    outputs: list[str]    = field(default_factory=list)

    def __post_init__(self):
        drivers = [lut.output_wire for lut in self.luts] + \
                  [dff.q_wire for dff in self.dffs] + \
                  self.inputs
        seen = set()
        for wire in drivers:
            if wire in seen:
                raise ValueError(f"Wire '{wire}' is driven by more than one source")
            seen.add(wire)

    def _lut_to_dict(self, l: LUT) -> dict:
        return {
            "id": l.id,
            "input_wires": l.input_wires,
            "output_wire": l.output_wire,
            "truth_table": l.truth_table,
        }

    def _dff_to_dict(self, d: DFF) -> dict:
        return {
            "id": d.id,
            "d_wire": d.d_wire,
            "q_wire": d.q_wire,
            "clk_wire": d.clk_wire,
            "reset_wire": d.reset_wire,
        }

    def schema(self) -> dict:
        """Static topology — fetched once on page load."""
        return {
            "luts": [self._lut_to_dict(l) for l in self.luts],
            "dffs": [self._dff_to_dict(d) for d in self.dffs],
            "inputs": self.inputs,
            "outputs": self.outputs,
        }

    def snapshot(self) -> dict:
        """Dynamic wire state — returned after every computation."""
        return {"wires": dict(self.wires)}
