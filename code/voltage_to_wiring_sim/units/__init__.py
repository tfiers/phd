from .array import Array, Quantity
from .unit import Unit, milli, nano, pico
from .util import QuantityCollection, inputs_as_raw_data


# Define units used in simulation, and their SI base units.
#
# We avoid one-letter unit names (such as 's' or 'A') to avoid clashing with
# common short variable names in downstream scripts.

second = Unit("s")
minute = Unit("min", base_unit=second, factor=60)  # don't overwrite builtin `min`(imum)
ms = second.with_prefix(milli)

volt = Unit("V")
mV = volt.with_prefix(milli)

amp = Unit("A")
pA = amp.with_prefix(pico)

siemens = Unit("S")
nS = siemens.with_prefix(nano)

farad = Unit("F")
pF = farad.with_prefix(pico)

Hz = Unit("Hz")