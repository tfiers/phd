
function perfmeasures(tc::DataFrame)
    # `tc` is a `tested_connections` table, with `predtype` (prediction) column.
    ix = idvec(:unconn, :exc, :inh)
    conntypes = keys(ix)
    conntypes_matrix = [(pred, real) for pred in conntypes, real in conntypes]
    counts = similar(conntypes_matrix, Int)  # Prediction counts
    for (i, (pred, real)) in enumerate(conntypes_matrix)
        counts[i] = count((tc.predtype .== pred) .& (tc.conntype .== real))
    end
    # The below comprehensions become CVecs, like `ix`
    num_correct = [counts[i,i] for i in ix]
    num_real    = [sum(counts[:,i]) for i in ix]
    num_pred    = [sum(counts[i,:]) for i in ix]
    sensitivity = num_correct ./ num_real  # aka TPR
    precision   = num_correct ./ num_pred
    return (;
        ix,
        conntypes,
        counts,
        num_correct,
        num_real,
        num_pred,
        sensitivity,
        precision,
    )
end


function perftable(tested_connections::DataFrame)
    # Creates a nicely-printing table with performance measures.
    data = perfmeasures(tested_connections)
    titlerow = titlecol = 1
    grouprow = groupcol = 2
    datarows = datacols = 3:5
    sens_row = prec_col = 7
    nrows    = ncols    = 7
    table = Matrix{Any}(undef, nrows, ncols)
    fill!(table, "")
    table[grouprow, datacols] .= data.conntypes
    table[datarows, groupcol] .= data.conntypes
    table[datarows, datacols] .= data.counts
    table[titlerow, datacols] .= ["┌───────", "Real type", "───────┐"]
    table[datarows, titlecol] .= [
        "             ┌",
        "Predicted type",
        "             └",
    ]
    table[sens_row, titlecol]  = "Sensitivity"
    table[sens_row, datacols] .= fmt_pct.(data.sensitivity)
    table[titlerow, prec_col]  = "Precision"
    table[datarows, prec_col] .= fmt_pct.(data.precision)
    title = join(["Tested connections: ", sum(data.counts)])
    bold_cells = vcat([(titlerow,c) for c in 1:ncols], [(r,titlecol) for r in 1:nrows])
    return DisplayTable(table, title, bold_cells)
end
