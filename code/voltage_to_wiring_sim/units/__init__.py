import unyt

from .unyt_mod import Array, Quantity, Unit, custom_units, unyt_array, unyt_quantity
from .util import as_raw_data, QuantityCollection, inputs_as_raw_data


pF = Unit("pF")
V = Unit("V")
mV = Unit("mV")
A = Unit("A")
pA = Unit("pA")
ms = Unit("ms")
second = Unit("s")
minute = Unit("min")
Hz = Unit("Hz")

try:
    unyt.define_unit("S", (1, "A/V"), prefixable=True)
except:
    # Siemens was already defined -- i.e. it's not the first time this script has run.
    pass

S = Unit("S")
custom_units.add(S)
nS = Unit("nS")
