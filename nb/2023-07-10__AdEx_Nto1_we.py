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

# # 2023-07-10__AdEx_Nto1_we

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
    
    objs = [n, P, Se, Si, M, S, SP]
    return *objs, Network(objs)


# %%time
*objs_m, net_m = Nto1_merged()
net_m.store()

# %%time
net_m.restore()
net_m.run(T, report='text')

# Aha, 7 seconds instead of 18 s.
# That's a..

18/7

# ..x speedup. Good.

# (2nd run, more like a 3x speedup).

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



# ---
#
# (Prev state of nb below)



n, P, Se, Si, M, S, SP, net = Nto1()
net.store()

net.restore()
we = 14 * pS
wi = 4 * we
T = 0.1 * second
net.run(T, report='text')

# %run lib/diskcache.py

# +
T = 10 * second

@cache("2023-07-10__AdEx_Nto1_we")
def sim(we, seed):
    net.restore()
    set_seed(seed)
    net.run(T)
    v = ceil_spikes(M, S)
    return dict(
        we   = we,
        seed = seed,
        median_Vm   = median(v),
        output_rate = S.num_spikes / T,
    )


# -

minute = 60*second;

# +
ws = [0, 2.5, 5, 7.5, 10, 11, 12, 12.5, 13, 14, 15, 16, 17.5, 20, 22.5, 25, 27.5, 30] * pS
# ws = [0, 5, 10, 15, 30] * pS
seeds = range(5)
# seeds = [2]

len(ws) * len(seeds) * 14*second / minute

# +
# from tqdm import tqdm
# -

data = []
for we in (ws):
    wi = 4 * we
    for seed in (seeds):
        d = sim(we, seed)
        data.append(d)

import pandas as pd

df = pd.DataFrame(data)
df.head()

# +
from collections import Counter

def units_to_header(df):
    df = df.copy()
    for col in df:
        x = df[col].values[-1]
        if type(x) == Quantity:
            c = Counter(el.get_best_unit() for el in df[col])
            unit = c.most_common()[0][0]
            df[col] = [val / unit for val in df[col]]
            df[col].unit = unit
            df.rename(columns={col: f"{col}_{unit}"}, inplace=True)
        else:
            df[col].unit = None
    return df


# -

df = units_to_header(df)

# !mkdir data
df.to_csv("data/2023-07-10__AdEx_Nto1_we_sim.csv")

# groupby no work w/ brian units
df.groupby("we_pS").mean()


# %run lib/plot.py

# +
def plot_dots_and_means(x, y, ax = None):
    if ax is None:
        fig, ax = plt.subplots()
    xu = unique(x)
    ym = [mean(y[x == xi]) for xi in xu]
    ax.plot(xu, ym, "-", lw=2)
    ax.plot(x, y, "k.", ms=4, mfc='k', mec='none')
    
fig, ax = plt.subplots()
plot_dots_and_means(df.we_pS, df.median_Vm_mV, ax)
hylabel(ax, "Median $V_m$ (mV)")
xl = "$Δg_\\mathrm{exc}$ (pS)"
xlim(-1, 31)
xlabel(xl);
# -

fig, ax = plt.subplots()
axhline(0, 0, 1, c="black", lw=1)
plot_dots_and_means(df.we_pS, df.output_rate_Hz, ax)
hylabel(ax, "Output firing rate (Hz)")
ylim(-1, 16)
xlabel(xl);

fig, axs = plt.subplots(figsize=(2.4, 3.4), nrows=2)
axs[1].axhline(0, 0, 1, c="black", lw=1)
plot_dots_and_means(df.we_pS, df.median_Vm_mV, axs[0])
plot_dots_and_means(df.we_pS, df.output_rate_Hz, axs[1])
axs[1].set_ylim(-1, 15)
axs[1].set_xlim(-1, 31)
axs[0].set_xlim(-1, 31)
axs[0].set_ylim(-66, -50)
hylabel(axs[0], "Median $V_m$ (mV)")
hylabel(axs[1], "Output firing rate (Hz)")
plt.tight_layout(h_pad=2)
axs[1].set_xlabel(xl)
savefig_("input_drive_we")







from julia import Base

Base.sin(8)


