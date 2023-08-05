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

# # 2023-07-10__AdEx_Nto1_Brian_speedtest

# %run lib/neuron.py

# We're gonna try a brian trick to try and speed up the simulation:
# instead of 6500 separate Poisson spike trains, simulate most of them (except a few that we want to use for conntesting) as **one** process. (One for exc and one for inh, to be precise).

μₓ = 4 * Hz
σ = sqrt(0.6)
μ = log(μₓ / Hz) - σ**2 / 2


# ## `PoissonGroup` only

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
*objs, net = Nto1_all_simmed();
net.store()

# +
we = 14 * pS
wi = 4 * we

T = 10*second;
# -

# %%time
net.restore()
net.run(T, report='text')


# So, 19 s for the sim itself,  
# 29 s for the whole thing, i.e. setup took 10 seconds (initial compilation, ig).

# ..that compil gets cached though. Second time: no init time at all.
# (Neither at `run` time or at the objs creation time).

# 2nd try, other day: 51 s for whole sim.  
# (total of block: 53.5 s).

# 3rd try, this same day: 58 s for whole sim.

# (weird, nothin shoulda changed, why 2+ x slower)

# ## `PoissonGroup` + `PoissonInput`s (merged)

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
    
    objs = [n, P, Se, Si, PIe, PIi, M, S, SP]
    return *objs, Network(objs)


# %%time
*objs_m, net_m = Nto1_merged()
net_m.store()

# %%time
net_m.restore()
net_m.run(T, report='text')

# 29 s for 10".
#
# whole block: 64 sec.

# And again, this same other day: 27 s.
#
# So, speedup of that PInput:

(51+58)/2

(51+58) / (27 + 29)

# 2x. worth the extra complexity? eh, sure.

# Otoh, what do when less than 6500 inputs.
# Say, 100 inh, 400 exc.
# Or, 10 inh, 40 exc.
# (ok, sol is simple, you take max)

# ## 

# How 'bout Julia?

# See notebook `2023-08-02__Julia_speedtest_AdEx_Nto1`.\
# Simulating all 6500 inputs for 10 seconds, we have a sim time of 0.7 seconds.  
# (10 minutes takes 9 seconds).  
# I.e. 25x as fast as Brian2 w/ Cython (18 sec).

# What about Brian's standalone mode? i.e. no python for main loop; generate a C++ proj.

# (does that work with changing params in a loop? (i.e. seed, we))

# See `2023-08-02__speedtest_brian_standalone_AdEx_Nto1`.  \
# Also < 1 sec.

# With `time ./main.exe`: ~0.5 seconds.

# Note that that is the one w/ merged inputs.
#
# Without: 8 seconds. Interesting.


