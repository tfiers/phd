from dataclasses import dataclass

from IPython.lib.pretty import PrettyPrinter


@dataclass
class Prefix:
    symbol: str
    factor: float


kilo = Prefix("k", 1e3)
deci = Prefix("d", 1e-1)
centi = Prefix("c", 1e-2)
milli = Prefix("m", 1e-3)
micro = Prefix("μ", 1e-6)
nano = Prefix("n", 1e-9)
pico = Prefix("p", 1e-12)


# (The following `noinspection` PyCharm directive is because it does not recognize a
# dataclass's init params in the class docstring).
# noinspection PyUnresolvedReferences
@dataclass
class Unit:
    """
    :param name
    :param base_unit:  Base SI units (meter, second, ...) in which data with this unit
                       is stored.
    :param factor:  With what to multiply 1 `base_unit` to get one of this unit.
    """

    name: str
    base_unit: "Unit" = None
    factor: float = 1

    def __post_init__(self):
        if self.base_unit is None:
            self.base_unit = self

    def __eq__(self, other: "Unit"):
        return other.name == self.name

    #
    #
    # Text representation in IPython/Jupyter
    #
    def _repr_pretty_(self, p: PrettyPrinter, _cycle: bool):
        p.text(str(self))

    def __str__(self):
        return self.name

    #
    #
    # Derived units through prefixes
    #
    def with_prefix(self, prefix: Prefix):
        if not self.is_base_unit:
            raise TypeError(f"Can only prefix base units (not {self})")
        return Unit(
            name=f"{prefix.symbol}{self.name}", base_unit=self, factor=prefix.factor
        )

    @property
    def is_base_unit(self) -> bool:
        return self.base_unit == self

    #
    #
    # Arithmetic with units, eg `8 * mV`, or `nS / mV`.
    #

    # Notes on `__rmul__` and `__rtruediv__`:
    # - These handle the creation of Arrays from unit-less scalars or array-like objects,
    #   eg `[3,1,2] * mV` or `1 / ms`.
    # - We have to import `arr.Array` inside these methods (and not at the top of the
    #   module) to avoid circular imports (`arr` imports `Unit` at the module level).

    # other * self
    def __rmul__(self, other):
        from arr import Array

        # 3 * mV
        return Array(other, display_unit=self)

    # other / self
    def __rtruediv__(self, other):
        from arr import Array

        # 1 / ms
        new_base_unit = Unit(f"/ {self.base_unit.name}")
        new_unit = Unit(f"/ {self.name}", new_base_unit, 1 / self.factor,)
        return Array(other, display_unit=new_unit)

    # self * other
    def __mul__(self, other):
        if isinstance(other, Unit):
            # nS * mV
            new_base_unit = Unit(name=f"{self.base_unit.name} * {other.base_unit.name}")
            return Unit(
                name=f"{self.name} * {other.name}",
                base_unit=new_base_unit,
                factor=self.factor * other.factor,
            )
        else:
            # mV * 3
            return NotImplemented

    # self / other
    def __truediv__(self, other):
        if isinstance(other, Unit):
            # nS / mV
            new_base_unit = Unit(name=f"{self.base_unit.name} / {other.base_unit.name}")
            return Unit(
                name=f"{self.name} / {other.name}",
                base_unit=new_base_unit,
                factor=self.factor / other.factor,
            )
        else:
            # mV / 3
            return NotImplemented

    # self ** power
    def __pow__(self, power, modulo=None):
        if isinstance(power, int) and modulo is None:
            if power == 0:
                return Unit("1")
            else:
                power_str = _to_superscript(power)
                return Unit(
                    name=f"{self.name}{power_str}",
                    base_unit=Unit(f"{self.base_unit.name}{power_str}"),
                    factor=self.factor ** power,
                )
        else:
            return NotImplemented


def _to_superscript(power: int) -> str:
    digits = "⁰¹²³⁴⁵⁶⁷⁸⁹"
    chars = []
    if power < 0:
        chars.append("⁻")
        power = -power
    for char in str(power):
        chars.append(digits[int(char)])
    return "".join(chars)
