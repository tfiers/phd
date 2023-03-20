
using ConnTestEval

conns = [
    (:exc, 1),
    (:inh, -1),
    (:unc, 0.1),
    (:exc, 0.2),
    (:unc, 0.3),
    (:inh, 0.1),
    (:unc, -1.1)
]
conntypes = first.(conns)
tvals = last.(conns)

s = sweep_threshold(tvals, conntypes)
