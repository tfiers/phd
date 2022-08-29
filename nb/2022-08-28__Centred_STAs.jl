# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.7
#   kernelspec:
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-08-28 • Centred STAs

# Center spike-triggered windows around 0 (mV) before averaging them.

# ..
#
# This is useless (in terms of increasing 'SNR' of the STA):
#
# If the current STA is this:
#
# $$
# STA_{cur} = \frac{1}{N} \sum_s V[s:s+W]
# $$
#
# (where $s$ is the presynaptic spiketime, $N$ the number of such spikes, $W$ the window length, and $V$ the voltage / VI signal),
#
# then the new STA would be:
#
# $$
# STA_{new} = \frac{1}{N} \sum_s \left( V[s:s+W] - V[s] \right)
# $$
#
# In other words:
# $$
# STA_{new} = STA_{cur} - \frac{1}{N} \sum_s V[s] \\
#           = STA_{cur} - STA_{cur}[1]
# $$
#
# i.e. the STA waveforms would be the same as the current ones, just shifted vertically by some value (namely the average voltage at the start of the window; or, if we had rather chosen $\texttt{mean}(V[s:s+W])$ as referencing value instead of $V[s]$: the average voltage of all windows).
#
# ---
#
# (Note that the above notation is more programm-y than mathy, with the $[…:…]$ slicing notation. In usual math notation we'd express it per timepoint: $STA[t] = \frac{1}{N} \sum_s V[s+t]$, with $t = 0, 1, …, W$).
#
# ---
#
# This idea would thus have no effect on connection detectability using the peak-to-peak measure (it would stay the same).
#
# Neither would it have an effect on the 'exc or inh' test, as that one already uses the $STA[1]$ as reference value.


