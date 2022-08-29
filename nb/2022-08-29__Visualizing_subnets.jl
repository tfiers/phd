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

# # 2022-08-29 • Visualizing subnets

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

# Based on Roxin; same as previous nb's.

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
    record_v = [1, 801],
);

# ## Run sim

s = cached(sim, [p.sim]);

s = augment_simdata(s, p);

# ## Connection stats

# conn matrix is [from, to].
#
# So one row is all outputs of one neuron.
#
# Summing over cols i.e. dim two gives num outputs.

num_out = count(s.is_connected, dims=2)
num_in = vec(count(s.is_connected, dims=1));

using PyPlot

using VoltoMapSim.Plot

ydistplot("Num out" => num_out, "Num in" => num_in);

# Sure yes, 40 = 1000 * 0.04.

# Let's export to Graphviz dot, to explore viz options with Gephi.

"digraph {}"

lines = ["digraph {"]
for id in s.neuron_IDs
    outputs = join(s.output_neurons[id], ", ")
    type = s.neuron_type[id]
    push!(lines, "   $(id) [type = $(type), id = $(id)]")
    push!(lines, "   $(id) -> {$(outputs)}")
end
push!(lines, "}")
dot = join(lines, "\n")
lines[[1:5; end-2:end]]

open(joinpath(homedir(), ".phdcache", "graph.dot"), "w") do io
    println(io, dot)
end

# Nice! Graphviz, fun.

# ![](images/gephi.png)


