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

# %%time
from brian2 import *

# !mkdir cpp

set_device('cpp_standalone', directory='cpp/1')

# %run lib/neuron.py

μₓ = 4 * Hz
σ = sqrt(0.6)
μ = log(μₓ / Hz) - σ**2 / 2

we = 14 * pS
wi = 4 * we
T = 10*second;


def Nto1_merged(N = 6500, Ne_simmed = 100, print_N=True):
    
    Ni_simmed = Ne_simmed

    Ne = N * 4//5
    Ni = N - Ne
    Ne_merged = Ne - Ne_simmed
    Ni_merged = Ni - Ni_simmed
    N_simmed = Ne_simmed + Ni_simmed
    if print_N:
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
    
    objs = [n, P, Se, Si, PIe, PIi, M, S, SP]
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
# Now with PIe and i included in `net`:  \
# total runtime 52.2 s.  
# main.exe: 1.9 seconds.

# ---
#
# 2023-08-14 (after deleting cpp/):
# - 1.6 wall time for `Nto1_merged()`
# - 61 s wall time for `run`
# - 0.898 s for `time ./main.exe`

61+1.6-0.898

# ---
#
# 2023-08-15 (after deleting cpp/, and w/ CPU in best performance mode (not battery saver)):
# - 0.376 wall time for `Nto1_merged()`
# - 18.4 s wall time for `run`
# - 0.353 s for `time ./main.exe`

0.376+18.4-0.353

# ---
# ---
#
# Ah, we can actually change params w/o rebuilding everything:\
# https://brian2.readthedocs.io/en/stable/examples/multiprocessing.02_using_standalone.html
# > you don’t need to recompile the entire project at each simulation. In the generated code, two consecutive simulations will only differ slightly (in this case only the tau parameter). The compiler will therefore only recompile the file that has changed and not the entire project

# ## w/o PoissonInput merging

# (Restarting nb and re-importing brian)

set_device('cpp_standalone', directory='cpp/2')


def Nto1_all_simmed(N = 6500):
    
    Ne = N * 4//5
    
    n = COBA_AdEx_neuron()
    
    rates = lognormal(μ, σ, N) * Hz
    P = PoissonGroup(N, rates)
    
    Se = Synapses(P, n, on_pre="ge += we")
    Si = Synapses(P, n, on_pre="gi += wi")
    Se.connect("i < Ne")
    Si.connect("i >= Ne")
    
    M = StateMonitor(n, ["V"], record=[0])
    S = SpikeMonitor(n)
    SP = SpikeMonitor(P)
    
    objs = [n, P, Se, Si, M, S, SP]
    return *objs, Network(objs)


# %%time
*objs, net = Nto1_all_simmed()

# %%time
net.run(T, report='text')

# New run: 42.2 s total.
#
# main.exe: 28.9 s (!)

# ---
#
# 2023-08-14 (after deleting cpp/):
# - 0.67 wall time for `Nto1_all_simmed()`
# - 70 s wall time for `run`
# - 21.43 s for `time ./main.exe`

70+0.67-21.43

# ---
#
# 2023-08-15 (after deleting cpp/, and w/ CPU in best performance mode (not battery saver)):
# - 0.123 wall time for `Nto1_all_simmed()`
# - 21.7 s wall time for `run`
# - 6.50 s for `time ./main.exe`

0.123+21.7-6.5

# ## Multiple runs

set_device('cpp_standalone', directory='cpp/3')

from time import time

for j, we in enumerate([8, 14, 20] * pS):
    print(f"Run {j+1} … ", end="")
    t0 = time()
    device.reinit()
    device.activate()
    *objs, net = Nto1_merged(print_N=False)
    net.run(T, report='text')
    print(f"{time() - t0:.1f} s")

# So, no caching speedup.
#
# (Same conclusion when running https://brian2.readthedocs.io/en/stable/examples/multiprocessing.02_using_standalone.html: all all `run_sim` call take 12 à 15 seconds).

# - ok, finally, to reconfirm, https://brian2.readthedocs.io/en/stable/examples/multiprocessing.02_using_standalone.html
# with one proc.
#     - (cause that text literally says: "The compiler will
# therefore only recompile the file that has changed and not the entire project")
#     - ye ok, there's lil speedup:
#     
# ```
# 8.6 s
# 5.6
# 5.2
# ..
# 5.2
# ```


