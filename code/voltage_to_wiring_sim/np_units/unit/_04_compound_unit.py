from collections import defaultdict
from math import prod
from typing import Dict, Iterable, List, Tuple

from ._01_base_class import BaseUnit, Unit
from ._02_simple_unit import SimpleUnit, dimensionless
from ._03_powered_unit import PoweredUnit


class CompoundUnit(Unit):
    """
    A multiplicative combination of `PoweredUnit`s.
    Eg "mV²·μm / nS".
    
    Attributes:
        - components: Tuple[PoweredUnit]
    """

    def __new__(cls, units: Iterable[Unit]):
        flattened_units = flatten(units)
        combined_units = combine_powers(flattened_units)
        if len(combined_units) == 0:
            return dimensionless
        elif len(combined_units) == 1:
            return combined_units[0]
        else:
            # `cls` can be `CompoundUnit` or `CompoundBaseUnit`.
            compound_unit = object.__new__(cls)
            compound_unit.components = combined_units
            return compound_unit

    @property
    def name(self):
        return "·".join([component.name for component in self.components])

    @property
    def base_unit(self):
        return CompoundBaseUnit([component.base_unit for component in self.components])

    @property
    def conversion_factor(self):
        return prod([component.conversion_factor for component in self.components])

    def __hash__(self):
        return hash(self.components)

    def _raised_to(self, power: int):
        return self.__class__([component ** power for component in self.components])


class CompoundBaseUnit(BaseUnit, CompoundUnit):
    def __new__(cls, units: Iterable[BaseUnit]):
        return CompoundUnit.__new__(cls, units)


def flatten(units: Iterable[Unit]) -> List[PoweredUnit]:
    """ Flatten and homogenize input units to be a list of `PoweredUnit`s. """
    flattened_units = []
    for unit in units:
        if isinstance(unit, CompoundUnit):
            flattened_units.extend(unit.components)
        elif isinstance(unit, PoweredUnit):
            flattened_units.append(unit)
    return flattened_units


def combine_powers(units: List[PoweredUnit]) -> Tuple[PoweredUnit]:
    """
    Aggregate all `PoweredUnit`s that have the same `ground_unit`, and sum their
    powers. Throw away dimensionless units and units with a combined power of zero.
    """
    powers: Dict[SimpleUnit, int] = defaultdict(lambda: 0)
    for u in units:
        powers[u.ground_unit] += u.power
    return tuple(
        ground_unit ** power
        for ground_unit, power in powers.items()
        if power != 0 and ground_unit != dimensionless
    )
