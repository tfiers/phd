from dataclasses import dataclass, fields
from typing import Dict, Union

from voltage_to_wiring_sim.np_units import Array, Quantity


@dataclass
class QuantityCollection:
    """ A collection of dimensioned values, with pretty printing ability. """
    
    def __str__(self):
        """ Invoked when calling `print()` on the dataclass. """
        clsname = self.__class__.__name__
        lines = [clsname, "-" * len(clsname)]
        for name, value in self.asdict().items():
            lines.append(f"{name} = {str(value)}")
        return "\n".join(lines)
    
    def asdict(self) -> Dict[str, Union[Quantity, Array]]:
        """
        Alternative to dataclasses.asdict()
        That method makes a deepcopy of every field value, this method does not.
        """
        return {field.name: getattr(self, field.name) for field in fields(self)}


def inputs_as_raw_data(f):
    raise NotImplementedError
