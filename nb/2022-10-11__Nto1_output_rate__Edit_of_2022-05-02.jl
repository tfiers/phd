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

# https://github.com/tfiers/phd/tree/da6bc5/pkg/VoltageToMap/src

] activate "../../phd-althist/da6bc5"

# I `instantiate`d old Manifest. Worked great.

] st

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

# Note: the caching doesn't work here between sessions: I still used wrong implementation with naive `hash`.

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
Base.show(io::IO, x::Float64) = @printf io "%.4g" x
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

# (Just the figure output, copied from older nb)

# ### Peak-to-peak

fig, ax = make_figure(perfs[:,:,1]);

# ## Inputs' Firing rates distribution

# I want to check something else suspicious.
#
# In this nb (a bit earlier), input firing rates are sampled from a LogNormal distr.
# But looking at this plot here: https://tfiers.github.io/phd/nb/2022-03-28__total_stimulation.html#total-stimulation
# -- where "total stimulation" is directly proportional to num spikes (every inh neuron has same Δg) -- the fr distributions look very un-lognormal to me..

p = paramsets[end]
p.sim.input.N_conn

p.sim.input.spike_rates

# (Real mean of that is 4Hz).

s = cached(sim, [p.sim]);

mean_ISI = [d.θ for d in s.state.fixed_at_init.ISI_distributions]  # scale = β = θ = mean
plt.hist(mean_ISI / seconds, bins=20);

mean_spikes_per_sec = 1 ./ mean_ISI  # λ = rate
plt.hist(mean_spikes_per_sec / Hz, bins=20);

# Ok that's not Normal, good

num_spikes = length.(s.input_spikes)
plt.hist(num_spikes);

# .. and that is.

# I must have made a reasoning error somewhere.
# Or a programming error (all sampled from same distr or sth).

@unpack ISI_distributions, = s.state.fixed_at_init;

findmax(mean_spikes_per_sec)

findmin(mean_spikes_per_sec)

some_ISIs = rand(ISI_distributions[1862], 3) / ms  |> show

some_ISIs = rand(ISI_distributions[2613], 3) / ms  |> show

# Ok, that's all good.
#
# So why do these input spikes look normal.
#
# Let's simulate ourselves, again.

spikes = Dict()
for (n, ISI_distr) in enumerate(ISI_distributions[1:1000])
    t = 0.0
    spikes[n] = Float64[]
    while true
        t += rand(ISI_distr)
        if t ≥ p.sim.duration
            break
        end
        push!(spikes[n], t)
    end
end

num_spikes = length.(values(spikes))
plt.hist(num_spikes);

# Akkerdjie. Dit is wel lognormal.
#
# What's diff with sim code.

# +
function simstep(spikerec, upcoming_input_spikes, ISI_distributions, t)
    t_next_input_spike = peek(upcoming_input_spikes).second  # (.first is neuron ID).
    if t ≥ t_next_input_spike
        n = dequeue!(upcoming_input_spikes)  # ID of the fired input neuron
        push!(spikerec[n], t)
        tn = t + rand(ISI_distributions[n])  # Next spike time for the fired neuron
        enqueue!(upcoming_input_spikes, n => tn)
    end
end

input_neuron_IDs = CVec(collect(1:length(ISI_distributions)), getaxes(ISI_distributions))

@unpack upcoming_input_spikes = s.state.variable_in_time;

first_input_spike_times = rand.(ISI_distributions)
spikerec = Dict{Int, Vector{Float64}}()

empty!(upcoming_input_spikes)
for (n, t) in zip(input_neuron_IDs, first_input_spike_times)
    enqueue!(upcoming_input_spikes, n => t)
    spikerec[n] = []
end

# duration = p.sim.duration
duration = 1minutes
@showprogress for t in linspace(0, duration, round(Int, duration / p.sim.Δt))
    simstep(spikerec, upcoming_input_spikes, ISI_distributions, t)
end
# -

num_spikes = length.(values(spikes))
spikerates = num_spikes ./ duration
plt.hist(spikerates);

# (Note that here we sim for all inputs but not all time; in previous plot we sim'ed for all time but not all inputs).

# Ma huh?
# This is almost exactly the code in `step_sim!`

@less VoltageToMap.step_sim!(s, p.sim, [], 1)

# (https://github.com/tfiers/phd/blob/da6bc5b/pkg/VoltageToMap/src/sim/step.jl)

mean_ISIs_sim = mean.(VoltageToMap.to_ISIs.(s.input_spikes))
plt.hist(mean_ISIs_sim / seconds, bins=20);

# Wait what. The mean ISI distr does look lognormal i.e. correct.
#
# Then why doesn't the rate distr?

plt.hist(length.(s.input_spikes) / p.sim.duration / Hz, bins=20);

# Let's investigate two concrete neurons.

findmin(mean_ISIs_sim), findmax(mean_ISIs_sim)

length(s.input_spikes[1862]), length(s.input_spikes[5513])

# Wut. (This is a great, expected spread).

1742/10minutes, 81/10minutes

# Ok so the normal diagram has correct values.

# How does a normal simulated fr distr arise from lognormal mean ISIs.



#

# ## Prez

# $$
# v(t) = 
# \begin{cases}
# e^{-t/τ}                                                          & τ_1 = τ_2 \\
# \frac{τ_1 τ_2}{τ_1 - τ_2} \left(e^{-t/τ_1} - e^{-t/τ_2} \right)   & τ_1 ≠ τ_2
# \end{cases}
# $$
# <!-- for codecogs, only ascii:
#   
# v(t) = 
# \begin{cases}
# e^{-t/\tau}                                                          & \tau_1 = \tau_2 \\
# \frac{\tau_1 \tau_2}{\tau_1 - \tau_2} \left(e^{-t/\tau_1} - e^{-t/\tau_2} \right)   & \tau_1 \neq \tau_2
# \end{cases}
#
# -->


