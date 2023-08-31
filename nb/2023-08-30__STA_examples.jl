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

# # 2023-08-30__STA_examples

# (Result of workflow speed (& ergonomy) tests: full Julia (no Python hybrid))

# So, for all 10 Ns;\
# For 10 diff seeds;
# for both exc, inh, and unconn;\
# we conntest (maximum) 100 input spike trains.\
# (Each test is comprised of calculating 101 STAs: one real and the rest with shuffled ISIs).

# From the prev nb (https://tfiers.github.io/phd/nb/2023-08-16__STA_conntest_pyjulia.html),
# we found we'd take a shorter window, so that 'area over start' measure (to determine if exc or inh) is correct.

# But ok, it's good to show that in thesis.\
# So, we repeat an example STA plot here.
#
# for full N ofc.

N = 6500;

@time using Revise

using Nto1AdEx
using Units

duration = 10minutes

@time sim = Nto1AdEx.sim(N, duration);

# (1st run: 2.5 secs, 27% compilation time).

@time using ConnectionTests

# We want our input spiketrains sorted: the highest spikers first.\
# And split exc/inh, too.

using DataFrames

ENV["DATAFRAMES_ROWS"] = 10;

# +
exc_inputs = highest_firing(excitatory_inputs(sim))

tabulate(trains) = DataFrame(
    "# input spikes" => num_spikes.(trains),
    "spike rate (Hz)" => spikerate.(trains)
)
tabulate(exc_inputs)

# +
inh_inputs = highest_firing(inhibitory_inputs(sim))

tabulate(inh_inputs)
# -

# ( :) )

STA = calc_STA(sim.V, exc_inputs[1].times);

using WithFeedback

@withfb import PythonCall
@withfb import PythonPlot
@withfb using Sciplotlib
@withfb using PhDPlots

plotSTA(STA);

# To compare with predicted PSP height (0.04 mV):

(maximum(STA) - first(STA)) / mV

plotsig(STA/mV, [0,20], ms);

# +
plotSTA_(train; kw...) = begin
    nspikes = num_spikes(train)
    EI = train ∈ exc_inputs ? "exc" : "inh"
    label = "$nspikes spikes, $EI"
    plotSTA(calc_STA(sim.V, train.times); label, kw...)
end
    
plotSTA_(exc_inputs[1]);
plotSTA_(exc_inputs[2]);
plotSTA_(inh_inputs[1]);
plotSTA_(inh_inputs[2]);
# -

plotSTA_(exc_inputs[1]);
plotSTA_(exc_inputs[end]);
plt.legend();

# +
mid = length(exc_inputs) ÷ 2

plotSTA_(exc_inputs[1]);
plotSTA_(exc_inputs[mid]);
plt.legend();

# +
fig, axs = plt.subplots(nrows=2, ncols=2, figsize=(pw*0.8, mtw))
plotSTA_2(args...; hylabel=nothing, kw...) = plotSTA_(args...; hylabel, kw...)

addlegend(ax; kw...) = legend(ax, fontsize=6, borderaxespad=0.7; kw...)

plotSTA_2(exc_inputs[1], ax=axs[0,0], hylabel="… Using the fastest spiking input, …", xlabel=nothing);
addlegend(axs[0,0])

plotSTA_2(exc_inputs[1], ax=axs[0,1], hylabel="… and other fast spikers.", xlabel=nothing);
plotSTA_2(exc_inputs[100], ax=axs[0,1], xlabel=nothing)
plotSTA_2(inh_inputs[1], ax=axs[0,1], xlabel=nothing)
plotSTA_2(inh_inputs[100], ax=axs[0,1], xlabel=nothing)
addlegend(axs[0,1], loc="lower right")


plotSTA_2(exc_inputs[1], ax=axs[1,1], hylabel="… and slowest spiking input.");
plotSTA_2(exc_inputs[end], ax=axs[1,1]);
addlegend(axs[1,1])

plotSTA_2(exc_inputs[1], ax=axs[1,0], hylabel="… and input with median spikerate.");
plotSTA_2(exc_inputs[mid], ax=axs[1,0]);
addlegend(axs[1,0], loc="upper right")

plt.suptitle(L"Spike-triggered averages (STAs) of membrane voltage $V$ (mV)")

plt.tight_layout(h_pad=2);

savefig_phd("example_STAs")
# -

cs = darken.(Sciplotlib.mplcolors, 0.87)

toRGBAtuple.(cs)[1:6]


