# Simple unit system.
#
# We don't use these more advanced solutions:
#  - unyt [https://github.com/yt-project/unyt/] -- Too slow.
#  - unitlib [https://github.com/tfiers/unitlib] -- My own try. It isn't ready for use yet.

from numpy import ndarray, number


mega = 1e6
kilo = 1e3
milli = 1e-3
micro = 1e-6
nano = 1e-9
pico = 1e-12

second = 1
minute = 60 * second
ms = milli * second

Hz = 1 / second

ampere = 1
nA = nano * ampere
pA = pico * ampere

volt = 1
mV = milli * volt

siemens = ampere / volt
nS = nano * siemens

ohm = 1 / siemens
Mohm = mega * ohm

coulomb = ampere * second
farad = coulomb / volt
pF = pico * farad


# Stubs to mock unitlib functionality and not have to change these types / imports in
# other modules of this package.

Array = ndarray
Quantity = number


def add_unit_support(f):
    return f
