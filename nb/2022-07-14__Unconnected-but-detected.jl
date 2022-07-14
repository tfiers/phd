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
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-07-14 • Not directly connected but detected

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

# Based on Roxin (see previous nb).

d = 6
p = get_params(
    duration = 10minutes,
    p_conn = 0.04,
    g_EE = 1   / d,
    g_EI = 18  / d,
    g_IE = 36  / d,
    g_II = 31  / d,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
    to_record = [1, 801],
);
# dumps(p)

# ## Run sim

s = cached(sim, [p.sim]);

s = augment_simdata(s, p);

import PyPlot

using VoltoMapSim.Plot

# ## Conntest

m = 1  # ID of recorded excitatory neuron
v = s.signals[m].v
ii = get_input_info(m, s, p);
ii.num_inputs

length(ii.unconnected_neurons)

# (There was a bug where `m` itself was included in `unconnected_neurons`. See related notebook in Unpolished section. Now fixed).

perf = evaluate_conntest_perf(v, ii.spiketrains, p);

perf.detection_rates

# So we're investigating those 15% false positives, which would be 5% if directly-unconnected spiketrains were not related to the voltage signal.

signif_unconn = ii.unconnected_neurons[findall(perf.p_values.unconn .< p.evaluation.α)]

tested_unconn = ii.unconnected_neurons[1:p.evaluation.N_tested_presyn]
show(tested_unconn)

length(signif_unconn) / length(tested_unconn)

# (The eval_conntest_perf function takes the first N_tested_presyn = 40 of the spiketrains it's given).

# ## STAs

STAs = [calc_STA(v, s.spike_times[n], p) for n in signif_unconn]
ylim = [minimum([minimum(S) for S in STAs]), maximum([maximum(S) for S in STAs])] ./ mV
for n in signif_unconn
    _, ax = plt.subplots(figsize=(2.2, 1.8))
    plotSTA(v, s.spike_times[n], p; ax, ylim)
end

# ## New shuffle seed

# We expect 2/6 (so 2 / 40 tested, i.e. 5%) to change, depending on shuffle.

# So let's try another test.  
# We do need to set the rng seed manually as the test sets it for reproducibility.

p2 = @set p.evaluation.rngseed = 1;

perf2 = evaluate_conntest_perf(v, ii.spiketrains, p2);

perf2.detection_rates

signif_unconn2 = ii.unconnected_neurons[findall(perf2.p_values.unconn .< p.evaluation.α)]

signif_unconn

# So all except `5` are common between both shuffle seeds.

# ## Paths

# Let's start by finding the shortest path of each of those significant-but-not-directly-connected neurons to our target neuron.

# Breadth first search.

function shortest_path(start::Int, target::Int, outputs::Dict{Int, Vector{Int}} = s.output_neurons)
    paths = Deque{Vector{Int}}()
    push!(paths, [start])
    while true
        path = popfirst!(paths)
        if last(path) == target
            return path
        end
        new_paths = [[path..., o] for o in outputs[last(path)] if o ∉ path]
        push!(paths, new_paths...)
    end
end;

for n in signif_unconn
    println(shortest_path(n, m))
end

# So they are all one hop away.

# ## Expected number of hops

# What is the overall distribution of shortest path lengths to this neuron?

# This is a bit slow using the above method.  
# So googling → https://www.wikiwand.com/en/Floyd–Warshall_algorithm, which finds all shortest paths in an adjacency matrix.

function shortest_distances(A)
    pre_post_pairs = Tuple.(findall(A))
    N = size(A)[1]
    inf = N
    dist = fill(inf, (N, N))
    for (m,n) in pre_post_pairs
        dist[m,n] = 1
    end
    for n in 1:N
        dist[n,n] = 0
    end
    for k in 1:N
        for i in 1:N
            for j in 1:N
                dk = dist[i,k] + dist[k,j]  # distance of path through k
                if dist[i,j] > dk
                    dist[i,j] = dk
                end
            end
        end
    end
    return dist
end;

A = s.is_connected
@time D = shortest_distances(A)

# So to answer the question (overall distribution of path lengths to our recorded neuron):

distances = D[:, m];
deleteat!(distances, m);  # Remove distance to self ("0")

cm = countmap(distances)

# 36 neurons are directly connected. This corresponds with:

ii.num_inputs

hops = collect(keys(cm))
nr_neurons = collect(values(cm))
_, ax = plt.subplots()
ax.bar(hops, nr_neurons)
set(ax, xlabel = "Hops to neuron `$m`", ylabel = "Nr of starting neurons", xminorticks = false)
ax.set_xticks(hops);  # `set` sets its own xticks

# So most neurons have only one neuron in between; and the rest only two.
# No neurons have more than that.

# For the whole network (all-to-all):

dist_matrix_as_vector = reshape(D, prod(size(D)));
cm_full = countmap(dist_matrix_as_vector)
delete!(cm_full, 0)

hops = collect(keys(cm_full))
nr_neurons = collect(values(cm_full))
_, ax = plt.subplots()
ax.bar(hops, nr_neurons)
set(ax, xlabel = "Shortest path length", ylabel = "Nr of neuron pairs", xminorticks = false)
ax.set_xticks(hops);  # `set` sets its own xticks

# Same conclusions when looking at all neurons as target as when only looking at neuron `1` as target: most have just one neuron in between, the rest only two, no paths longer than 3 hops / synapses.

# So in other words, our detected-but-not-connected are not special in that they only have one neuron in between.

# Why are they still detected?
#
# -- and mostly consistently so between shuffle rng seeds.

# STAs are mostly downwards. Are the in-between neurons inhibitory?

# ## In between neuron type

paths = shortest_path.(signif_unconn, m)
in_between_neuron = [p[2] for p in paths if length(p) == 3]

[s.neuron_type[n] for n in in_between_neuron]

# So no.

# Ah but we found only one shortest path. There are likely multiple.

# Maybe the detected ones have *more* inhibitory in between, or stronger connections, or higher firing neurons.
# So we could compare these measures between a detected and an undetected unconncted neuron.

# ## All paths

# Let's start with all paths of length 2 (edges; so 3 neurons, including start and target).

function all_paths_of_length(k::Int, start::Int, target::Int, outputs::Dict{Int, Vector{Int}} = s.output_neurons)
    paths = [[start]]
    for i in 1:k
        newpaths = []
        for path in paths
            push!(newpaths, [[path..., o] for o in outputs[last(path)]]...)
        end
        paths = newpaths
    end
    return [p for p in paths if last(p) == target]
end;

insignif_unconn = [n for n in tested_unconn if n ∉ signif_unconn]
show(insignif_unconn)

signif_unconn

all_paths_of_length(2, signif_unconn[1], m)

all_paths_of_length(2, insignif_unconn[1], m)

# Now do this for all tested neurons, and get the type of the in-between neurons.

# ## Compare between detected (false positive) and not detected (true negative)

# Start simple: number of paths of length 2, for each.

macro plothists(expr, title = "", bins = 10)
    return quote
        vals_sig = [$expr for n in signif_unconn]
        vals_insig = [$expr for n in insignif_unconn]
        plt.hist([vals_sig, vals_insig], $bins, align="left",
                 label = ["Detected as connected", "Not detected as connected"])
        plt.legend()
        plt.xlabel($title, loc="center")
        plt.ylabel("Number of tested,\n unconnected neurons")
    end
end;

@plothists length(all_paths_of_length(2, n, m)) "Number of length-2 paths to target neuron `$m`" 0:7;

# No big diff it seems. The detected maybe have more paths.

# Next, nr of inhibitory in between.

# +
type_of_in_between_neuron(path) = s.neuron_type[path[2]]

num_inh_in_between(start_n) =
    count([type_of_in_between_neuron(p) for p in all_paths_of_length(2, start_n, m)] .== :inh);
# -

@plothists(num_inh_in_between(n), "Number of length-2 paths where \nneuron in between is inhibitory", 0:3)
plt.xticks(0:2);

# ~~So no, not more inhibitory in between; on the contrary, there's other neurons with more inhibitory in between, that didn't get detected.~~  
# When I actually plotted it, I did see diff :)
#
# The detected-as-connected neurons have more inhibitory neurons as in-between to our target neuron.

# Next, firing rates.

# +
firing_rate_of_in_between_neuron(path) = s.spike_rates[path[2]]

mean_or_zero(x) = isempty(x) ? 0 : mean(x)
mean_fr_in_between(n) =
    mean_or_zero([firing_rate_of_in_between_neuron(p) for p in all_paths_of_length(2, n, m)]);
# -

@plothists mean_fr_in_between(n) "Mean firing rate of in-between neuron (Hz)";

# Again, seems like a bit higher firing rate.

# It might make more sense to look at the sum of firing rates, as the number of paths is not equal between 'pre'-neurons:

@plothists total_firing_rate_in_between(n) "Sum of firing rates of in-between neurons (Hz)";

# The distribution still seems higher.

# What about those non detected ones at the far right? What does their STA look like? Why are they _not_ detected?
# See the section after the next one.

# ## STAs of non-detected

# We repeat the STAs of the detected unconnected here..

STAs = [calc_STA(v, s.spike_times[n], p) for n in signif_unconn]
ylim = [minimum([minimum(S) for S in STAs]), maximum([maximum(S) for S in STAs])] ./ mV
for n in signif_unconn
    _, ax = plt.subplots(figsize=(2.2, 1.8))
    plotSTA(v, s.spike_times[n], p; ax, ylim)
end

# ..to then compare them with some STAs of the non-detected unconnected:

for n in insignif_unconn[1:6]
    _, ax = plt.subplots(figsize=(2.2, 1.8))
    plotSTA(v, s.spike_times[n], p; ax, ylim)
end

# Strangely, these STAs do not seem much smaller than the detected ones..

# The first one is very high. What was it's p-value?

perf.p_values.unconn[1]

# Check (we repeat this as it the shuffle is different each time):

mean([test_connection(v, s.spike_times[ii.unconnected_neurons[1]], p) for i in 1:10])

# (Probably same, check ok)

# Quite interesting.  
# Here the usefulness of the shuffle test (instead of looking at the absolute STA height values) comes up.

# Maybe it is so high because the neuron has only few spikes (and thus a noisy STA).

s.spike_rates[ii.unconnected_neurons[1]]

# Indeed, quite low :)

# ## Non detected but the in-betweens fire lots

i = argmax([total_firing_rate_in_between(n) for n in insignif_unconn])
n = insignif_unconn[i]

all_paths_of_length(2, n, m)

num_inh_in_between(n)

plotSTA(v, s.spike_times[n], p);

# This STA is indeed quite random and small.

s.spike_rates[n]

# Ah, what about this for the significant ones?

@plothists(s.spike_rates[n], "Firing rate (Hz)");

# No clear diff.

# ## Summary

# - The network is highly connected: every neuron is maximum three hops (edges, synapses) away from any other. Most only two hops.
#
# - Excess false positives (above the expected α = 5%) seem stable between shuffle seeds and are thus not flukes.
#
# - Their STAs often look like inhibitory STAs / PSPs.
#
# - These detected but not-directly-connected 'pre' neurons seem to have
#     - More paths to the voltage-recorded neuron
#     - More inhibitory neurons on these paths
#     - Higher firing neurons on these paths
#     
#   They do not have a higher firing rate.
#
# - Low firing unconnected neurons have high STAs (as not enough spikes to average out the noise); but these get correctly not detected thanks to the shuffle test.
