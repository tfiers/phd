# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.7
#   kernelspec:
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-09-01 • 1144 weights

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

d = 1
p = get_params(
    duration = 10minutes,
    p_conn = 0.04,
    g_EE = 1 / d,
    g_EI = 1 / d,
    g_IE = 4 / d,
    g_II = 4 / d,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
    record_v = [1:40; 801:810],
);

# ## Run sim

s = cached(sim, [p.sim]);

s = augment_simdata(s, p);

# + [markdown] heading_collapsed=true
# ## Plot firing rates

# + hidden=true
using PyPlot

# + hidden=true
using VoltoMapSim.Plot

# + hidden=true
histplot_fr(s.spike_rates);

# + hidden=true
rasterplot(s.spike_times, tlim=[0,1]);
# -

# ## Connection tests

# (Using the new connection test and performance evaluation where we also predict exc or inh).
# -- though results for unconnected are unchanged, so we can still compare with previous mass-eval (`2022-07-23__Record_many`).

using Base.Threads

detrates = Dict()
neurons = p.sim.network.record_v
pbar = Progress(length(neurons))
@threads for m in neurons
    perf = cached_conntest_eval(s, m, p, verbose = false)
    detrates[m] = perf.detection_rates
    next!(pbar)
end

# ## Plot perf

exc_post = [1:40;]
inh_post = [801:810;];

function detplot(ids, groupname)
    N = length(ids)
    ax = ydistplot(
        "Exc. inputs" => [detrates[n].TPR_exc for n in ids],
        "Inh. inputs" => [detrates[n].TPR_inh for n in ids],
        "Unconn." => [detrates[n].FPR for n in ids],
        ylim = [0,1],
        hylabel = "Detection rates for $(groupname) neurons (n = $N)",
        ref = p.evaluation.α,
    )
    return nothing
end;

detplot(exc_post, "excitatory")

detplot(inh_post, "inhibitory")

# Interesting!
# 1. Higher-than-α FPR exists here too
# 2. E→E is detected here!
#
# (compare with `2022-07-23 • Record many neurons`, where E→E is not detected at all).

# In `2022-05-13 • Network`, we had (only for 1 neuron instead of 40) low E→E detectability, no I→E detectability, and lower than α FPR.
# But that net had the mistaken '1414' connection strength params (inh _inputs_ 4x as strong, instead of outputs).

# ## Inspect performance

# + tags=["output_scroll"]
m = 1
perf = cached_conntest_eval(s,m,p)
ENV["LINES"] = 100  # display all rows of table
perf.tested_neurons
# -

# ### Inhibitory input misclassified

# one inh misclassified:

Plot.plotSTA(from::Int, to::Int, s, p, kw...) = plotSTA(s.signals[to].v, s.spike_times[from], p, kw...)
plotSTA(831, 1, s, p);

# Not so clear. A clearer one:

plotSTA(894, 1, s,p);

# But yeah, it would be fixed with a shorter STA window.

# ### Exc input misclassified

plotSTA(145, 1, s,p);

plotSTA(681, 1, s,p);

# And again, shorter window would mitigate.

# ## Average STA window

# ```
# For every recorded (exc) neuron..
#     for all it's (exc) inputs..
#         calc STA, and grand average all those
# ```

calcSTA(from::Int, to::Int, s, p) = calc_STA(s.signals[to].v, s.spike_times[from], p);

function calcMeanSTA(post; pre)
    avgSTA = nothing
    N = 0
    @showprogress for n in post
        ii = s.input_info[n]
        if pre == :exc
            inputs = ii.exc_inputs
        elseif pre == :inh
            inputs = ii.inh_inputs
        elseif pre == :FP
            perf = cached_conntest_eval(s,n,p)
            tn = perf.tested_neurons
            is_FP = (tn.real_type .== :unconn) .& (tn.predicted_type .!= :unconn)
            inputs = tn.input_neuron_ID[is_FP]
        end
        for m in inputs
            STA = calcSTA(m, n, s, p)
            if isnothing(avgSTA) avgSTA = STA
            else avgSTA .+= STA end
            N += 1
        end
    end
    return avgSTA ./ N
end;

avgSTA_EE = calcMeanSTA(exc_post, pre=:exc)
avgSTA_EI = calcMeanSTA(inh_post, pre=:exc)
avgSTA_IE = calcMeanSTA(exc_post, pre=:inh)
avgSTA_II = calcMeanSTA(inh_post, pre=:inh);

avgSTA_FP_E = calcMeanSTA(exc_post, pre=:FP)
avgSTA_FP_I = calcMeanSTA(inh_post, pre=:FP);

function Plot.plotsig(x, p::ExpParams; tscale = ms, kw...)
    duration = length(x) * p.sim.general.Δt
    t = linspace(zero(duration), duration, length(x)) / tscale
    xlabel = (tscale == ms) ? "Time (ms)" : 
             (tscale == seconds) ? "Time (s)" :
             (tscale == minutes) ? "Time (minutes)" : ""
    plotsig(t, x; xlabel, kw...)
end;

plotsig(avgSTA_EE / mV, p, hylabel="Average E→E STA (mV)", ylim=[-49.4, -48]); plt.subplots();
plotsig(avgSTA_EI / mV, p, hylabel="Average E→I STA (mV)", ylim=[-49.4, -48]); plt.subplots();
plotsig(avgSTA_IE / mV, p, hylabel="Average I→E STA (mV)", ylim=[-51, -48.5]); plt.subplots();
plotsig(avgSTA_II / mV, p, hylabel="Average I→I STA (mV)", ylim=[-51, -48.5]); plt.subplots();
plotsig(avgSTA_FP_E / mV, p, hylabel="Average FP→E STA (mV)"); plt.subplots();
plotsig(avgSTA_FP_I / mV, p, hylabel="Average FP→I STA (mV)");

# Inhibitory neurons seem to have a lower average voltage, from looking at their STA baselines.

# +
avg_voltage(group) = mean([mean(s.signals[n].v) for n in group])

avg_voltage(exc_post) / mV
# -

avg_voltage(inh_post) / mV

# Yup, that tracks.

# For the average false positive STAs, we indeed see the 2 x (propagation + integration delay) (± 40 ms) dip seen before.

# ## Disynaptic false positive (FP) hypothesis

# We suspect false positive detections are due to an intermediary connected neuron.
#
# A → B → C
#
# A fires, makes B fire¹, which generates a PSP in the recorded neuron C.
#
# But this PSP happens with a larger delay after the A spike than if A would be directly connected to C.
#
# So let's test if the peak of the STA of unconnected-but-detected (i.e. FP) neurons occurs later than the peak of non-detected unconnected neurons (the timing of which should be random).
#
#
# ¹(sometimes at least)

tn = perf.tested_neurons;
# We'll add columns: for every neuron (tp exc, tp inh, fp, tn),
# we'll calc when the peak occurs (max or min, depending on area-over-start) and add that.

m = 1;

peak_over_start = Float64[]
peakpos_ms = Float64[]
for row in eachrow(tn)
    STA = calcSTA(row.input_neuron_ID, m, s,p)
    f = (row.area_over_start > 0) ? findmax : findmin
    peak, peakpos = f(STA)
    push!(peak_over_start, (peak - STA[1]) / mV)
    push!(peakpos_ms, peakpos * p.sim.general.Δt / ms)
end
tn.peak_over_start = peak_over_start
tn.peakpos_ms = peakpos_ms;

ENV["COLUMNS"] = 100;  # show all columns of df

# + tags=["output_scroll"]
ydistplot(
    jn("Exc inputs,", "detected")          => tn.peakpos_ms[(tn.real_type .== :exc) .& (tn.predicted_type .== :exc)],
    jn("Inh inputs,", "detected")          => tn.peakpos_ms[(tn.real_type .== :inh) .& (tn.predicted_type .== :inh)],
    jn("Unconnected,", "not detected")     => tn.peakpos_ms[(tn.real_type .== :unconn) .& (tn.predicted_type .== :unconn)],
    jn("Unconnected", "but detected (FP)") => tn.peakpos_ms[(tn.real_type .== :unconn) .& (tn.predicted_type .!= :unconn)],
    figsize = (5, 2.4),
    hylabel = "Position of STA peak", 
    ylabel = "ms after presynaptic spike",
);
# -


