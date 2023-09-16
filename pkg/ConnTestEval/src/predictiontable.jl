
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

    PredictionTable(θ, tvals, conntypes) = begin
        preds = predicted_types(tvals, θ)
        cm = confusion_matrix(conntypes, preds)
        (; TPRₑ, TPRᵢ, TPR, FPR) = detection_rates(cm)
        new(θ, tvals, conntypes, preds, cm, TPRₑ, TPRᵢ, TPR, FPR)
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

detection_rates(cm) = begin
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
    PP  = TP + FP  # Predicted positive
    return (;
        TPRₑ = TPₑ / Pₑ,
        TPRᵢ = TPᵢ / Pᵢ,
        TPR  = TP  / P,
        FPR  = FP  / N,
        PPV  = TP  / PP,
    )
end

detection_rates(p::PredictionTable) = (;
    p.TPRₑ,
    p.TPRᵢ,
    p.TPR,
    p.FPR,
)

count(cm; real=:, pred=:) = sum(cm[index(real), index(pred)])

index(x::Colon) = x
index(conntype) =
    ( conntype == :exc ?  1  :
      conntype == :inh ?  2  :
      conntype == :unc ?  3  :
      error("Unknown connection type `$conntype`") )


# See VoltoMapSim/src/infer/confusionmatrix.jl for more measures, and
# relations between them.

TPR(p::PredictionTable) = p.TPR  # True positive rate / recall / sensitivity / power
PPV(p::PredictionTable) =        # Positive predictive value / precision
    detection_rates(p.confusion_matrix).PPV

F1(p::PredictionTable) = harmonic_mean(TPR(p), PPV(p))

harmonic_mean(x...) = 1 / mean(1 ./ x)
mean(x) = sum(x) / length(x)

export PPV, F1



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
