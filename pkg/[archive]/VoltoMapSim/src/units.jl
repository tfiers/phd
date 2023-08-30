
# 'Fake' units, until a better solution exists.
# (`Unitful` works great, but the interactive UX is bad because of its very verbose types).

# [most units moved to SpikeWorks]

@reexport using SpikeWorks.Units

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
