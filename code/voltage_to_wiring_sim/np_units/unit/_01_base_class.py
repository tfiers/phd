from abc import ABC, abstractmethod, abstractproperty
from numbers import Number
from typing import Literal, Optional, TYPE_CHECKING, overload

from .prefixes import Prefix
from ..type_aliases import ArrayLike, Scalar, scalar_types


if TYPE_CHECKING:
    # See the explanation of `if TYPE_CHECKING` in ../ReadMe.
    from ..array import Array, Quantity
    from ._02_simple_unit import SimpleUnit, SimpleBaseUnit
    from ._04_compound_unit import CompoundUnit


class Unit(ABC):
    """
    A physical unit. For example, "farad", "μm²", or "mV/nS".

    Units can be:
     - raised to a power (`meter**2`);
     - composed with other units (`newton * meter`);
     - applied to numeric data (`8*farad`, `[3,5]*mV`);
     - applied to numeric data that already has units (`5*mV / nS`, `5*volt / mV`).

    This abstract base class ('ABC') defines an interface that all {..}Unit classes in
    this package implement.
    """

    #
    #
    # ---------------
    # Core properties

    @abstractproperty
    def name(self) -> str:
        """
        How this unit is displayed textually (eg. in print statements or in axis labels
        of data plots). Examples: "min", "mV".
        """
        ...

    @abstractproperty
    def base_unit(self) -> "BaseUnit":
        """
        A scalar multiple or submultiple of this `unit`, such that
        ```
        unit == base_unit * conversion_factor
        ```
        
        Numeric data annotated with this `unit` is stored in `base_unit` units. For
        example, if this `unit` is "mV" and its `base_unit` is "volt" (with a
        `conversion_factor` of 1E-3), the numeric data underlying the expression `8 mV`
        will be stored as `0.008` in memory.
        """
        ...

    @abstractproperty
    def conversion_factor(self) -> Number:
        """
        With what to multiply one `base_unit` to get one of this unit.
        
        For example, if this unit is "minute", with a base unit of "second",
        `conversion_factor` is 60.
        See also `base_unit`.
        """
        ...

    #
    #
    # --------------------------------
    # Behave as a proper Python object

    def __str__(self):
        return self.name

    def __repr__(self):
        return f'<{self.__class__.__name__} "{self.name}">'

    def __eq__(self, other):
        return hash(self) == hash(other)

    @abstractmethod
    def __hash__(self) -> int:
        ...

    #
    #
    # -----------------
    # Unit creation API

    def __new__(
        cls,
        name: str,
        base_unit: Optional["SimpleBaseUnit"] = None,
        conversion_factor: Optional[float] = 1,
    ):
        # Use `Unit`'s constructor as a shorthand to create new
        # `SimpleUnit`s and `SimpleBaseUnit`s.

        from ._02_simple_unit import SimpleUnit, SimpleBaseUnit

        if base_unit is None:
            return SimpleBaseUnit(name)
        else:
            return SimpleUnit(name, base_unit, conversion_factor)

    @staticmethod
    def from_prefix(prefix: Prefix, base_unit: "SimpleBaseUnit") -> "SimpleUnit":
        return SimpleUnit(
            name=f"{prefix.symbol}{base_unit.name}",
            base_unit=base_unit,
            conversion_factor=prefix.factor,
        )

    # mV * farad
    def __mul__(self, other) -> "CompoundUnit":
        if isinstance(other, Unit):
            from ._04_compound_unit import CompoundUnit

            return CompoundUnit([self, other])

    # mV / farad
    def __truediv__(self, other):
        if isinstance(other, Unit):
            return self * (1 / other)
            # `1 / other` will defer to `Unit.__rtruediv__`.

    # mV ** 2
    def __pow__(self, power, modulo=None) -> "Unit":
        if isinstance(power, int) and modulo is None:
            return self._raised_to(power)
        else:
            return NotImplemented

    @abstractmethod
    def _raised_to(self, power: int) -> "Unit":
        ...

    #
    #
    # -----------------------------------
    # `Quantity` and `Array` creation API
    # (via `8 * mV` syntax)

    @overload
    def __rmul__(self, other: Scalar) -> "Quantity":
        ...

    @overload
    def __rmul__(self, other: ArrayLike) -> "Array":
        ...

    # 8 * mV  (`other` = 8)
    def __rmul__(self, other):
        # Why import here? To prevent a circular import (`array.py` already imports from
        # `unit.py` at the module level).
        from ..array import Array, Quantity

        if isinstance(other, scalar_types):
            return Quantity(value=other, display_unit=self)
        else:
            return Array(data=other, display_unit=self)

    @overload
    def __rtruediv__(self, other: Literal[1]) -> "Unit":
        ...

    # 8 / mV  (`other` = 8)
    def __rtruediv__(self, other):
        reciprocal_unit = self ** (-1)
        if other == 1:
            # Allow `1 / unit` as a special case, to create a pure `Unit` (and not a
            # `Quantity` with `value = 1`).
            return reciprocal_unit
        else:
            return other * reciprocal_unit


class BaseUnit(Unit, ABC):
    """
    A `Unit` in which numeric data is stored in memory.

    See the `Unit.base_unit` property.
    """

    @property
    def base_unit(self):
        return self

    @property
    def conversion_factor(self):
        return 1
