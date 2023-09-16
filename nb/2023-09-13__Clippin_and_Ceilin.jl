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

# # 2023-09-13 · Clippin and Ceilin

include("lib/Nto1.jl")

# +
N = 6500
duration = 10minutes

@time sim = Nto1AdEx.sim(N, duration, ceil_spikes = false);
# -

# (Hm, spikerate not 4.0 Hz (even though we use our lookup table))

sim.spikerate / Hz

# ## Ceil

V_no_ceil = sim.V;
V_ceil = ceil_spikes!(copy(V_no_ceil), sim.spiketimes);  # V_ceil = Vₛ = 
Nto1AdEx.Vₛ / mV

include("lib/plot.jl")

fig, ax = plt.subplots(figsize=(4, 1.4))
plotsig(V_ceil / mV,    [100, 400], ms, label="Ceiled")
plotsig(V_no_ceil / mV, [100, 400], ms, label="No ceiling")
legend(ax, reverse=false);

# ## Clip

# And now for the clipping, we do it data driven (i.e. no spike detection), just a percentile.

include("lib/df.jl")

set_print_precision(4)
ENV["DATAFRAMES_ROWS"] = 12;

ps = [0, 0.1, 1, 5, 10, 50, 90, 95, 99, 99.9, 99.95, 99.99, 100]
qs = percentile(V_ceil, ps)
df = DataFrame("p" => ps, "V (mV)" => qs/mV)
showsimple(df)

df_ = permutedims(df, "p", strict=false)
showsimple(df_, allcols=true)

# Okay, lesgo for 99.

# +
clip!(V, p = 99) = begin
    V_thr = percentile(V, p)
    to_clip = V .≥ V_thr
    V[to_clip] .= V_thr
    V
end

V_ceil_n_clip = clip!(copy(V_ceil));
# -

Vs = [
    (V = V_no_ceil,     label = "No ceiling",       zorder = 2),
    (V = V_ceil,        label = "Ceiled spikes",    zorder = 1),
    (V = V_ceil_n_clip, label = "Ceiled & Clipped", zorder = 3),
];

fig, ax = plt.subplots(figsize=(4, 1.4))
for (V, label, zorder) in Vs
    plotsig(V, [0, 2000], ms; label, zorder, yunit=:mV)
end
hylabel(ax, L"Membrane voltage $V$")
legend(ax);

# ## STAs

exc_input_1 = highest_firing(excitatory_inputs(sim))[1]

fig, ax = plt.subplots()
# set(ax, ylim=[-54.1601, -54.02])  # grr
for (V, label, zorder) in Vs
    STA = calc_STA(V, exc_input_1.times)
    plotSTA(STA; label, nbins_y=4)
end
plt.legend();

# Interesting! They have diff base heights (very convenient for plotting on same ax, here).

# Ok, it makes sense. They're averages: each sample dragged down or up.

# ## ROCs

trains_to_test = get_trains_to_test(sim);

ConnectionTests.set_STA_length(20ms);

function test_conns(V)
    test(train) = test_conn(STAHeight(), V, train.times)
    rows = []
    for (conntype, trains) in trains_to_test
        descr = string(conntype)
        @showprogress descr for train in trains
            t = test(train)
            fr = spikerate(train)
            push!(rows, (; conntype, fr, t))
        end
    end
    DataFrame(rows)
end;

MemDiskCache.set_dir("2023-09-13__Clippin_and_Ceilin")

df_no_ceil     = @cached test_conns(V_no_ceil);      # 55.6 seconds

df_ceil        = @cached test_conns(V_ceil);         # 51.3 seconds

df_ceil_n_clip = @cached test_conns(V_ceil_n_clip);  # 51.8 seconds

dfs = [df_no_ceil, df_ceil, df_ceil_n_clip];
sweeps = sweep_threshold.(dfs)
AUCs = calc_AUROCs.(sweeps);

labels = extract(:label, Vs);

df = DataFrame(AUCs)
insertcols!(df, 1, :V_type=>labels)
showsimple(df)

# Distilling from [mpl docs' Examples: Grouped bar chart with labels](https://matplotlib.org/stable/gallery/lines_bars_and_markers/barchart.html):

# +
function grouped_barplot(df; cols, group_labels, ax=nothing, bar_label_fmt="%.2g", colors=nothing, kw...)
    N_groups = length(group_labels)
    N_bars_per_group = length(cols)
    if isnothing(ax)
        fig, ax = plt.subplots()
    end
    if isnothing(colors)
        colors = mplcolors[1:N_bars_per_group]
    end
    x = 0:(N_groups - 1)
    width = 1/(N_bars_per_group + 1)
    for (i, (colname, color)) in enumerate(zip(cols, colors))
        values = df[!, colname]
        offset = (i-1) * width
        bars = ax.bar(x .+ offset, values, width, label=colname, color=toRGBAtuple(color))
        ax.bar_label(bars, padding = 3, fmt=bar_label_fmt, fontsize="x-small")
    end
    set(ax, xtype=:categorical)
    ax.set_xticks(x .+ width, group_labels)
    return ax
end

fig, ax = plt.subplots(figsize=(5, 3))
ax.axhline(0.5, color="black")
colors = [color_both, color_exc, color_inh]
ax = grouped_barplot(df, cols=["AUC", "AUCₑ", "AUCᵢ"], group_labels=df.V_type; ax, colors);
legend(ax, ncols=3, loc="upper left")
set(ax, ylim=[0.45, 1], xtype=:keep, title="""
    STA connection test performance, for different voltage signal types""");
# -

# ## Threshold-plot

# Visualize what ROC is.

# +
sweep = sweep_threshold(df_ceil_n_clip)

fig, ax = plt.subplots()
plot(sweep.threshold, sweep.TPRₑ, color=color_exc, label="Excitatory inputs")
plot(sweep.threshold, sweep.TPRᵢ, color=color_inh, label="Inhibitory inputs")
plot(sweep.threshold, sweep.TPR, color=color_both, label="(Both exc and inh)")
plot(sweep.threshold, sweep.FPR, color=color_unconn, label="Non-inputs")
# plot(sweep.threshold, F1.(sweep), color=C2, label="F1")
# plot(sweep.threshold, PPV.(sweep), color=C3, label="Precision")
set(ax, ytype=:fraction, hylabel="Spiketrains detected as input", xlabel="Detection threshold")
ax.invert_xaxis()
legend(ax);
# -


