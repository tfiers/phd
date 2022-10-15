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
#     display_name: Julia 1.8.1 mysys
#     language: julia
#     name: julia-1.8-mysys
# ---

# # 2022-10-04 • Use faster curve fit for connection inference

# As we saw in the previous notebook, we can get away with way fewer Levenberg-Marquardt steps (see [here](https://tfiers.github.io/phd/nb/2022-09-13__Fit_simpler_function.html#fit) for more on that algo) to get a decent fit: the difference in fit quality between 10 and the default ~350 iterations is not that big.

# ## Imports

# +
#
# -

using MyToolbox

@time_imports using VoltoMapSim

# The faster modelling code has been consolidated in the codebase (`src/infer/model_STA.jl`).

# ## Params

p = get_params(
    duration = 10minutes,
    p_conn = 0.04,
    g_EE = 1, g_EI = 1, g_IE = 4, g_II = 4,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
    record_v = [1:40; 801:810],
);

# ## Load STA's

# ### Load all STA's

# Skip this section if you want just one.

out = cached_STAs(p);

(ct, STAs, shuffled_STAs) = out;

α = 0.05 
conns = ct.pre .=> ct.post
example_conn(typ) = conns[findfirst(ct.conntype .== typ)]
conn = example_conn(:exc)  # 139 => 1

STA = copy(STAs[conn]);

# + [markdown] heading_collapsed=true
# ### Load 1 STA

# + hidden=true
path = cachepath("2022-10-04__inspect_curve_fit", "STA");

# + hidden=true
# savecache(path, STA);

# + hidden=true
# using SnoopCompile
# tinf = @snoopi_deep loadcache(path);

# + hidden=true
@time STA = loadcache(path);
# -

# ## Test one

fit, model = STA_modelling_funcs(p);

@time fit(STA, maxIter=10);  # compile

fitfunc = fit $ (; maxIter = 10)
testfunc = modelfit_test $ (; modelling_funcs = (fitfunc, model))
test_conn(testfunc, STAs[conn], shuffled_STAs[conn])

@time test_conn(testfunc, STAs[conn], shuffled_STAs[conn]);

# This used to be 5.8 seconds (or even 50 seconds).

# ## Test sample

samplesize = 100
resetrng!(1234)
i = sample(1:nrow(ct), samplesize, replace = false)
ctsample = ct[i, :];

summarize_conns_to_test(ctsample)

tc = test_conns(testfunc, ctsample, STAs, shuffled_STAs, α = 0.05);

perftable(tc)

tc[(tc.conntype .== :exc), :] 

plotsig(STAs[20=>28] / mV, p);
plotsig(STAs[451=>6] / mV, p);
plotsig(STAs[770=>18] / mV, p);
plotsig(STAs[33=>806] / mV, p);

# oh ow, is this the nonlinearity of Izhikevich at play? (Weaker excitation at lower voltages). Hm or is that sth else ([nb](https://tfiers.github.io/phd/nb/2021-12-08__biology_vs_Izh_subhtr.html)).
