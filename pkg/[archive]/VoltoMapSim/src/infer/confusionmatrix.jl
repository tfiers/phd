using Base: @kwdef
using Printf
using PrettyTables

@kwdef struct ConfusionMatrix
    TP  ::Int  # (real +, predicted +)   correct detections
    FP  ::Int  # (real -, predicted +)   wrong detections (missed rejections). Type I error
    FN  ::Int  # (real +, predicted -)   missed detections (wrong rejections). Type II error
    TN  ::Int  # (real -, predicted -)   correct rejections
    # ↑ input
    # ↓ calculated
    P    = TP + FN   # Positive
    N    = TN + FP
    PP   = TP + FP   # Predicted positive
    PN   = TN + FN
    TPR  = TP / P   # True positive rate / recall / sensitivity / power
    PPV  = TP / PP  # Positive predictive value / precision
    NPV  = TN / PN  # Negative predictive value
    FPR  = FP / N   # False positive rate / α
    FDR  = FP / PP  # = 1 - PPV. False discovery rate
    FNR  = FN / P   # = 1 - TPR. False negative rate / β
    TNR  = TN / N   # = 1 - FPR.
    FOR  = FN / PN  # = 1 - NPV. False omission rate ('omitted from detections')
    # - 'New' measures (only first is well known, as F1):
    TP_rel  = harmonic_mean(TPR, PPV)  # Correct detections. Known as F1
    FP_rel  = harmonic_mean(FPR, FDR)  # Wrong detections / missed rejections
    FN_rel  = harmonic_mean(FNR, FOR)  # Missed detections / wrong rejections
    TN_rel  = harmonic_mean(TNR, NPV)  # Correct rejections
    # - Measures summarizing all four cases:
    accuracy = (TP + TN) / (P + N)
    MCC      = (TP*TN - FP*FN) / sqrt(PP * PN * P * N)  # Matthew's correlation coefficient  / phi coefficient.
end

harmonic_mean(x...) = 1 / mean(1 ./ x)

Base.show(io::IO, m::MIME"text/plain", cm::ConfusionMatrix) = showtable(io, m, cm)
Base.show(io::IO, m::MIME"text/html", cm::ConfusionMatrix) = showtable(io, m, cm)

showtable(io, m, o) = pretty_table(io, propertytable(o); tablestyle(m,o)...)

function propertytable(o)
    names = collect(propertynames(o))
    vals = [getproperty(o, n) for n in names]
    return hcat(names, vals)
end
tablestyle(m, ::T) where T = (
    title = "$(T):",
    show_header = false,
    formatters = (v,i,j)->fmt(v),
    body_hlines = cumsum([4, 4, 8]),  # This is ConfusionMatrix specific (so no, not for 'T')
    backend = table_backend(m),
)
fmt(x::Float64) = @sprintf "%.0f%%" 100x   # Or: fmt_pct(x, 1)  # (From ../misc)
fmt(x) = x
table_backend(::MIME"text/plain") = Val(:text)
table_backend(::MIME"text/html") = Val(:html)
