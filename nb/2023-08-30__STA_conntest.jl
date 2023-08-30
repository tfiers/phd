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

# # 2023-08-30__STA_conntest

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

plot = Sciplotlib.plot;

plotsig(STA / mV, ms);

(maximum(STA) - first(STA)) / mV

plotsig(STA/mV, [0,20], ms);


