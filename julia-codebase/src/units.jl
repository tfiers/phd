
# 'Fake' units, until a better solution exists.
# (`Unitful` works great, but the interactive UX is bad because of its very verbose types).

mega = 1e6
kilo = 1e3
milli = 1e-3
centi = 1e-2
micro = 1e-6
nano = 1e-9
pico = 1e-12

s = seconds = 1
ms = milli * seconds
minutes = 60 * seconds
hours = 60 * minutes

Hz = 1 / seconds

metre = meter = 1
cm = centi * metre
mm = milli * metre
μm = um = micro * metre
nm = nano * metre

ampere = 1
uA = μA = micro * ampere
nA = nano * ampere
pA = pico * ampere

volt = 1
mV = milli * volt
nV = nano * volt

siemens = ampere / volt
mS = milli * siemens
nS = nano * siemens

ohm = 1 / siemens
Mohm = mega * ohm

coulomb = ampere * seconds
farad = coulomb / volt
uF = μF = micro * farad
nF = nano * farad
pF = pico * farad
