using MyToolbox: @NT

struct ConfusionMatrix
    TP::Int  # (real +, predicted +)   correct detections
    TN::Int  # (real -, predicted -)   correct rejections
    FP::Int  # (real -, predicted +)   wrong detections (missed rejections). Type I error
    FN::Int  # (real +, predicted -)   missed detections (wrong rejections). Type II error
end

Base.propertynames(cm::ConfusionMatrix) = keys(metrics(cm))
Base.getproperty(cm::T, name::Symbol) where T <: ConfusionMatrix =
    (name in fieldnames(T)) ? getfield(cm, name) : metrics(cm)[name]

metrics(cm::ConfusionMatrix) = @NT begin
    @unpack TP, TN, FP, FN = cm
    P  = TP + FN   # Positive
    N  = TN + FP
    PP = TP + FP   # Predicted positive
    PN = TN + FN
    TPR = TP / P   # True positive rate / recall / sensitivity / power
    PPV = TP / PP  # Positive predictive value / precision
    NPV = TN / PN  # Negative predictive value
    FPR = FP / N   # False positive rate / α
    FDR = FP / PP  # 1 - PPV. False discovery rate
    FNR = FN / P   # 1 - TPR. β
    TNR = TN / N   # 1 - FPR.
    FOR = FN / PN  # 1 - NPV. False omission rate ('omitted from detections')
    correct_detections = harmonic_mean(TPR, PPV)  # TP proportions. Known as F1.
    wrong_detections   = harmonic_mean(FPR, FDR)  # FP proportions. Aka missed rejections.
    correct_rejections = harmonic_mean(TNR, NPV)  # TN proportions
    missed_detections  = harmonic_mean(FNR, FOR)  # FN proportions. Aka wrong rejections.
    accuracy = (TP + TN) / (P + N)
    MCC = (TP*TN - FP*FN) / sqrt(PP * PN * P * N)  # Matthew's Correlation or Phi Coefficient.
end

harmonic_mean(x...) = 1 / mean(1 ./ x)

function Base.show(io::IO, ::MIME"text/plain", cm::ConfusionMatrix)
    println(io, "ConfusionMatrix:")
    names = propertynames(cm)
    len(n) = length(string(n))
    tabs = [0, 4, maximum(len, names)]
    pad(name) = lpad(name, tabs[findlast(len(name) .> tabs) + 1])
    for name in names
        println(io, pad(name), ": ", getproperty(cm, name))
    end
end
