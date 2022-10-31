
# 'Fake' units, until a better solution exists.
# (`Unitful` works great, but the interactive UX is bad because of its very verbose types).

const giga  = 1e9
const mega  = 1e6
const kilo  = 1e3
const milli = 1e-3
const centi = 1e-2
const micro = 1e-6
const nano  = 1e-9
const pico  = 1e-12
export mega, kilo, milli, centi, micro, nano, pico

const second = 1.0
const Hz = 1 / second
const ms = milli * second
const minute = 60 * second
const hour = 60 * minute
export second, Hz, ms, minute, hour

const seconds = second
const minutes = minute
const hours = hour
export seconds, minutes, hours
# Plural makes more sense in e.g. `10minutes`.
# Singular makes more sense in `f(x, unit = second)` or `x = 80 * second`.

const metre = meter = 1.0
const cm = centi * metre
const mm = milli * metre
const μm = um = micro * metre
const nm = nano * metre
export metre, meter, cm, mm, μm, um, nm

const ampere = 1.0
const mA = milli * ampere
const μA = micro * ampere
const nA = nano * ampere
const pA = pico * ampere
export ampere, mA, μA, nA, pA

const volt = 1.0
const mV = milli * volt
const μV = micro * volt
const nV = nano * volt
export volt, mV, μV, nV

const siemens = ampere / volt
const ohm = 1 / siemens
const mS = milli * siemens
const nS = nano * siemens
const pS = pico * siemens
const Mohm = mega * ohm
const Gohm = giga * ohm
export siemens, ohm, mS, nS, pS, Mohm

const coulomb = ampere * second
const farad = coulomb / volt
const μF = micro * farad
const nF = nano * farad
const pF = pico * farad
export coulomb, farad, μF, nF, pF

const kibi = 2^10
const mebi = 2^20
const gibi = 2^30
# Sidenote: Windows uses binary prefixes, but displays them as SI: "MB" is actually "MiB".

const bytes = 1
    # We choose bytes as base unit (instead of bits), as that is what e.g. `sizeof` and
    # `Base.summarysize` report.
const bits = bytes / 8
const kB = kilo * bytes
const MB = mega * bytes
const GB = giga * bytes
const kiB = kibi * bytes
const MiB = mebi * bytes
const GiB = gibi * bytes
export bytes, bits, kB, kiB, MB, MiB, GB, GiB
