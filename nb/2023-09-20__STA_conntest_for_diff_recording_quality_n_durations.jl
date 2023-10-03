# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Julia 1.9.3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-09-20 · STA conntest for diff recording quality n durations 

include("lib/Nto1.jl")

N = 6500
duration = 10minutes
@time sim = Nto1AdEx.sim(N, duration);  # ceil_spikes is true by default

# ## VI noise

# +
(; Vₛ, Eₗ) = Nto1AdEx

function VI_sig(sim; spike_SNR = 10, spike_height = (Vₛ - Eₗ), seed=1)
    Random.seed!(seed)
    σ = spike_height / spike_SNR
    sig = copy(sim.V)
    sig .+= (σ .* randn(length(sig)))
    sig
end;

sig = VI_sig(sim);
# -

include("lib/plot.jl")

plotsig(sig, [0,1000], ms, yunit=:mV);

# Very good.

VI_sig(sim, spike_SNR=Inf) == sim.V

# Excellent.

# ## Clip the VI sig

include("lib/df.jl")

ps = [95, 98, 99, 99.9, 99.95, 99.99, 100]
qs = percentile(sig, ps)
df = DataFrame("p" => ps, "V (mV)" => qs/mV)

# For the clean (no VI noise) signal, we clipped at -49.79 mV (which was there the 99 percentile)

# If we do same:

clip!(sig, p = 99) = begin
    thr = percentile(sig, p)
    to_clip = sig .≥ thr
    sig[to_clip] .= thr
    sig
end;

sigc = clip!(copy(sig), 99);

tlim=[0,1000]
plotsig(sig , tlim, ms, yunit=:mV)
plotsig(sigc, tlim, ms, yunit=:mV, yunits_in=nothing);

# Hm, we might loose some non-spike signal there?  
# So let's choose sth stricter:  (note that this is all for VI SNR 10, no systematic search.. But 10 is a realistic SNR, so, fine).

clip_pctile = 99.9
sigc = clip!(copy(sig), clip_pctile);

plotsig(sig , tlim, ms, yunit=:mV)
plotsig(sigc, tlim, ms, yunit=:mV, yunits_in=nothing);

# ## Test conns

cachedir = "2023-09-20__STA_conntest_for_diff_recording_quality_n_durations";

sim_ = CachedFunction(Nto1AdEx.sim, cachedir; disk=false, duration=10minutes, N)

MemDiskCache.set_dir(cachedir);

# +
# MemDiskCache.open_dir()
# -

function sim_and_test(; duration=10minutes, VI_SNR=Inf)
    sim = sim_(; duration)
    sig = VI_sig(sim, spike_SNR=VI_SNR)
    sigc = clip!(sig, clip_pctile)
    key = "sim_and_test" * string((; duration, VI_SNR)) * "__rows"
    rows = @cached key test_high_firing_inputs(sim, sigc)
    # ↪ every row is a putative connection. (real type, t-val, presyn fr)
    df = DataFrame(rows)
    sweep = sweep_threshold(df)
    return (; sim, sigc, df, sweep)
end

rows = []
for VI_SNR in [Inf, 100, 20, 10, 4, 2, 1]
    (; sweep) = sim_and_test(; VI_SNR)
    F1max = maximum(skipnan(sweep.F1))
    (; AUC) = calc_AUROCs(sweep)
    row = (; VI_SNR, F1max, AUC)
    push!(rows, row)
    # println("\n", row, "\n"^2)
end;

df = DataFrame(rows)
showsimple(df)

# Without clipping (from a first run, when I forgot to clip; only ceilin):
# ```
# (VI_SNR = Inf, F1max = 0.697)
# (VI_SNR = 10,  F1max = 0.469)
# (VI_SNR = 4,   F1max = 0.404)
# (VI_SNR = 2,   F1max = 0.398)
# (VI_SNR = 1,   F1max = 0.390)
# ```
# Note that, except at Inf snr, not much diff !

set_mpl_style!(sciplotlib_style);

# +
fmt(x) = isinf(x) ? "∞" : round(Int, x);

fig, ax = plt.subplots()
plot(1:nrow(df), df.F1max, ".-"; ax, xticklabels=fmt.(df.VI_SNR), ytype=:fraction, xtype=:categorical,
     xlabel="Voltage imaging noise (spike-SNR)")
t = hylabel(ax, L"Average of recall & precision at $\max\ F_1$");
ax.annotate("Connection detection performance of STA test", fontweight="bold",
            xy=(0, 1.3), xycoords=t, va="bottom");

# +
fmt(x) = isinf(x) ? "∞" : round(Int, x);

fig, ax = plt.subplots()
color = "gray"
l = ax.axhline(0.5; lw=1, ls="--", color)
ax.annotate("Chance"; xy=(1,0), xycoords=l, ha="right", va="bottom", color)
plot(1:nrow(df), df.AUC, ".-"; ax, xticklabels=fmt.(df.VI_SNR), ylim=[0,1], xtype=:categorical,
     xlabel="Voltage imaging noise (spike-SNR)", color="black")
t = hylabel(ax, "Area under ROC curve (AUC)");
ax.annotate("Connection detection performance of STA test", fontweight="bold",
            xy=(0, 1.3), xycoords=t, va="bottom");
# -




