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
we = 14 * pS
wi = we * 4
T = 1 * second
net.run(T, report='text')

# %run lib/plot.py

n, P, Se, Si, M, S, SP = objs;

kw = dict(tlim = [300, 500]*ms, t_unit=ms, nbins_y=3, yaxloc="right")
fig, axs = plt.subplots(figsize=(4, 5.5), nrows=5, sharex=True, height_ratios=[1,1,1,1,1])
add_hline(axs[1])
add_hline(axs[-1])
plotsig(M.ge[0], "$g_e$ & $g_i$", **kw, ylim=[0, 2.8], ax=axs[0], color="C2", label="$g_e$")
plotsig(M.gi[0], None, **kw, ylim=[0, 2.8], ax=axs[0], color="C1", label="$g_i$")
axs[0].legend(loc="lower left", ncols=2, fontsize="x-small")
plotsig(M.ge[0] - M.gi[0], "$g_e - g_i$", **kw, ylim=[-1,1], ax=axs[1], y_unit=nS)
plotsig(-M.I[0], "$-I_\mathrm{syn}$", ylim=[25, 85], **kw, ax=axs[2])
plotsig(M.V[0], "$V$", **kw, ylim=[-60, -45], ax=axs[3])
plotsig(M.w[0], "$w$", **kw, ylim=[-20, 60], ax=axs[4])
axs[0].set_xlim(kw["tlim"] / ms)
axs[-1].set_xlabel(None)
for ax in axs[0:-1]:
    ax.set_xlabel(None)
    ax.spines["bottom"].set_visible(False)
    ax.tick_params(bottom=False, which='both')
plt.subplots_adjust(hspace=0.7)

savefig_thesis("all_sigs", fig);

# ## Impulse response

# A single spike :)

# %run lib/Nto1.py

set_seed(2)
*objs_net2, net2 = Nto1(Ne=1, Ni=0, vars_to_record=["V", "I", "ge", "gi", "w"], μ=0.3)
net2.store()

net2.restore()
we = 14 * pS
wi = we * 4
T = 2 * second
net2.run(T, report='text')

n, P, Se, Si, M, S, SP = objs_net2;
P

# %run lib/plot.py

kw = dict(tlim = [850, 1050]*ms, t_unit=ms, nbins_y=3, yaxloc="right")
fig, axs = plt.subplots(figsize=(2.6, 4.2), nrows=4, sharex=True)
add_hline(axs[1])
plotsig(M.ge[0], "$g_e$", **kw, ax=axs[0], color="C2")
plotsig(-M.I[0], "$-I_\mathrm{syn}$", **kw, ax=axs[1])
plotsig(M.V[0], "$V$", **kw, ax=axs[2])
plotsig(M.w[0], "$w$", **kw, ax=axs[3])
axs[-1].set_xlabel(None)
for ax in axs[0:-1]:
    ax.set_xlabel(None)
    ax.spines["bottom"].set_visible(False)
    ax.tick_params(bottom=False, which='both')
plt.subplots_adjust(hspace=0.7)

savefig_thesis("impulse_response", fig)


