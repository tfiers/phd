import numpy as np
from numpy import allclose

from .array import Array
from .unit import Unit, milli, nano

volt = Unit("V")
mV = volt.with_prefix(milli)
nV = volt.with_prefix(nano)

second = Unit("s")
ms = second.with_prefix(milli)
min = Unit("min", base_unit=second, factor=60)

siemens = Unit("S")
nS = siemens.with_prefix(nano)


umu = volt * ms
assert umu.base_unit == volt * second
assert umu.factor == 0.001

udu = mV / nS
assert udu.base_unit == volt / siemens
assert udu.factor == 1e6

umudu = nV * nS / mV
udumu = nV * (nS / mV)
assert umudu.base_unit == udumu.base_unit == volt * siemens / volt
assert umudu.factor == udumu.factor == 1e-15

amumu = 3 * mV * mV
assert allclose(amumu.data_in_base_units, 3e-6)
amudu = 3 * nS / mV
assert allclose(amudu.data_in_base_units, 3e-6)

recip = 1 / ms
assert recip.base_unit == (1 / second).display_unit
assert allclose(recip.data_in_base_units, 1000)

smup = 8 * (mV ** 2)
assert allclose(smup.data_in_base_units, 8e-6)
assert smup.base_unit == volt ** 2  # == volt * volt

time = 2 * min
assert time.base_unit == second
assert time.data_in_base_units == 120

smu = 3 * mV
amu = [3, 1, 5] * nV

smu2 = 2 * smu
smu2
(smu + smu)
# amu2 =
# amu_plus
# assert 2 * smu == smu + smu
