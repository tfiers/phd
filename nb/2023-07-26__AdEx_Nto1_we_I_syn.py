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

set_seed(1)
*objs, net = Nto1(N=6500, vars_to_record=["V", "I", "ge", "gi", "w"])
net.store()

net.restore()
we = 15 * pS
wi = we * 4
T = 1 * second
net.run(T, report='text')

n, P, Se, Si, M, S, SP = objs;

kw = dict(tlim = [550, 750]*ms, t_unit=ms, nbins_y=3, yaxloc="right")
fig, axs = plt.subplots(figsize=(4, 5.5), nrows=5, sharex=True, height_ratios=[1,1,1,1,1])
add_hline(axs[1])
add_hline(axs[-1])
plotsig(M.ge[0], "$g_e$ & $g_i$", **kw, ylim=[0, 3], ax=axs[0], color="C2", label="$g_e$")
plotsig(M.gi[0], None, **kw, ax=axs[0], color="C1", label="$g_i$")
axs[0].legend(loc="lower left", ncols=2, fontsize="x-small")
plotsig(M.ge[0] - M.gi[0], "$g_e - g_i$", **kw, ylim=[-.85,.85], ax=axs[1], y_unit=nS)
plotsig(-M.I[0], "$-I_\mathrm{syn}$", ylim=[30, 90], **kw, ax=axs[2])
plotsig(M.V[0], "$V$", **kw, ylim=[-60, -45], ax=axs[3])
plotsig(M.w[0], "$w$", **kw, ylim=[-10.02, 70], ax=axs[4], xlim=kw["tlim"]/ms)
axs[-1].set_xlabel(None)
for ax in axs[0:-1]:
    ax.set_xlabel(None)
    ax.spines["bottom"].set_visible(False)
    ax.tick_params(bottom=False, which='both')
plt.subplots_adjust(hspace=0.7)

savefig_thesis("all_sigs_6500", fig);

# ## Impulse response

# A single spike :)

from lib.neuron import *

set_seed(2)

# +
n = COBA_AdEx_neuron()

G = SpikeGeneratorGroup(1, [0], [10*ms])
S = Synapses(G, n, on_pre="ge += we");
# -

S.connect()

vars_to_record=["V", "I", "ge", "w"]
M = StateMonitor(n, vars_to_record, record=[0])
net2 = Network([n, G, S, M])
net2.store()

net2.restore()
we = 14 * pS
wi = we * 4
T = 150 * ms
net2.run(T, report='text')

# %run lib/plot.py

kw = dict(nbins_y=3, nbins_x=3, yaxloc="right", clip_on=False)
fig, axs = plt.subplots(figsize=(1.4, 3.8), nrows=4, sharex=True)
add_hline(axs[1])
plotsig(M.ge[0], "$g_\mathrm{exc}$", **kw, ax=axs[0], color="C2")
plotsig(-M.I[0], "$-I_\mathrm{syn}$", **kw, ax=axs[1])
plotsig(M.V[0], "$V$", **kw, ax=axs[2])
plotsig(M.w[0], "$w$", **kw, ax=axs[3])
axs[-1].set_xlabel(None)
for ax in axs[0:-1]:
    ax.set_xlabel(None)
    ax.spines["bottom"].set_visible(False)
    ax.tick_params(bottom=False, which='both')
plt.subplots_adjust(hspace=1.2)

savefig_thesis("impulse_response", fig)

C / gL


