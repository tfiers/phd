
export PredictionTable, print_confusion_matrix, Fβ, F2, missing_to_nan


struct PredictionTable
    threshold        ::Float64
    tvals            ::Vector{Float64}
    real_types       ::Vector{Symbol}
    predicted_types  ::Vector{Symbol}
    confusion_matrix ::Matrix{Int}    # Indexed as [real type, predicted type]
    TPRₑ             ::Float64
    TPRᵢ             ::Float64
    TPR              ::Float64
    FPR              ::Float64
    PPV              ::Union{Float64,Missing}
    F1               ::Union{Float64,Missing}

    PredictionTable(θ, tvals, conntypes) = begin
        preds = predicted_types(tvals, θ)
        cm = confusion_matrix(conntypes, preds)
        new(θ, tvals, conntypes, preds, cm, perfmeasures(cm)...)
    end
end

predicted_types(tvals, θ) = [classify(t, θ) for t in tvals]

classify(t, θ) =
    ( abs(t) ≤ θ ?  :unc  :
      t > 0      ?  :exc  :
                    :inh  )

confusion_matrix(real_types, predicted_types) = begin
    cm = zeros(Int, 3, 3)
    for (real, pred) in zip(real_types, predicted_types)
        cm[index(real), index(pred)] += 1
    end
    return cm
end

perfmeasures(cm) = begin
    # Count positives (P), true positives (TP), etc.
    Pₑ  = count(cm, real=:exc)
    TPₑ = count(cm, real=:exc, pred=:exc)
    Pᵢ  = count(cm, real=:inh)
    TPᵢ = count(cm, real=:inh, pred=:inh)
    N   = count(cm, real=:unc)
    TN  = count(cm, real=:unc, pred=:unc)
    P   = Pₑ + Pᵢ
    TP  = TPₑ + TPᵢ
    FP  = N - TN
    PP  = TP + FP      # Predicted positive

    TPRₑ = TPₑ / Pₑ
    TPRᵢ = TPᵢ / Pᵢ
    TPR  = TP  / P     # True positive rate / recall / sensitivity / power
    FPR  = FP  / N
    if PP > 0
        PPV = TP / PP  # Positive predictive value / precision
    else
        PPV = missing
    end
    F1 = harmonic_mean(TPR, PPV)
    # See VoltoMapSim/src/infer/confusionmatrix.jl for more measures,
    # and relations between them.

    return (; TPRₑ, TPRᵢ, TPR, FPR, PPV, F1)
end

count(cm; real=:, pred=:) = sum(cm[index(real), index(pred)])

index(x::Colon) = x
index(conntype) =
    ( conntype == :exc ?  1  :
      conntype == :inh ?  2  :
      conntype == :unc ?  3  :
      error("Unknown connection type `$conntype`") )

harmonic_mean(x...) = 1 / mean(1 ./ x)
mean(x) = sum(x) / length(x)

precision(p::PredictionTable) = p.PPV
recall(p::PredictionTable) = p.TPR

"""
    Fβ(p::PredictionTable, β)

"F_β measures the effectiveness of retrieval for a user who attaches β
times as much importance to recall as to precision"
"""
Fβ(p::PredictionTable, β) = begin
    precision = p.PPV
    recall = p.TPR
    return (1 + β^2) * (precision * recall) / ((β^2 * precision) + recall)
end
F2(p::PredictionTable) = Fβ(p, 2)


# When plotting a precision or F1 series, the value for threshold = 0
# will be 'missing'. (There are zero detections, so there is no
# 'precision' of the detections to speak off). We can't plot 'missing'
# values, but we _can_ plot NaN. You can thus plot, e.g:
# `missing_to_nan.(sweep.PPV)`.
missing_to_nan(x) = coalesce(x, NaN)



# ---------------
# --- Display ---
# ---------------

print_confusion_matrix(p::PredictionTable) =
    println(confusion_matrix_string(p.confusion_matrix))

confusion_matrix_string(cm) = begin
    s = """
                  Predicted
               exc   inh   unc
          exc XXXX  XXXX  XXXX
    Real  inh XXXX  XXXX  XXXX
          unc XXXX  XXXX  XXXX
    """
    # Julia is 'column-major', which means it goes [1,1], [2,1], ..
    for count in transpose(cm)
        s = replace(s, "XXXX"=>lpad(count, 4), count=1)
    end
    return s
end

rows(p::PredictionTable) = [
    (; t, real, pred)
    for (t, real, pred)
    in zip(
        p.tvals,
        p.real_types,
        p.predicted_types,
    )
]

Base.show(io::IO, ::MIME"text/plain", p::PredictionTable) = begin
    println(io, PredictionTable, "\n")
    println(io, "Threshold: ", p.threshold, "\n")
    println(io, confusion_matrix_string(p.confusion_matrix), "\n")
    for name in [:TPRₑ, :TPRᵢ, :TPR, :FPR]
        val = getproperty(p, name)
        println(io, rpad(name, 4), ": ", round(val, digits=2))
    end
    println(io)
    print_table(io, rows(p))
end

print_table(io, rows) =
    for r in rows
        println(io, r)
    end
    # If user did `using PrettyTables`, could do instead:
    # pretty_table(io, rows, show_subheader=false, tf=tf_compact)
