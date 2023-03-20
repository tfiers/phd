"""
Performance evaluation of a connection test applied to a bunch of
possibly-connected neuron pairs.

Input is
    - A list of 't-values'; which are the connection test's guess of
      how strongly connected each neuron-pair is;
    - And a corresponding list of the real type of each connection;
      which should be one of `(:exc, :inh, :unc)`.

For a certain t-value-threshold `θ`, each connection is classified as
follows: unconnected (`:unc`) if `|t| ≤ θ`; and excitatory or inhibitory
otherwise, depending on t's sign (`:exc` for t > 0, and `:inh` for t < 0).
"""
module ConnTestEval


using StructArrays


include("predictiontable.jl")


sweep_threshold(df) = sweep_threshold(df.t, df.conntype)

sweep_threshold(tvals, conntypes) = StructArray(
    [PredictionTable(θ, tvals, conntypes) for θ in thresholds(tvals)]
)

"""
    thresholds(tvals)

List of classification thresholds that spans all possible TPR/FPR tradeoffs.

Sorted from zero recall and zero false positives (highest threshold), to
highest recall and 100% false positive rate (threshold 0).
"""
thresholds(tvals) = sort!(unique!([abs.(tvals); 0]), rev=true)


export sweep_threshold, PredictionTable

end
