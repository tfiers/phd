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

# # 2023-07-26__AdEx_Nto1_we_I_syn

# %run lib/Nto1.py

n, P, Se, Si, M, S, SP, net = Nto1(N=6500, vars_to_record=["V", "I", "ge", "gi", "w"])
net.store()

net.restore()
set_seed(1234)
we = 14 * pS
wi = we * 4
T = 1 * second
net.run(T, report='text')

# %run lib/plot.py

kw = dict(tlim = [250, 500]*ms, t_unit=ms)
fig, axs = plt.subplots(figsize=(4, 5.5), nrows=5, sharex=True)
add_hline(axs[1])
add_hline(axs[-1])
plotsig(M.ge[0], "$g_e$ & $g_i$", **kw, ylim=[0, 2.8], ax=axs[0], color="C2", label="$g_e$")
plotsig(M.gi[0], None, **kw, ylim=[0, 2.8], ax=axs[0], color="C1", label="$g_i$")
axs[0].legend(loc="lower right", ncols=2)
plotsig(M.ge[0] - M.gi[0], "$g_e - g_i$", **kw, ax=axs[1], y_unit=nS)
plotsig(-M.I[0], "$-I_\mathrm{syn}$", ylim=[25, 85], **kw, ax=axs[2])
plotsig(M.V[0], "$V$", **kw, ylim=[-60, -45], ax=axs[3])
plotsig(M.w[0], "$w$", **kw, ylim=[-20, 60], ax=axs[4])
for ax in axs[0:-1]:
    ax.set_xlabel(None)
plt.tight_layout(h_pad=0.4)
savefig_thesis("all_sigs")



# %run lib/diskcache.py

# +
T = 10 * second

@cache("2023-07-10__AdEx_STA_Nto1")
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
df.to_csv("data/2023-07-10__AdEx_STA_Nto1_sim.csv")

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


