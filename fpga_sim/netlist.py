from dataclasses import dataclass


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
