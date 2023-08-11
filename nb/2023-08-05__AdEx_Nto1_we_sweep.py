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

# # 2023-08-05__AdEx_Nto1_we_sweep

# (We've made Nto1AdEx.jl now).
#
# Let's do an unholy python julia brian hybrid.
#
# (plotting (and nb restarting) in julia still too slow startup).  
# But sim is almost 1000x faster than brian.

# %%time
from brian2.units import *

# %%time
# %run lib/plot.py

# https://github.com/JuliaPy/pyjulia

# %%time
from julia import Pkg

# %%time
Pkg.activate("..")
# Pkg.status()
# output is in nb terminal

# %%time
from julia import Nto1AdEx

# %%time
out = Nto1AdEx.sim(6500, 10);

# (First run: 1.3 seconds)

V = (out.V * volt)

# %run lib/util.py

V = ceil_spikes_jl(out)

plotsig(V, tlim=[0,1000]*ms);

# %run lib/diskcache.py

# +
N = 6500
T = 10 * second

@cache("2023-08-05__AdEx_Nto1_we_sweep")
def sim(wₑ, seed):
    out = Nto1AdEx.sim(N, T / second, seed, wₑ / siemens);
    v = ceil_spikes_jl(out)
    return dict(
        wₑ   = wₑ,
        seed = seed,
        median_Vm   = median(v),
        output_rate = out.spikerate * Hz,
    )


# -

wₑs = [0, 2.5, 5, 7.5, 10, 11, 12, 12.5, 13, 14, 15, 16, 17.5, 20, 22.5, 25, 27.5, 30] * pS
# wₑs = [0, 5, 10, 15, 30] * pS
seeds = range(10);
# seeds = [2]

# +
# from tqdm import tqdm
# -

data = []
for wₑ in (wₑs):
    for seed in (seeds):
        d = sim(wₑ, seed)
        data.append(d)

df = pd.DataFrame(data)
df.head()

df = units_to_header(df)

# +
# (`!mkdir -p data` not working in IJulia)
# -

# !mkdir data
df.to_csv("data/2023-08-05__AdEx_Nto1_we_sweep.csv")

# groupby no work w/ brian units
df.groupby("we_pS").mean()


# %run lib/plot.py

# %run lib/util.py

# +
def plot_dots_and_means(x, y, ax = None, **kw):
    xu = unique(x)
    ym = [mean(y[x == xi]) for xi in xu]
    plot(xu, ym, "-", lw=2, ax=ax, **kw, clip_on=False)
    plot(x, y, "k.", ms=4, mfc='k', mec='none', ax=ax, **kw, clip_on=False)
    
fig, ax = plt.subplots(figsize=(0.9*mw, 0.6*mw))
xlim = [0, 30]
plot_dots_and_means(df.we_pS, df.median_Vm_mV, ax, xlim=xlim, ylim=[-65.2, -50])
hylabel(ax, "Median $V_m$ (mV)")
xl = "$Δg_\\mathrm{exc}$ (pS)"
plt.xlabel(xl);
# -

fig, ax = plt.subplots(figsize=(0.9*mw, 0.6*mw))
plt.axhline(0, 0, 1, c="black", lw=1)
plot_dots_and_means(df.we_pS, df.output_rate_Hz, ax, ylim=[-0.2, 15], xlim=xlim)
hylabel(ax, "Output firing rate (Hz)")
plt.xlabel(xl);

# %run lib/plot.py

fig, axs = plt.subplots(figsize=(0.9*mw, 1.3*mw), nrows=2)
axs[1].axhline(0, 0, 1, c="black", lw=1)
plot_dots_and_means(df.we_pS, df.median_Vm_mV, axs[0], xlim=xlim, ylim=[-65, -50], nbins_x=4)
plot_dots_and_means(df.we_pS, df.output_rate_Hz, axs[1], xlim=xlim, ylim=[-0, 15], nbins_x=4)
hylabel(axs[0], "Median $V_m$ (mV)")
hylabel(axs[1], "Output firing rate (Hz)")
rm_ticks_and_spine(axs[0])
plt.tight_layout(h_pad=1.4)
axs[1].set_xlabel(xl);
savefig_thesis("input_drive_we")


