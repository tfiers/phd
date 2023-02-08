# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Julia 1.9.0-beta3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-02-07 • AdEx ↔ Izhikevich comparison

@showtime using MyToolbox
@showtime using SpikeWorks

# ## Converting Izh to AdEx params

# Equations:

# ### AdEx
#
# aka aEIF

# https://tfiers.github.io/phd/nb/2021-12-08__biology_vs_Izh_subhtr.html

# Richard Naud, Nicolas Marcille, Claudia Clopath, and Wulfram Gerstner,\
# ‘Firing patterns in the adaptive exponential integrate-and-fire model’,\
# Biol Cybern, Nov. 2008, https://doi.org/10.1007/s00422-008-0264-7

# $$
# \begin{align}
# C \frac{dV}{dt}      &= -g_L (V - E_L) + g_L \Delta_T \exp \left( \frac{V - V_T}{\Delta_T} \right) + I - w\\
# \tau_w \frac{dw}{dt} &= a (V - E_L) - w
# \end{align}
# $$
#
# if $V > 0$ mV, then
#
# $$
# \begin{align}
# V &→ V_r\\
# w &→ w + b
# \end{align}
# $$

# ### Izhikevich
# 2007 Book, eqs 5.7-5.8 ("Reduction to Simple model" → "Derivation via I-V relations")
#
# (See also https://www.izhikevich.org/publications/spikes.htm for the 2003 version, with 'hardcoded' $C$, $v_r$, $v_t$;\
# so that only four params $\{a, b, c, d\}$).

# $$
# \begin{align}
# C \frac{dv}{dt} &= k(v-v_r)(v-v_t) - u + I\\
# \frac{du}{dt} &= a(b(v-v_r) - u)
# \end{align}
# $$
#
# if $v ≥ v_\text{peak}$, then
#
# $$
# \begin{align}
# v &→ c\\
# u &→ u + d
# \end{align}
# $$

# ### Param comparison

# Exactly equal:
#
# | AdEx LIF | Izhikevich | My Izh. code | Units     | Function 
# |----------|:-----------|:-------------|:----------|:--------
# | $V$      | $v$        | $v$          | [V]       | Membrane voltage
# | $w$      | $u$        | $u$          | [A]       | Adaptation current
# | $C$      | $C$        | $C$          | [F]       | Membrane capacitance
# | $τ_w$    | $1\ /\ a$  | $1\ /\ a$    | [s]       | Time ct. of adaptation current
# | $a$      | $b$        | $b$          | [A/V = S] | Sensitivity of adapt. current on v (\*)
# | $+I$     | $+I$       | $-I$         | [A]       | Synaptic & electrode current
# | $0$ mV   | $v_\text{peak}$ | $v_s$   | [V]       | Spike definition/cutoff threshold
# | $V_r$    | $c$        | $v_r$        | [V]       | Reset voltage after spike
# | $b$      | $d$        | $Δu$         | [A]       | Adapt. current bump after spike
#
# (\*) Sensitivity of adapt. current, o or coupling strength of $(V-V_L)$ on it

# Same role, approximately same:
#
# | AdEx LIF | Izhikevich | My Izh. code | Units | Function 
# |----------|:-----------|:-------------|:------|:--------
# | $E_L$    | $v_r$      | $v_l$        | [V]   | Resting ('leak') membrane potential
# | $V_T$    | $v_t$      | $v_t$        | [V]   | Spike run-off threshold (when no adapt. & ext. current)

# Approx same role:
#
# | AdEx LIF | Izhikevich | Units | Function 
# |----------|:-----------|:------|:--------
# |   /      | $k$        | [S/V] | Larger: steeper parabola (of v̇) -- and v̇ more sensitive to depolarization
# | $g_L$    |  /         | [S]   | Larger: steeper exponential (of v̇) -- and v̇ more sensitive to depolarization. (Leak conductance)
# | $Δ_T$    |  /         | [V]   | Smaller: steeper exponential (of v̇). 'Threshold slope factor'
#
# Thus:
#
# $$
# k \propto \frac{g_L}{Δ_T}
# $$
#
# ---

# (Dayan & Abbott book has $V$:
#
# $$
# c_m \frac{dV}{dt} = -i_m + \frac{I_e}{A}
# $$
# Multiplying out the cell membrane size $A$:
#
# $$
# C \frac{dV}{dt} = -I_m + I_e
# $$
# )
#
# On $I$:\
# `sign convention for current entering/leaving cell: C v̇ = –Iₘₑₘ +Iₑₓₜ`\
# Positive charges flowing **out** of membrane: Iₘₑₘ pos.\
# Positive charges flowing from electrode **into** cell: Iₑₓₜ pos.\
# (So I made a mistake here). (Which seems to be cancelled out: exc STAs are upwards).

# ### AdEx has one parameter more than Izhikevich
#
# This allows it to decouple the two sensitivities of V̇, around its two fixed points (resting potential and spiking threshold).\
# In Izhikevich, you cannot make one more sensitive without also making the other more sensitive.

# ### Parameter reduction

# Naud et al 2008 divide their nine params into:
# - Scaling parameters: $C, g_L, E_L, Δ_T, V_T$
# - Bifurcation parameters: $a, τ_w, b, V_r$
#
# In Izh reduction, these four bifurcation parameters are:
# - In the same order: $b, 1/a, d, c$
#   
# (Now the other way round:
# - Izh  $a, b, c, d = $
# - AdEx $1/τ_w, a, V_r, b$
#
# )
#
# Note that for both models, when transforming a model in biological units (with all 9 or 8 params)\
# to a dimensionless one, with just 4 bifurcation parameters,\
# the bifurcation parameters (_with the same names_), will get different values.

# ### I-V relation

# Re Izh book, same place as reff'ed above.
#
# Guide to the derivation there, and fig 5.24:
# - "Instantaneous I-V relation, $I_0(V)$" is for $\dot{v} = 0$ and $u = 0$
#     - $I = -k(v-v_r)(v-v_t)$
# - "Steady-state I-V relation, $I_\infty(V)$" is for $\dot{v} = 0$ and $u \neq 0$; but $\dot{u} = 0$
#     - $I = -k(v-v_r)(v-v_t) + u$
#     - $\ \ = -k(v-v_r)(v-v_t) + b(v-v_r)$
#     - ($\ \ = -k v^2 + (kv_t+kv_r+b)v + (bv_r - kv_rv_t)$)
#
# indeed around $v_r$ ($= E_L$), the linearization (derivative) of V̇ wrt V gives the input conductance
# (= 1/R, with R the input resistance).
#
# Derivative of steady-state I(V) wrt $v$:\
# $-2kv + (kv_t+kv_r+b)$
#
# At $v=v_r$:\
# $b + k(v_t - v_r)$.
#
# Rheobase = smallest current with which cell generates action potential, when applied 'infinitely' (300 ms) long.

# ### Sign of $b$ (Izh) / $a$ (AdEx)
#
# - $b < 0$: positive feedback
# - $b > 0$: negative feedback
#
# Confusing, yes.\
# The former is 'amplifying',\
# the latter is 'resonant', adaptation.

# ### Same parametrization

# Let's choose AdEx's.
#
# i.e. express Izhikevich equation w/ AdEx names for params.
#
# As the diff.eq. for the adaptation current is exactly the same, we omit it.\
# Idem for the non-continuous spike detection and reset.\
# That leaves us the membrane potential diff.eq, from which we leave out the non-membrane currents, as they are also identical.
#
# Izh:
#
# $$
# C \dot{V} = k(V-E_L)(V-V_T)
# $$
#
# AdEx:
#
# $$
# C \dot{V} = -g_L(V-E_L) + g_L Δ_T \exp \left( \frac{V - V_T}{\Delta_T} \right)
# $$

# ### $k$ ↔ $g_L$

# In Izhikevich, the slope of v̇(v) around the resting potential (= the input conductance)
# is, for $u = 0$, and at $v = v_r$:
#
# $$
# \begin{align}
#  & \frac{d}{dv}\left( k(v-v_r)(v-v_t) \right)\\
# =& 2kv - kv_t - kv_r\\
# =& k(v_r - v_t)
# \end{align}
# $$
#
# Linearizing AdEx's v̇(v) around the resting potential,
# ignoring the exponential as it's small:
#
# $$
# \begin{align}
#  & \frac{d}{dV}\left( -g_L (V - E_L) \right)\\
# =& -g_L
# \end{align}
# $$

# Is input conductance same thing as leak conductance? I suppose so.\
# (Yes, caption of table 1 [here] says so, e.g: "Total leak conductance (a.k.a. input conductance)").
#
# [here]: https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1002550
#
# So, we then have our relationship:
#
# $$
# g_L = k(v_t - v_r)
# $$

# For our good old Cortical RS (regular spiking) parameters we've always used, this is:
# - $k = 0.7$ nS/mV
# - $v_r = -60$ mV
# - $v_t = -40$ mV
#
# and thus
# - $v_t - v_r = 20$ mV
# - $g_L = 14 $ nS

# Is this realistic?\
# Table 1 (after fig 4) in Naud 2008 gives $g_L$ values between 2.9 and 18 nS.\
# So yes, totally.

# ### $k$ ↔ $\Delta_T$

# We will linearize AdEx's V̇(V) around $V=V_T$\
# We cannot ignore the linear (leak) term now, I think.
#
# (Given that a parabola has the same slope at both zeros (just inversed sign),
# we already know it for Izh (namely $k(v_t-v_r)$)).
#
# $$
# \begin{align}
#  & \frac{d}{dV}\left( -g_L (V - E_L) + g_L Δ_T \exp\left(\frac{V - V_T}{Δ_T}\right) \right)\\
# =& -g_L + g_L Δ_T\ \ \frac{d}{dV}\left(\frac{V - V_T}{Δ_T}\right)\ \  \exp\left(\frac{V - V_T}{Δ_T}\right)\\
# =& -g_L + g_L Δ_T\ \ \frac{1}{Δ_T} \ \ \ \ \ \  \exp\left(\frac{V - V_T}{Δ_T}\right)\\
# \\
# & \text{(substituting $V=V_T$)}\\
# =& -g_L + g_L \frac{Δ_T}{Δ_T}  \exp(0)\\
# =& -g_L + g_L\\
# =&\ 0
# \end{align}
# $$
#
# Aha.\
# $V_T$ is thus not the approx runaway threshold.\
# It's where V̇(V) is minimal.\
# (The derivative at $V_T$ is zero).

# ---
# (For Izh, minimum is where $2kv - kv_t - kv_r = 0$,\
# or $v = (v_t + v_r)/2$\.
# That makes total sense.
#
# ---

# So where is the unstable fixed point?\
# At V̇=0, or:
#
# $$
# \begin{align}
# V - E_L &= Δ_T \exp\left(\frac{V - V_T}{Δ_T}\right)\\
# \\
# \left(\frac{V - E_L}{Δ_T}\right) &= \exp\left(\frac{V - V_T}{Δ_T}\right)
# \end{align}
# $$
#
# (We can take log; but doesn't help much).
#
# WolframAlpha [says] root at:
#
# $$
# V = E_L - Δ_T\ W(-e^{(E_L/Δ_T - V_T/Δ_T)})
# $$
#
# with W = ProductLog = https://mathworld.wolfram.com/LambertW-Function.html
#
# [says]: https://www.wolframalpha.com/input?i=f%28V%29+%3D+-g*%28V-L%29%2Bg*D*exp%28%28V-T%29%2FD%29
#
# Evaluating the second term for the Naud's cortical RS (below):

E_L = -65 # mV
V_T = -52 # mV
Δ_T = 0.8 # mV
;

# The exponent is 

(E_L/Δ_T - V_T/Δ_T)  # mV

# The LambertW function passes through 0.\
# So this root is just our resting potential.\
# (It's $E_L$, minus a tiny correction due to the exponential term; which is nearly 0 there).

# So where is our second root??

# We'll plot it. Above values,\
# and g_L = 1.\
# [Link](https://www.wolframalpha.com/input?i=plot+f%28V%29+%3D+-%28V%2B65%29%2B0.8*exp%28%28V%2B52%29%2F0.8%29+from+-70+to+-48)
#
# Ok so phew, I'm not crazy, there's two roots.

# Eh, I guess it just can't be found analytically.

# So let's do numerically then.\
# Unstable fixed point (firing thr), and slope there:

# Or not, it's fine. Not needed now. (We could do it, if we wanted).

# WolframAlpha of the plot above gives -49.6 mV.
#
# The slope there is:
#
# $$
# g_L \left( \exp\left(\frac{V - V_T}{Δ_T}\right) - 1 \right)
# $$
#
# Or:

# +
g_L = 4.3 # nS
V = -49.6 # mV

exponent = (V-V_T)/Δ_T  # [unitless]
# -

slope = g_L * (exp(exponent)-1)  # nS

# That looks about right.

# ### Value for $\Delta_T$

# They compare with real regular spiking cells, 'RS'.\
# Again table 1: $Δ_T = 0.8$ mV (lowest of the table; highest is 5.5 mV).

# ### Param value comparison, for cortical RS neuron
# Putting it all together, param comparison of AdEx RS of Naud et al, with Izhikevich's RS (Mark's technical report):
#
#
# | Naud 2008 AdEx | Val       | Val         | Izh / report  | What
# |---------------:|:----------|:------------|:--------------|:----
# | $C$            | 104 pF    | 100  pF     | $C$           |
# | $C/g_L$        | 24 ms     | ?           | ?             | Time constant of voltage
# |                |           | 0.14  ms·mV | $C/k$         | ?
# | -------------- | --------- | ------------| --------------|
# | $g_L$          | 4.3 nS    | 14  nS      | $k(v_t-v_r)$  | Slope of V̇(V) at rest
# | $E_L$          | -65 mV    | -60  mV     | $v_r$         | Rest (stable fixed point)
# | $V_T$          | -52 mV    | -50  mV     | $(v_t+v_r)/2$ | Minimum of V̇(V)
# |                | -49.6 mV  | -40  mV     | $v_t$         | Threshold (unstable fixed point)
# |                | 82 nS     | 14  nS      | $k(v_t-v_r)$  | Slope of V̇(V) at threshold
# | $Δ_T$          | 0.8 mV    |             |               |
# | -------------- | --------- | ------------| --------------|
# | $a$            | -0.8 nS   | -2  nS      | $b$           | Sensitivity of adapt. current
# | $τ_w$          | 88 ms     | 33 ms       | $a^{-1}$      | Time ct of adapt. current
# | $b$            | 65 pA     | 100  pA     | $d$           | Adapt. current bump after spike
# | $V_r$          | -53 mV    | -50  mV     | $c$           | Reset voltage after spike
#

# So the Naud RS neuron has a range -65 mV -- -50 mV  (15 mV wide)\
# Ours has -60 mV -- -40 mV  (20 mV wide).
#
# Their neuron's adaptation current adapts slower, is less influenced by V.\
# Ours is less smoothed, and has larger bumps on a spike.
#
# They reset quite high: almost at the 'knik' (minimum, $V_T$)\
# We reset in the middle of our interval.
#
# Around rest, their neuron is less sensitive (more than 3x less).\
# I.e. they should have smaller STAs.\
# (and conversely, at threshold their V̇ is almost 6x more sensitive).
#
# Their V̇ is linear over a large range\
# (see [plot] again).\
# Ours is linear nowhere.
#
# [plot]: https://www.wolframalpha.com/input?i=plot+f%28V%29+%3D+-%28V%2B65%29%2B0.8*exp%28%28V%2B52%29%2F0.8%29+from+-70+to+-48

# ### Izh time constant for voltage

# Can we find it?

# Not now.

# ### Define params
#
# We could write code to convert our current Izh params to AdEx\
# (e.g. `g_L = k*(v_t - v_r)`).\
# But why not just go with Naud 2008 cortical RS params.

# [→ Next notebook]
