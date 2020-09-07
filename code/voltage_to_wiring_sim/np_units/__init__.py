from .array import Array, Quantity
from .unit import Unit
from .unit.prefixes import milli, nano, pico
from .util import QuantityCollection, inputs_as_raw_data


# Define units used in simulation, in terms of their SI base units.
#
# We avoid one-letter unit variable names (such as 's' or 'A') to avoid clashing with
# common short variable names in downstream scripts.

second = Unit("s")
volt = Unit("V")
ampere = Unit("A")
siemens = Unit("S")
farad = Unit("F")
Hz = Unit("Hz")

minute = Unit("min", base_unit=second, conversion_factor=60)
#   Don't name "min" so as to not overwrite builtin `min` (minimum).

ms = Unit.from_prefix(milli, second)
mV = Unit.from_prefix(milli, volt)
pA = Unit.from_prefix(pico, ampere)
nS = Unit.from_prefix(nano, siemens)
pF = Unit.from_prefix(pico, farad)
