# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.10.0
#   kernelspec:
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-01-08 • Big-N-to-1 simulation

# +
#
# -

include("nb_init.jl")

print(warnings)

# @withfeedback using OrdinaryDiffEq
@withfeedback using Parameters, ComponentArrays
@alias CArray = ComponentArray;

save(fname) = savefig(fname, subdir="methods");

?redirect_stdout

# ## Parameters

N_unconn = 100
N_E    = 5200
N_I    = N_E ÷ 4

N_conn = N_I + N_E

N = N_conn + N_unconn

neuron_ids = CArray(E = 1:N_E, I = 1:N_I, unconn = 1:N_unconn)

only(getaxes(neuron_ids))  

showex(labels(neuron_ids))

# i.e. global id = index into `CArray`.

# +
using Unitful: nS, pF, pA

sim_duration = 10 * seconds
Δt    = 0.1 * ms
v0    = -80 * mV  # Membrane potential at t = 0
u0    =   0 * pA  # Adaptation variable at t = 0
τ_syn =   7 * ms
v_I   = -65 * mV  # Reversal potential at inhibitory synapses
v_E   =   0 * mV  # Reversal potential at excitatory synapses
                  # v_I and v_E as in `2021-11-11__synaptic_conductance_ratio.pdf`

@with_kw struct IzhikevichParams
    C = 100 * pF
    k = 0.7 * (nS/mV)
    b = -2 * nS
    v_r    = -60 * mV
    v_t    = -40 * mV
    v_peak =  35 * mV
    c      = -50 * mV
    a = 0.03 / ms
    d = 100 * pA
end

cortical_RS = IzhikevichParams();
# -

# See the previous notebook
input_spike_rate = LogNormal_with_mean(4Hz, √0.6)

# ## Inputs

λ = rand(input_spike_rate, N_)  # rates
β = (1 ./ λ) .|> seconds  # alternative Exp parametrisation: scale (= 1 / rate)
ISI_distributions = Exponential.(β);
#   julia's broadcasting dot syntax: make an Exp distribution for every value in the β vector

# Create v_syn vector: for each neuron, the reversal potential at its downstream synapses.
vs = CArray(I=fill(v_I, N_I), E=fill(v_E, N_E))

# ## Sim

# Proof of concept of spike generation using a priority queue.

# +
using DataStructures
using Unitful: Time

first_spiketimes = rand.(ISI_distributions)

pq = PriorityQueue{Int, Time}()
for (input_neuron, t) in enumerate(first_spiketimes)
    enqueue!(pq, input_neuron => t)
end

t = 0s
while t < sim_duration
    input_neuron, t = dequeue_pair!(pq)  # earliest spike
    new_ISI = rand(ISI_distributions[input_neuron])
    enqueue!(pq, input_neuron => t + new_ISI)
end
# -

Base.show(io, U::Type{<:Unitful.Units}) = print(io, "jfjf")#"typeof($(U()))")

typeof(Hz)

# Superfast.



# +
function f(D, vars, params, t)
    @unpack C, k, b, v_r, v_t, v_peak, c, a, d = params
    @unpack v, u = vars
    D.v = (k * (v - v_r) * (v - v_t) - u) / C
    D.u = a * (b * (v - v_r) - u)
    D.g = -g / τ_syn
    return nothing
end

x0 = ComponentArray{Quantity{Float64}}(v = v0, u = u0)  # note eltype cast to float
prob = ODEProblem(f, x0, float(sim_duration), cortical_RS)
# integrator = init(prob, Tsit5(); Δt, adaptive=true)
# -

t = 0ms:0.1ms:sim_duration
v = t -> sol(t).v / mV |> NoUnits
plot(t, v.(t));

x0

ca = ComponentArray{Quantity{Float64}}(v=v0, u=u0)

x0

function Base.float(ca::ComponentArray)
    for
