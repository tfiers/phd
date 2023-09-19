"""
Evaluate the performance of a connection test, applied to a bunch of
possibly-connected neuron pairs.

Input is
- A list of 't-values'; which are the guesses of the connection test on
  how strongly connected each neuron-pair is;
- And a corresponding list of the real type of each connection;
  which should be one of `(:exc, :inh, :unc)`.

For a certain t-value-threshold `θ`, each connection is classified as
follows:
- unconnected (`:unc`) if `|t| ≤ θ`;
- and excitatory or inhibitory otherwise, depending on t's sign (`:exc`
  for `t > 0`, and `:inh` for `t ≤ 0`).

I.e. we perform ternary (not binary) classification.

Main end-user function: [`sweep_threshold`](@ref).\\
The resulting `sweep` can be queried for different series (e.g.
`sweep.F1` or `sweep.threshold`), and you can pass it to
[`at_FPR`](@ref) and [`calc_AUROCs`](@ref).
"""
module ConnTestEval

include("predictiontable.jl")
include("sweep.jl")

end
