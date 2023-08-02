# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:light
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# # 2023-08-02__speedtest_brian_standalone_AdEx_Nto1

from brian2 import *

set_device('cpp_standalone')

# %run lib/neuron.py

μₓ = 4 * Hz
σ = sqrt(0.6)
μ = log(μₓ / Hz) - σ**2 / 2

we = 14 * pS
wi = 4 * we
T = 10*second;


def Nto1_merged(N = 6500, Ne_simmed = 100):
    
    Ni_simmed = Ne_simmed

    Ne = N * 4//5
    Ni = N - Ne
    Ne_merged = Ne - Ne_simmed
    Ni_merged = Ni - Ni_simmed
    N_simmed = Ne_simmed + Ni_simmed
    print(f"{Ne=}, {Ni=}, {N_simmed=}, {Ne_merged=}, {Ni_merged=}")
    
    n = COBA_AdEx_neuron()

    rates = lognormal(μ, σ, N_simmed) * Hz
    P = PoissonGroup(N_simmed, rates)
    Se = Synapses(P, n, on_pre="ge += we")
    Si = Synapses(P, n, on_pre="gi += wi")
    Se.connect("i < Ne_simmed")
    Si.connect("i >= Ne_simmed")

    PIe = PoissonInput(n, 'ge', Ne_merged, μₓ, we)
    PIi = PoissonInput(n, 'gi', Ni_merged, μₓ, wi);

    M = StateMonitor(n, ["V"], record=[0])
    S = SpikeMonitor(n)
    SP = SpikeMonitor(P)
    
    objs = [n, P, Se, Si, M, S, SP]
    return *objs, Network(objs)


# %%time
*objs_m, net_m = Nto1_merged()

# %%time
net_m.run(T, report='text')

# So, wall time of 23.4 seconds. That's generating all the C++ etc files in ./output/, and then running.

# We can get just the runtime by running the main ig (but that's not useful irl ig, cause can't change params w/o rebuilding (?)).

# +
# # ! output\\main.exe
# -

# (If run here, we get some IO errors).  
# But if run in sep terminal, we get no errors.  
# And.. "10 seconds simulated in < 1s". Impressive!

# ---
#
# Ah, we can actually change params w/o rebuilding everything:\
# https://brian2.readthedocs.io/en/stable/examples/multiprocessing.02_using_standalone.html
# > you don’t need to recompile the entire project at each simulation. In the generated code, two consecutive simulations will only differ slightly (in this case only the tau parameter). The compiler will therefore only recompile the file that has changed and not the entire project


