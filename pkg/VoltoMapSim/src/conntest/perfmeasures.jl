
function perfmeasures(tc::DataFrame)
    # `tc` is a `tested_connections` table, with `predtype` (prediction) column.
    conntypes = [:unconn, :exc, :inh]
    conntypes_matrix = [(pred, real) for pred in conntypes, real in conntypes]
    counts = similar(conntypes_matrix, Int)  # Detection counts
    for (i, (pred, real)) in enumerate(conntypes_matrix)
        counts[i] = count((tc.predtype .== pred) .& (tc.conntype .== real))
    end
    N = length(conntypes)
    sensitivities  = Vector(undef, N)  # aka TPRs
    precisions     = Vector(undef, N)
    for i in 1:N
        num_correct   = counts[i,i]
        num_real      = sum(counts[:,i])
        num_predicted = sum(counts[i,:])
        sensitivities[i] = num_correct / num_real
        precisions[i]    = num_correct / num_predicted
    end
    return (; counts, sensitivities, precisions, conntypes, conntypes_matrix)
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
    fmt_pct(x) = join([round(Int, 100x), "%"])
    table[sens_row, titlecol]  = "Sensitivity"
    table[sens_row, datacols] .= fmt_pct.(data.sensitivities)
    table[titlerow, prec_col]  = "Precision"
    table[datarows, prec_col] .= fmt_pct.(data.precisions)
    title = join(["Tested connections: ", sum(data.counts)])
    bold_cells = vcat([(titlerow,c) for c in 1:ncols], [(r,titlecol) for r in 1:nrows])
    return DisplayTable(table, title, bold_cells)
end
