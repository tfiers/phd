from unitlib import Array, Quantity, add_unit_support
from unitlib.units import second, ampere, minute, volt, farad, siemens, Hz
from unitlib.prefixes import milli, nano, pico


ms = milli * second
mV = milli * volt
nA = nano * ampere
nS = nano * siemens
pF = pico * farad
pA = pico * ampere

# Reassignment trick to make PyCharm IDE:
#  - Not complain about unused imports
#  - In other modules, suggest importing these objects from this module, instead of from
#    their original packages.
Array, Quantity, add_unit_support = Array, Quantity, add_unit_support
minute, Hz = minute, Hz
