from ._03_powered_unit import PoweredBaseUnit, PoweredUnit


class SimpleUnit(PoweredUnit):
    """
    Eg "newton" or "mV"; as contrasted with "mV²" (a `PoweredUnit`) or "newton * meter²"
    (a `CompoundUnit`).
    """

    def __new__(
        cls, name: str, base_unit: "SimpleBaseUnit", conversion_factor: float,
    ):
        # `cls` can be `SimpleUnit` or `SimpleBaseUnit`.
        simple_unit = object.__new__(cls)
        # We are a special case of a `PoweredUnit`:
        simple_unit.power = 1
        simple_unit.ground_unit = simple_unit
        # The below three attributes cannot be set directly (e.g. using
        # `simple_unit.name = name`); this would yield an `AttributeError`. This is
        # because these attributes are *properties* in the parent class. Properties can
        # only be overriden by new properties. Hence the annoying verbosity of dummy
        # variables and trivial property getters.
        # (And no, using `simple_unit.name = property(..)`
        #  or `simple_unit.__dict__["name"] = ..` also doesn't work :) ).
        simple_unit._name = name
        simple_unit._base_unit = base_unit
        simple_unit._conversion_factor = conversion_factor
        return simple_unit

    @property
    def name(self):
        return self._name

    @property
    def base_unit(self):
        return self._base_unit

    @property
    def conversion_factor(self):
        return self._conversion_factor

    def __hash__(self):
        return hash((self.name, self.base_unit, self.conversion_factor))

    def _raised_to(self, power):
        return PoweredUnit(self, power)


class SimpleBaseUnit(PoweredBaseUnit, SimpleUnit):
    def __new__(cls, name: str):
        return SimpleUnit.__new__(cls, name, ..., ...)

    def __hash__(self):
        return hash(self.name)

    def _raised_to(self, power):
        return PoweredBaseUnit(self, power)


dimensionless = SimpleBaseUnit("1")
