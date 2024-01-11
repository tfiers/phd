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

# # 2024-01-11 · Re-make network hops barplots

include("lib\\util.jl");

# +
#new_nb("2024-01-11__Re-make_network_hops_barplots")
# -

# Data from https://tfiers.github.io/phd/nb/2022-07-14__Unconnected-but-detected.html#paths

# ---

include("lib\\plot.jl")

hops = [1, 2, 3]
nr_neurons = [39594, 759845, 199561];

fig, ax = plt.subplots(figsize=(0.9mw,0.6mw))
ax.bar(hops, nr_neurons, width=0.6)
set(ax, xlabel = "Shortest path length", ylabel = "Nr of neuron pairs", xminorticks = false, xlim = [0.5, 3.5])
ax.set_xticks(hops);  # `set` sets its own xticks
savefig_phd("shortest-path-all")

nr_neurons = [36, 733, 230];

fig, ax = plt.subplots(figsize=(0.9mw,0.6mw))
ax.bar(hops, nr_neurons, width=0.6)
set(ax, xlabel = "Hops to neuron `1`", ylabel = "Nr of starting neurons", xminorticks = false, xlim = [0.5, 3.5])
ax.set_xticks(hops);  # `set` sets its own xticks
savefig_phd("shortest-path-1")


