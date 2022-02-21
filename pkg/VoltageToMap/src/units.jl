
# 'Fake' units, until a better solution exists.
# (`Unitful` works great, but the interactive UX is bad because of its very verbose types).

giga  = 1e9
mega  = 1e6
kilo  = 1e3
milli = 1e-3
centi = 1e-2
micro = 1e-6
nano  = 1e-9
pico  = 1e-12
export mega, kilo, milli, centi, micro, nano, pico

seconds = s = 1
Hz = 1 / seconds
ms = milli * seconds
minutes = 60 * seconds
hours = 60 * minutes
export seconds, s, Hz, ms, minutes, hours

metre = meter = 1
cm = centi * metre
mm = milli * metre
μm = um = micro * metre
nm = nano * metre
export metre, meter, cm, mm, μm, um, nm

ampere = 1
mA = milli * ampere
uA = μA = micro * ampere
nA = nano * ampere
pA = pico * ampere
export ampere, mA, μA, uA, nA, pA

volt = 1
mV = milli * volt
uV = μV = micro * volt
nV = nano * volt
export volt, mV, uV, μV, nV

siemens = ampere / volt
ohm = 1 / siemens
mS = milli * siemens
nS = nano * siemens
pS = pico * siemens
Mohm = mega * ohm
Gohm = giga * ohm
export siemens, ohm, mS, nS, pS, Mohm

coulomb = ampere * seconds
farad = coulomb / volt
uF = μF = micro * farad
nF = nano * farad
pF = pico * farad
export coulomb, farad, uF, μF, nF, pF

kibi = 2^10
mebi = 2^20
gibi = 2^30
# Sidenote: Windows uses binary prefixes, but displays them as SI: "MB" is actually "MiB".

bytes = 1
    # We choose bytes as base unit (instead of bits), as that is what e.g. `sizeof` and
    # `Base.summarysize` report.
bits = bytes // 8
kB = kilo * bytes
MB = mega * bytes
GB = giga * bytes
kiB = kibi * bytes
MiB = mebi * bytes
GiB = gibi * bytes
export bytes, bits, kB, kiB, MB, MiB, GB, GiB
