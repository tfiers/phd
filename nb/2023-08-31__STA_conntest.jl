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

?@showprogress

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

calc_AUROCs(sweep)

fig, ax = plt.subplots()
set(ax, aspect="equal", xlabel="False inputs detected (FPR)", ylabel="Real inputs detected (TPR)",
    xtype=:fraction, ytype=:fraction, title=("STA connection test performance", :pad=>12, :loc=>"right"))
ax.axvline(0.05, color="gray", lw=1)
plot(sweep.FPR, sweep.TPRₑ; ax, label="Excitatory inputs")
plot(sweep.FPR, sweep.TPRᵢ; ax, label="Inhibitory inputs")
plot(sweep.FPR, sweep.TPR; ax, label="Both")
legend(ax);


