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
#     display_name: Julia 1.8.1
#     language: julia
#     name: julia-1.8
# ---

# # 2022-10-11 • N-to-1 output rate (edit of '2022-05-02')

# I found an 'error' in the N-to-1 code (used in [2022-05-02 • STA mean vs peak-to-peak](https://tfiers.github.io/phd/nb/2022-05-02__STA_mean_vs_peak-to-peak.html) amongst others):
# the 'input per spike' (Δg) is not scaled with the total number of inputs.
#
# I.e, the more inputs, the stronger the one simulated neuron will spike.\
# The worry is that in the high-N cases, the output will be constantly firing, making connection detection via STA's difficult (and that would be the reason for the observed poor performance in those cases).
#
# So I went back in time (downloading [old zips](https://github.com/tfiers/phd/tree/da6bc5bc1) of repo and its submodules) and re-ran this notebook, to check/confirm this issue.
#
# Conclusion:
#
# The error was indeed there.
#
# But the fear that the highest was drowning in spikes was not true. This is because the input in all the other cases (except N = 6400) was so low that the output did not spike at all.
#
# The breakdown really is cause too much inputs, so the STAs become very noisy (SNR: 'signal' stays same (no downscaling of input with many N here (the 'error') -- but noise goes up).

# ## Setup

# +
#
# -

# I `instantiate`d old Manifest. Worked great.

] st

pwd()

# i.e. we at https://hyp.is/8k1PvkjtEe2q8bOPbkntDA/tfiers.github.io/phd/nb/2022-05-02__STA_mean_vs_peak-to-peak.html

# +
# using Revise
# -

using MyToolbox

using VoltageToMap

using PyPlot
using VoltageToMap.Plot

# ## Params

N_excs = [
    4,   # => N_inh = 1
    17,  # Same as in `previous_N_30_input`.
    80,
    320,
    1280,
    5200,  
];

rngseeds = [0]; #, 1, 2, 3, 4];

get_params((N_exc, rngseed, STA_test_statistic)) = ExperimentParams(
    sim = SimParams(
        duration = 10 * minutes,
        imaging = get_VI_params_for(cortical_RS, spike_SNR = Inf),
        input = PoissonInputParams(; N_exc);
        rngseed,
    ),
    conntest = ConnTestParams(; STA_test_statistic, rngseed);
    evaluation = EvaluationParams(; rngseed)
);

variableparams = collect(product(N_excs, rngseeds, ["ptp"])) #, "mean"]))

paramsets = get_params.(variableparams);
print(summary(paramsets))

dumps(paramsets[1])

# ## Run

# +
# @edit cached(sim_and_eval, [paramsets[1]])
# -

perfs = similar(paramsets, NamedTuple)
for i in eachindex(paramsets)
    (N_exc, seed, STA_test_statistic) = variableparams[i]
    paramset = paramsets[i]
    println((; N_exc, seed, STA_test_statistic), " ", cachefilename(paramset))
    perf = cached(sim_and_eval, [paramset])
    println()
    perfs[i] = perf
end

perfs

# ## (Addon)

using Printf
Base.show(io::IO, x::Float64) = @printf io "%.3g" x
1/3

# ## Check if output rate increases

# Hah there was not even output spike recording. Oops.
#
# I'll detect manually.

function f(p)
    s = cached(sim, [p.sim]);
    ot = s.v .> p.sim.izh_neuron.v_thr   # over thr
    spike_ix = findall(diff(ot) .== +1)  # pos thr crossings
    spiketimes = spike_ix * p.sim.Δt
    num_spikes = length(spiketimes)
    spike_rate = num_spikes / p.sim.duration * Hz
    time_between = 1/spike_rate * seconds
    return (; N_conn = p.sim.input.N_conn, num_spikes, spike_rate, time_between)
end
for p in paramsets
    println(f(p))
end

# Ok.
# So the fear that the highest was drowning in spikes was not true.
# The breakdown really is cause too much inputs, so signal is less clear.

# ## Plot

# (Just figure copied from older nb)

# ### Peak-to-peak

fig, ax = make_figure(perfs[:,:,1]);
