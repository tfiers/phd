# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Julia 1.9.0-beta3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-08-31__STA_conntest

# So, hi.
# copying from prev nb:
#
# So, for all 10 Ns;\
# For 10 diff seeds;
# for both exc, inh, and unconn;\
# we conntest (maximum) 100 input spike trains.\
# (Each test is comprised of calculating 101 STAs: one real and the rest with shuffled ISIs).

include("lib/Nto1.jl")

# +
duration = 10minutes
N = 6500

@time sim = Nto1AdEx.sim(N, duration);
# -

# (So even with native code caching in Julia 1.9, we still have 30% of time compilation here).

# We decided we'd pick the 100 highest firing (exc and inh).\
# And then generate some unconnecteds too..\
# What's their firing rate? Maybe sample from the real ones :) hehe, sure.

# ## Gen unconnected trains

set_print_precision(3)

exc_inputs = highest_firing(excitatory_inputs(sim))[1:100]
inh_inputs = highest_firing(inhibitory_inputs(sim))[1:100]
both = [exc_inputs..., inh_inputs...]
fr = spikerate.(both)
showsome(fr / Hz)

Random.seed!(1)
unconn_frs = sample(fr, 100)
showsome(unconn_frs)

# Seed may not be same as seed in sim: otherwise our 'unconnected' trains generated might be same as real ones used in (generated in) sim.

Random.seed!(9)
unconn_trains = [poisson_SpikeTrain(r, duration) for r in unconn_frs];

# ## Conntest

ConnectionTests.set_STA_length(200);

# +
test(train) = test_conn(STAHeight(), sim.V, train.times)

@time test(exc_inputs[1])
# -

# (That value is the 'connectedness measure' I defined. Here simply 1 – p-value)

# Plottin some unconnected STAs.

include("lib\\plot.jl")

_plotSTA(train, winlength = 1000; kw...) = plotSTA(calc_STA(sim.V, train.times, Nto1AdEx.Δt, winlength); kw...);
fig, axs = plt.subplots(ncols=2, figsize=(pw, 0.3pw), sharey=true)
_plotSTA(exc_inputs[1], ax=axs[0])
_plotSTA(unconn_trains[1], ax=axs[0], c="gray")
_plotSTA(unconn_trains[2], ax=axs[1], c="gray")
_plotSTA(unconn_trains[3], ax=axs[1], c="black");

@time test.(unconn_trains[[1,2,3]])

include("lib/df.jl")

using ProgressMeter

# +
rows = []

@time for (conntype, trains) in [
        (:exc, exc_inputs),
        (:inh, inh_inputs),
        (:unc, unconn_trains)
    ]
    descr = string(conntype)
    @showprogress descr for train in trains
        t = test(train)
        fr = spikerate(train)
        push!(rows, (; conntype, fr, t))
    end
end;
# -

showsome(rows)

df = DataFrame(rows)
rename!(df, :fr => "Spikerate (Hz)")

# ## Eval

sweep = ConnTestEval.sweep_threshold(df);

showsome(sweep.threshold)

23/100

predtable = at_FPR(sweep, 5/100)
print_confusion_matrix(predtable)

AUCs = calc_AUROCs(sweep)
AUCs = (; (k=>round(AUCs[k], digits=2) for k in keys(AUCs))...)

fig, ax = plt.subplots()
# ax.axvline(0.05, color="gray", lw=1)
plot(sweep.FPR, sweep.TPRₑ; ax, label="Excitatory   $(AUCs.AUCₑ)")
plot(sweep.FPR, sweep.TPRᵢ; ax, label="Inhibitory   $(AUCs.AUCᵢ)")
plot(sweep.FPR, sweep.TPR; ax,  label="Both         $(AUCs.AUC)")
set(ax, aspect="equal", xlabel="Non-inputs wrongly detected (FPR)", ylabel="Real inputs detected (TPR)",
    xtype=:fraction, ytype=:fraction, title=("STA connection test performance", :pad=>12, :loc=>"right"))
font = Dict("family"=>"monospace", "size"=>6)
legend(ax, borderaxespad=1,     title="Input type   AUC ", loc="lower right",
        alignment="right", markerfirst=true, prop=font);
# Using the same `font` dict for `title_fontproperties` does not apply the size (bug ig)
# (bug in this PR? https://github.com/matplotlib/matplotlib/pull/19304)
# Hm, it works in straight Python[*]. Interesting.
ax.legend_.get_title().set(family="monospace", size=6, weight="bold");

# [*]: http://localhost:8888/notebooks/2023-09-05__mpl_legend_title_props_bugreport.ipynb

# `[*]`: http://localhost:8888/notebooks/2023-09-05__mpl_legend_title_props_bugreport.ipynb

neighbours_of_5pct_line = sweep[5:6]
neighbours_of_5pct_line.threshold

neighbours_of_5pct_line.FPR

# Sudden jump in TPRs right around 5%.\
# Coincidence I think, cause there is no threshold programmed in STAHeight ConnectionTest.
#
# Actually no, jump is after 5% / at 6%:

x = sweep[5:11]
DataFrame(; x.threshold, x.FPR, x.TPR)

# So we increase the threshold from 0.94 to 0.90, and find more TPs, without incurring any additional FPs.


