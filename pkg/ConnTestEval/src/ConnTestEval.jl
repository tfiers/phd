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
otherwise, depending on t's sign (`:exc` for t > 0, and `:inh` for t ≤ 0).
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

"""
    at_FPR(tables, FPR = 0.05)

Given the `tables` resulting from a threshold sweep, get the table that
has an FPR closest to the given value.
"""
at_FPR(tables, FPR = 0.05) = tables[argmin(abs.(tables.FPR .- FPR))]

calc_AUROCs(tables) = (;
    AUC  = trapz(tables.FPR, tables.TPR),
    AUCₑ = trapz(tables.FPR, tables.TPRₑ),
    AUCᵢ = trapz(tables.FPR, tables.TPRᵢ),
)

trapz(x, y) = begin
    auc = 0
    dx = diff(x)
    N = length(x) - 1
    for i in 1:N
        h = (y[i] + y[i+1]) / 2  # Height of trapezius in middle
        auc += h * dx[i]
    end
    return auc
end


export sweep_threshold, PredictionTable, at_FPR, calc_AUROCs

end
