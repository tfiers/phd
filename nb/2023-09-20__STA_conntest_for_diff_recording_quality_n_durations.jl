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

# Guess we could also set an absolute value, like clip at 0 or -20 mV or sth.\
# But in VI recordings there is no scale.
#
# Maybe there's some other way. Aren't those spikes bunched/clustered? yeah! i suppose they are..\
# So we do.. uhm.. clustering on V distribution? I kinda like it..\
# "Oja's algorithm"? ooooh yeah.\
# no wait, that's sth else.\
# But there is a similar sounding algorithm, used in quantization/discretization.\
# Splitting sth (a distribution) in two..
#
# **Otsu's method**!
#
# https://github.com/mdhumphries/HierarchicalConsensusClustering/blob/master/Helper_Functions/otsu1D.m

# ## Test conns

cachedir = "2023-09-20__STA_conntest_for_diff_recording_quality_n_durations";

sim_ = CachedFunction(Nto1AdEx.sim, cachedir; disk=false, duration=10minutes, N)

MemDiskCache.set_dir(cachedir);

MemDiskCache.open_dir()

function sim_and_test(; duration=10minutes, VI_SNR=Inf, seed=1)
    sim = sim_(; duration, seed)
    sig = VI_sig(sim, spike_SNR=VI_SNR)
    sigc = clip!(sig, clip_pctile)
    key = "sim_and_test" * string((; duration, VI_SNR, seed)) * "__rows"
    rows = @cached key test_high_firing_inputs(sim, sigc)
    # ↪ every row is a putative connection. (real type, t-val, presyn fr)
    df = DataFrame(rows)
    sweep = sweep_threshold(df)
    return (; sim, sigc, df, sweep)
end;

maxF1(sweep) = maximum(skipnan(sweep.F1));

# ↓ expected runtime: 8 SNRs x 5 seeds x 56 seconds = 37 minutes

SNRs = [Inf, 100, 40, 20, 10, 4, 2, 1];

rows = []
@time for VI_SNR in SNRs
    for seed in 1:5
        kw = (; duration, VI_SNR, seed)
        key = "sim_and_test$(kw)__sweep"
        row = @cached key begin
            (; sweep) = sim_and_test(; VI_SNR, seed)
            F1max = maxF1(sweep)
            (; AUC) = calc_AUROCs(sweep)
            row = (; VI_SNR, seed, F1max, AUC)
        end
        push!(rows, row)
        #println("\n", row, "\n"^2)
    end
end;

df = df_snr = DataFrame(rows)
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

# ## Plot

fmt(x) = isinf(x) ? "∞" : round(Int, x);

plot_F1(df, xcol; ax=newax(), title=true, kw...) = begin
    plot_dots_and_means(df, xcol, :F1max; ax, ytype=:frac, color_means=C0, ylabel=nothing, kw...)
    deemph_middle_ticks(ax.yaxis)
    t = hylabel(ax, L"Maximum $F_1$-score (mean of Recall & Precision)")
    title && ax.annotate("Connection detection performance of STA test", fontweight="bold",
                         xy=(0, 1.3), xycoords=t, va="bottom")
    return ax
end;

xlabel = "Voltage imaging noise (spike-SNR)"
xticklabels=fmt.(SNRs);

plot_F1(df_snr, :VI_SNR; xtype=:cat, xlabel, xticklabels);
savefig_phd("STA_perf_diff_snr_F1");

plot_F1(df_snr, :VI_SNR; xtype=:cat, xlabel, xticklabels);
# savefig_phd("STA_perf_diff_snr_F1");

plot_AUC(df, xcol; ax=newax(), chance_level_loc=:left, title=true, kw...) = begin
    color = "gray"
    chance_level = 0.252  # See section below :)
    l = ax.axhline(chance_level; lw=1, ls="--", color)
    if chance_level_loc == :left
        xy = (0,0)
        ha = "left"
    else
        xy = (1,0)
        ha = "right"
    end
    ax.annotate("Chance level"; xycoords=l, xy, ha, va="bottom", color)
    
    plot_dots_and_means(df, xcol, :AUC; ax, ylim=[0,1], ylabel=nothing, kw...)
    deemph_middle_ticks(ax.yaxis)
    t = hylabel(ax, "Area under ROC curve (AUC)");
    title && ax.annotate("Connection detection performance of STA test", fontweight="bold",
                         xy=(0, 1.3), xycoords=t, va="bottom");
    return ax
end;

plot_AUC(df_snr, :VI_SNR; xtype=:cat, xticklabels, xlabel);
# savefig_phd("STA_perf_diff_snr_auc");

# One fig. Tighter ylims.

fig, (ax_top, ax_btm) = plt.subplots(nrows=2, figsize=(mtw,1.1mtw), height_ratios=[1,1.2])
xlabel = ("Voltage imaging noise (spike-SNR)", :fontweight=>"bold")
xticklabels=fmt.(SNRs)
plot_F1(df_snr, :VI_SNR; xtype=:cat, ylim=[0.4, 1], ax=ax_top, title=false, xlabel=nothing)
rm_ticks_and_spine(ax_top, "bottom")
plot_AUC(df_snr, :VI_SNR; xtype=:cat, ylim=[0, 1], ax=ax_btm, title=false, xlabel, xticklabels);
fig.suptitle("Connection detection performance of STA test", x=0.5155)
plt.tight_layout(h_pad=1.7);
savefig_phd("STA_perf_diff_snr");

# ## Comparing AUC and F1max directly.

gd = groupby(df_snr, :VI_SNR)
dfm = combine(gd, [:F1max, :AUC] .=> mean, renamecols=false)

ax=newax(figsize=(2.2, 2.2));
plot([0,1], [0,1], "--"; ax, c="lightgrey")
plot(dfm.AUC, dfm.F1max, ".-"; ax, aspect="equal", xlim=[0,1], ylim=[0,1],
     xlabel="AUC", ylabel=L"\max\ F_1", ytype=:fraction);
deemph_middle_ticks(ax);

# ## Longer recording

plotsig(VI_sig(sim; spike_SNR=40), tlim, ms, yunit=:mV);

# Sure, I can see that happening.

out = @cached "longer_rec" sim_and_test(duration=60minutes, VI_SNR=40);

(; sweep) = out
maxF1(sweep)

calc_AUROCs(sweep)

# ## Chance level
#
# What is AUROC chance level for our weird ternary classification.

# Assign classes randomly. Or rather give random connectedness-scores (t-vals).

# +
random_test_result(Nₜ = 100) = begin
    conntype = repeat([:exc, :inh, :unc], inner=Nₜ)
    N = length(conntype)
    t = 2*rand(N) .- 1  # Uniform in [-1, 1]
    df = DataFrame(; conntype, t)
end

for _ in 1:5
    df = random_test_result()
    sweep = sweep_threshold(df)
    println(calc_AUROCs(sweep))
end
# -

# So chance level is even less than 0.333

ax = plotROC(sweep, legend_loc="upper center")
deemph_middle_ticks(ax);

random_test_AUC() = calc_AUROCs(sweep_threshold(random_test_result())).AUC
@time random_test_AUC()

rm_from_memcache!("random_test_AUCs")
rm_from_disk("random_test_AUCs")

Random.seed!(1234)
random_test_AUCs = @cached "random_test_AUCs" [random_test_AUC() for _ in 1:300];

# (4 seconds)

# +
(; ConnectionPatch) = mpl.patches;

function connect(axA, axB, xyA, xyB=xyA; lw=0.8, ls="--", color=Gray(0.4), kw...)
    fig = axA.figure
    con = ConnectionPatch(xyA, xyB, axA.transData, axB.transData; lw, ls, color=toRGBAtuple(color), kw...)
    fig.add_artist(con)
end;
# -

fig, (ax_top, ax_btm) = plt.subplots(nrows=2, figsize=(4, 2.2))
distplot(random_test_AUCs; ax=ax_top, xlim=[0, 1], lines=false)
distplot(random_test_AUCs; ax=ax_btm, xlabel="Area under ROC curve (AUC)")
deemph_middle_ticks(ax_top)
xl, xr = ax_btm.get_xlim()
yb, yt = ax_top.get_ylim()
connect(ax_top, ax_btm, (xl, yb), (xl, yt))
connect(ax_top, ax_btm, (xr, yb), (xr, yt))
ax_top.vlines([xl, xr], yb, yt, color=toRGBAtuple(Gray(0.4)), lw=0.8)
fig.suptitle("Performance of random connection classifier")
plt.tight_layout(h_pad=2.6);
savefig_phd("AUC_chance_level")

random_test_maxF1() = maxF1(sweep_threshold(random_test_result()))
random_test_maxF1()

Random.seed!(1234)
random_test_F1s = @cached "random_test_F1s" [random_test_maxF1() for _ in 1:300];

mean(random_test_F1s), median(random_test_F1s)

# ## Vary recording duration

durations = [10seconds, 30seconds, 1minute, 2minutes, 4minutes, 10minutes, 20minutes, 30minutes, 1hour]
VI_SNR = 40;

rows = []
@time for duration in durations
    for seed in 1:5
        kw = (; VI_SNR, duration, seed)
        key = "sim_and_test$(kw)__sweep_row"
        row = @cached key begin
            (; sweep) = sim_and_test(; kw...)
            F1max = maxF1(sweep)
            (; AUC) = calc_AUROCs(sweep)
            row = (; duration, seed, F1max, AUC)
        end
        push!(rows, row)
        # println("\n", row, "\n"^2)
    end
end;

# Running all this took:

6687.8 / minutes

# Holy damn, discovered a bug.\
# (For 10second duration: exc and inh test instant, but uncon suspiciously slow).\
# Reason: in `get_trains_to_test` (from `lib/Nto1.jl`), `duration` is a global var.\
# [This is one discovered disadvantage of a script vs a module!! Name leakage vs encapsulation].
#
# ok, turned out this didn't have an effect on the results. good.

df = df_duration = DataFrame(rows)
df.duration = df.duration / minutes
df

kw = (
    xlabel = "Recording duration",
    xscale = "log",
    xticklabels = ["6 sec", "1 min", "10 min", "1 hr 40"],
);

plot_F1(df_duration, :duration; kw...);
# savefig_phd("STA_perf_diff_dur_F1")

plot_AUC(df_duration, :duration; kw..., chance_level_loc=:right);
# savefig_phd("STA_perf_diff_dur_auc")

xlabel = ("Recording duration", :fontweight=>"bold")
xscale = "log"
xticklabels = ["6 sec", "1 min", "10 min", "1 hr 40"]
fig, (ax_top, ax_btm) = plt.subplots(nrows=2, figsize=(mtw,1.1mtw), height_ratios=[1,1.2])
plot_F1(df_duration, :duration; xscale, ylim=[0.4, 1], ax=ax_top, title=false, xlabel=nothing)
rm_ticks_and_spine(ax_top, "bottom")
plot_AUC(df_duration, :duration;
         ylim=[0, 1], ax=ax_btm, title=false, xscale, xlabel, xticklabels, chance_level_loc=:right);
fig.suptitle("Connection detection performance of STA test", x=0.5155)
plt.tight_layout(h_pad=1.7);
savefig_phd("STA_perf_diff_rec_duration");

# ## Computation time

# Read out from cache files on disk.

VI_SNR = 40;
rows = []
@time for duration in durations
    for seed in 1:5
        key = "sim_and_test" * string((; duration, VI_SNR, seed)) * "__rows"
        runtime = get_runtime(key)
        row = (; duration, seed, runtime)
        push!(rows, row)
        # println("\n", row, "\n"^2)
    end
end;

df = df_runtimes = DataFrame(rows)
df.duration .= df.duration / minutes
df.runtime .= df.runtime / minutes
df

ax = newax()
x1 = df.duration[1]
x2 = df.duration[end]
ax.plot([x1,x2], [x1,x2], "--", c="lightgray");
plot_dots_and_means(
    df_runtimes, :duration, :runtime; xscale="log", yscale="log", ax,
    xticklabels,
    xlabel = "Simulated duration (minutes)",
    ylabel = "Runtime (minutes)",
);


