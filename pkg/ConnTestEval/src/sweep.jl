
using StructArrays


export sweep_threshold, calc_AUROCs, at_FPR


"""
    sweep_threshold(df)
    sweep_threshold(tvals, conntypes)

Given a list of 't-values' and a corresponding list of true connection
types, apply all possible thresholds to these t-values, and return the
resulting list of [`PredictionTable`](@ref)s, as a `StructVector`.

We return a `StructVector` so that you can call e.g. `sweep.FPR` on the
returned object, to get a list of `FPR` values for the different applied
thresholds (see [`thresholds`](@ref))

The two input lists can be given separately, or as part of a DataFrame,
in which case it should have a column named `t` and a column named
`conntype`.
"""
sweep_threshold(df) = sweep_threshold(df.t, df.conntype)

sweep_threshold(tvals, conntypes) = StructVector(
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

Given the `StructVector` of `PredictionTable`s returned by
[`sweep_threshold`](@ref), get the table that has a false positive rate
closest to the given value.
"""
at_FPR(tables, FPR = 0.05) = tables[argmin(abs.(tables.FPR .- FPR))]

"""
    calc_AUROCs(tables)

Given the `StructVector` of `PredictionTable`s returned by
[`sweep_threshold`](@ref), calculate the areas under the receiving
operating characterics curves. Three AUC values are returned: one for
only excitatory inputs, one for only inhibitory, and one for both input
types together.
"""
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
