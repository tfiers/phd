
from neuron import *

μₓ = 4 * Hz
σ = sqrt(0.6)
μ = log(μₓ / Hz) - σ**2 / 2

def Nto1(N=6500, vars_to_record=["V"]):

    Ne = N * 4//5
    print(f"{Ne=}")

    n = COBA_AdEx_neuron()

    rates = lognormal(μ, σ, N) * Hz
    P = PoissonGroup(N, rates)

    Se = Synapses(P, n, on_pre="ge += we")
    Si = Synapses(P, n, on_pre="gi += wi")
    Se.connect("i < Ne")
    Si.connect("i >= Ne")

    M = StateMonitor(n, vars_to_record, record=[0])
    S = SpikeMonitor(n)
    SP = SpikeMonitor(P)

    objs = [n, P, Se, Si, M, S, SP]
    return *objs, Network(objs)
