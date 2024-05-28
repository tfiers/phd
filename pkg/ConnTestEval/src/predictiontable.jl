
using StructArrays
using CreateNamedTupleMacro


export PredictionTable, skipnan, Fβ, print_confusion_matrix


struct PredictionTable{NT<:NamedTuple}
    threshold        ::Float64
    tvals            ::Vector{Float64}
    real_types       ::Vector{Symbol}
    # ↑ inputs
    # ↓ calculated
    predicted_types  ::Vector{Symbol}
    confusion_matrix ::Matrix{Int}     # Indexed as [real type, predicted type]
    perfmeasures     ::NT
        # We use a NamedTuple (instead of having all the performance
        # measures as separate fields here), so we can add measures
        # without redefining the struct, and thus having to reload the
        # Julia session.
end

PredictionTable(θ, tvals, conntypes) = begin
    tvals = Vector{Float64}(tvals)
    conntypes = Vector{Symbol}(conntypes)
    preds = predicted_types(tvals, θ)
    cm = confusion_matrix(conntypes, preds)
    pm = perfmeasures(cm)
    PredictionTable(θ, tvals, conntypes, preds, cm, pm)
end

predicted_types(tvals, θ) = [classify(t, θ) for t in tvals]

classify(t, θ) =
    ( abs(t) ≤ θ ?  :unc  :
      t > 0      ?  :exc  :
                    :inh  )

confusion_matrix(real_types, predicted_types) = begin
    cm = zeros(Int, 3, 3)  # (Could be a StaticArray)
    for (real, pred) in zip(real_types, predicted_types)
        cm[index(real), index(pred)] += 1
    end
    return cm
end

count(cm; real=:, pred=:) = sum(cm[index(real), index(pred)])

index(x::Colon) = x
index(conntype) =
    ( conntype == :exc ?  1  :
      conntype == :inh ?  2  :
      conntype == :unc ?  3  :
      error("Unknown connection type `$conntype`") )


perfmeasures(cm) = @NT begin

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

    # Detection rates
    TPRₑ = TPₑ / Pₑ
    TPRᵢ = TPᵢ / Pᵢ
    TPR  = TP  / P     # True positive rate / recall / sensitivity / power
    FPR  = FP  / N     # False positive rate / α

    # PP: Predicted Positive
    PPₑ = count(cm, pred=:exc)
    PPᵢ = count(cm, pred=:inh)
    PP  = PPₑ + PPᵢ
    PN  = count(cm, pred=:unc)

    # The positive precision values below are `NaN` for the highest threshold.
    # (There are no detections, i.e. zero 'predicted positive'). More
    # proper might be to detect `PP == 0`, and then assigning `missing`.
    # But NaNs allow directly passing precision vectors to maptlotlib :)
    # For other uses of these vectors (e.g. using `argmax`), see
    # `skipnan` below.
    PPV  = TP  / PP     # Positive predictive value / precision
    PPVₑ = TPₑ / PPₑ    # "Out of all that's predicted 'exc', how many actually are"
    PPVᵢ = TPᵢ / PPᵢ
    NPV  = TN  / PN     # Negative predictive value. NaN for threshold = 0.

    # (Weighted) harmonic means of recall and precision.
    # I.e. detection ability from the POV of the ground truth (recall)
    # and from the POV of the experimenter (precision).
    F1  = Fβ(PPV,  TPR,  β=1)
    F1ₑ = Fβ(PPVₑ, TPRₑ, β=1)
    F1ᵢ = Fβ(PPVᵢ, TPRᵢ, β=1)
    # Recall weighted more heavily:
    F2  = Fβ(PPV,  TPR,  β=2)
    F2ₑ = Fβ(PPVₑ, TPRₑ, β=2)
    F2ᵢ = Fβ(PPVᵢ, TPRᵢ, β=2)
    # Precision weighted more heavily:
    F05  = Fβ(PPV,  TPR,  β=0.5)
    F05ₑ = Fβ(PPVₑ, TPRₑ, β=0.5)
    F05ᵢ = Fβ(PPVᵢ, TPRᵢ, β=0.5)

    # Aliases
    recall = TPR
    precision = PPV

    # See VoltoMapSim/src/infer/confusionmatrix.jl for more measures,
    # and relations between them.
end

"""
    skipnan(itr)

Replaces `NaN` values by `missing`, and then applies `skipmissing`.
Allows working with vectors containing some NaNs, while ignoring these
NaNs (e.g. in `argmax`).
"""
skipnan(itr) = skipmissing([isnan(x) ? missing : x for x in itr])


"""
    Fβ(precision, recall; β=1)

"``F_β`` measures the effectiveness of retrieval for a user who attaches
``β`` times as much importance to recall as to precision".
"""
Fβ(precision, recall; β=1) = (
    (1 + β^2) * precision * recall
                    /
     ((β^2 * precision) + recall)
)




# ---------------------------------------------------------------------
#
# Pretend like PredictionTable has as its own fields all the properties
# in the `perfmeasures` field, both as a single object, and when part of
# a StructVector (see `sweep_threshold`).
#
Base.propertynames(p::PredictionTable) = [
    fieldnames(PredictionTable)...,
    keys(p.perfmeasures)...,
]
#
Base.getproperty(p::PredictionTable, name::Symbol) =
    if name in fieldnames(PredictionTable)
        getfield(p, name)
    else
        p.perfmeasures[name]
    end
#
#
# https://juliaarrays.github.io/StructArrays.jl/stable/advanced/#Structures-with-non-standard-data-layout
# (Lotsa work here below to make it typestable. Could spare it by just not having `NT` typeparam in struct).
#
StructArrays.staticschema(::Type{PredictionTable{NamedTuple{names,types}}}) where {names,types} =
    NamedTuple{(fieldnames(PredictionTable)..., names...),
               Tuple{fieldtypes(PredictionTable)..., types.parameters...}}
#
StructArrays.component(p::PredictionTable, name::Symbol) = getproperty(p, name)
#
StructArrays.createinstance(::Type{PredictionTable{NamedTuple{names}}}, args...) where {names} = begin
    N = fieldcount(PredictionTable)
    PredictionTable(args[1:(N-1)]..., NamedTuple{names}(args[N:end]))
end



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

# For when shown as part of a StructVector (by default, this is
# extremely noisy, with the NamedTuple type param) (typical Julia).
# Here, we make it short and sweet. (Full type info is still given when
# printing the StructVector; namely after "eltype: "). The "with" here
# is to not give the impression that you can construct a new
# PredictionTable from the info between brackets :).
Base.show(io::IO, p::PredictionTable) =
    print(io, PredictionTable, " with ", (; p.threshold, p.PPₑ, p.PPᵢ, p.FP))

Base.show(io::IO, ::MIME"text/plain", p::PredictionTable) = begin
    println(io, PredictionTable, "\n")
    println(io, "t-values and connection types (actual and predicted):\n")
    print_table(io, rows(p))
    println(io, "\n", "Threshold: ", p.threshold, "\n")
    println(io, confusion_matrix_string(p.confusion_matrix), "\n")
    for name in keys(p.perfmeasures)
        val = p.perfmeasures[name]
        if val isa AbstractFloat
            val = round(val, digits=2)
        end
        println(io, rpad(name, 4), ": ", val)
    end
end

print_table(io, rows) =
    if isdefined(Main, :PrettyTables) && isdefined(Main, :pretty_table)
        @eval Main pretty_table($io, $rows, show_subheader=false, tf=tf_compact)
    else
        for r in rows
            println(io, r)
        end
    end
