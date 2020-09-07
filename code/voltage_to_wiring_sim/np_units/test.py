from numpy import allclose as is_close

from voltage_to_wiring_sim.np_units import Array, Quantity, Unit, milli, nano
from voltage_to_wiring_sim.np_units.unit import PoweredUnit


volt = Unit("V")
mV = Unit.from_prefix(milli, volt)
nV = Unit.from_prefix(nano, volt)

second = Unit("s")
ms = Unit.from_prefix(milli, second)
minute = Unit("min", base_unit=second, conversion_factor=60)

siemens = Unit("S")
nS = Unit.from_prefix(nano, siemens)


umu = volt * ms
assert umu.base_unit == volt * second
assert is_close(umu.conversion_factor, 0.001)

udu = mV / nS
assert udu.base_unit == volt / siemens
assert is_close(udu.conversion_factor, 1e6)

umudu = nV * nS / mV
udumu = nV * (nS / mV)
assert umudu.base_unit == udumu.base_unit == volt * siemens / volt
assert is_close(umudu.conversion_factor, udumu.conversion_factor)
assert is_close(umudu.conversion_factor, 1e-15)

amumu = 3 * mV * mV
assert is_close(amumu.data, 3e-6)
amudu = 3 * nS / mV
assert is_close(amudu.data, 3e-6)

recip = 1 / ms
assert isinstance(recip, (Unit, PoweredUnit))
assert recip.base_unit == 1 / second
assert is_close(recip.conversion_factor, 1000)

recip2 = 2 / ms
assert isinstance(recip2, Quantity)
assert recip2.data_unit == 1 / second
assert is_close(recip2.data, 2000)

smup = 8 * (mV ** 2)
assert is_close(smup.data, 8e-6)
assert smup.data_unit == volt ** 2 == volt * volt

time = 2 * minute
assert time.value_unit == time.data_unit == second
assert time.value == time.data.item() == 120

amu = [3, 1, 5] * nV
assert isinstance(amu, Array) and not isinstance(amu, Quantity)

smu = 3 * mV
assert isinstance(smu, Quantity)

# assert 2 * smu == smu + smu  # todo: implement ufunc `equal`

assert 1 * ms / ms == 1

breakpoint()
