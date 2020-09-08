from typing import TYPE_CHECKING

from ._01_base_class import BaseUnit, Unit


if TYPE_CHECKING:
    # See the explanation of `if TYPE_CHECKING` in ../ReadMe.
    from ._02_simple_unit import SimpleUnit, SimpleBaseUnit


class PoweredUnit(Unit):
    """
    Eg "mm²"; as contrasted with "mm" (a `SimpleUnit`) or "N/mm²" (a `CompoundUnit`).
    
    Attributes:
        - ground_unit: SimpleUnit
        - power: int
    """

    def __new__(cls, ground_unit: "SimpleUnit", power: int):

        if power == 0:
            from ._02_simple_unit import dimensionless
            return dimensionless

        elif power == 1:
            return ground_unit

        else:
            # `cls` can be `PoweredUnit` or `PoweredBaseUnit`.
            powered_unit = object.__new__(cls)
            powered_unit.ground_unit = ground_unit
            powered_unit.power = power
            return powered_unit

    @property
    def name(self):
        return f"{self.ground_unit.name}{self._power_as_superscript}"

    @property
    def base_unit(self):
        return self.ground_unit.base_unit ** self.power

    @property
    def conversion_factor(self):
        return self.ground_unit.conversion_factor ** self.power

    def __hash__(self):
        return hash((self.ground_unit, self.power))

    # (mV⁻³)**2
    def _raised_to(self, power: int):
        # `self.__class__` can be `PoweredUnit` or `PoweredBaseUnit`.
        return self.__class__(self.ground_unit, self.power * power)

    @property
    def _power_as_superscript(self) -> str:
        # Transform eg the int `-87` to the string `"⁻⁸⁷"`.
        superscript_chars = "⁰¹²³⁴⁵⁶⁷⁸⁹"
        digits = str(abs(self.power))
        output_chars = [superscript_chars[int(digit)] for digit in digits]
        if self.power < 0:
            output_chars.insert(0, "⁻")
        return "".join(output_chars)


class PoweredBaseUnit(BaseUnit, PoweredUnit):
    def __new__(cls, ground_unit: "SimpleBaseUnit", power: int):
        return PoweredUnit.__new__(cls, ground_unit, power)
