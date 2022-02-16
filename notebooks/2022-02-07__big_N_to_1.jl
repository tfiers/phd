# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.6
#   kernelspec:
#     display_name: Julia 1.7.1
#     language: julia
#     name: julia-1.7
# ---

# # 2022-02-07 • Big-N-to-1 simulation

# +
#
# -

include("nb_init.jl")

# +
using Unitful: pA, pF, nS
# @withfeedback using OrdinaryDiffEq
using Parameters, ComponentArrays

@alias CArray = ComponentArray;
# -

save(fname) = savefig(fname, subdir="methods");

# ## Parameters

sim_duration = 10 * seconds
Δt = 0.1 * ms;

# ### Input spikers

N_unconn = 100
N_exc    = 5200
N_inh    = N_exc ÷ 4

N_conn = N_inh + N_exc

N = N_conn + N_unconn

input_spike_rate = LogNormal_with_mean(4Hz, √0.6)  # See the previous notebook

# ### Synapses

# Reversal potential at excitatory and inhibitory synapses,  
# as in the report [`2021-11-11__synaptic_conductance_ratio.pdf`](https://github.com/tfiers/phd-thesis/blob/main/reports/2021-11-11__synaptic_conductance_ratio.pdf):

v_exc =   0 * mV
v_inh = -65 * mV;

# Exponential decay time constant of synaptic conductance `g`, $τ_{s}$ (`s` for "synaptic"):

τs =   7 * ms;

# ### Izhikevich neuron

# Membrane potential `v` and adaptation variable `u` at `t = 0`:

v0    = -80 * mV
u0    =   0 * pA;

# Parameters for a cortical regular spiking neuron:

# +
@with_kw struct IzhikevichParams
    C      = 100 * pF
    k      = 0.7 * (nS/mV)
    b      = -2 * nS
    v_r    = -60 * mV
    v_t    = -40 * mV
    v_peak =  35 * mV
    c      = -50 * mV
    a      = 0.03 / ms
    d      = 100 * pA
end

cortical_RS = IzhikevichParams();
# -

# ## Neuron IDs

neuron_ids = CArray(exc = 1:N_exc, inh = 1:N_inh, unconn = 1:N_unconn)

only(getaxes(neuron_ids))

showsome(labels(neuron_ids))

# i.e. a neuron's **global** ID = its index into the [ComponentVector](https://github.com/jonniedie/ComponentArrays.jl) "`neuron_ids`".

# ## Inputs

λ = rand(input_spike_rate, N)  # sample firing rates, one for every input neuron
β = (1 ./ λ) .|> seconds       # alternative Exp parametrisation: scale (= 1 / rate)
ISI_distributions = Exponential.(β);
#   This uses julia's broadcasting `.` syntax: make an `Expontential` distribution for every value in the β vector

# Create v_syn vector: for each neuron, the reversal potential at its downstream synapses.
vs = CArray(E=fill(v_E, N_E), I=fill(v_I, N_I))

print("""
ComponentVector{typeof(Quantity(::Int64, mV))}(E = Quantity(::Int64, mV)[0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV  …  0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV, 0 mV], I = Quantity(::Int64, mV)[-65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV  …  -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV, -65 mV])
""")

CArray(E=fill(0,N_E), I=fill(-65,N_I))

print("""
ComponentVector{::Quantity(::Int64, mV)}(E = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0], I = [-65, -65, -65, -65, -65, -65, -65, -65, -65, -65  …  -65, -65, -65, -65, -65, -65, -65, -65, -65, -65])
""")

print("""
ComponentVector{Quantity{Int64, mV}}(E = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0  …  0, 0, 0, 0, 0, 0, 0, 0, 0, 0], I = [-65, -65, -65, -65, -65, -65, -65, -65, -65, -65  …  -65, -65, -65, -65, -65, -65, -65, -65, -65, -65])
""")

# This is the expected type interface.
# But they add those ..
# oh no, I can feel it coming. I'm about to make my own unit library innit.
# aargh. fucik. lol.
# ok uhm. no.
# we're gonna go unitless again.
# hahahahahahah



vs[1]

typeof(vs[1])

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
