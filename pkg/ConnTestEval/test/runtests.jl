
using ConnTestEval
using Test

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
tvals = Vector{Float64}(last.(conns))
     # If not, is a Vector{Real},
     # and every predtable will have own copy (to make Vector{Float64})

s = sweep_threshold(tvals, conntypes)

@test s.threshold == [1.1, 1.0, 0.3, 0.2, 0.1, 0.0]
@test s[1].FPR == 0.0
@test s[end].FPR == 1.0
@test s[1].real_types == s[3].real_types
@test s[1].predicted_types[1] == :unc
