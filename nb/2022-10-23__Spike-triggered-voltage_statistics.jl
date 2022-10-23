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
#     display_name: Julia 1.8.1 mysys
#     language: julia
#     name: julia-1.8-mysys
# ---

# # 2022-10-23 • Spike-triggered voltage statistics

# What is the spread of the STA at the different times-after-spike.
#
# Motivation: get insight in this signal we're analyzing and fitting / modelling.
# Most concretely, what should distribution of errors around prediction be (the default i.e. Normal(0, σₓ)?).

# ## Imports

# +
#
# -

using MyToolbox

@time_imports using VoltoMapSim

# ## Data indexing order

# We have calculated STA's before.
# But we don't want those, we want the individual 'windows'.
#
# Options to index:
# 1. k → i → tᵣ
# 2. k → tᵣ → i
# 3. tᵣ → k → i
#
# where
# - tᵣ = t_rel = time after spike
# - k  = k, possible connection
# - i  = nr of presynaptic spike
#
# Our plot will eventually have tᵣ on the x-axis, and postsyn voltage `v` on the y-axis (and the data is a heatmap of probability) (there'll also be slices, there v is the x-axis, and y is the pdf).
#
# Both these plot types will aggregate (to estimate the pdf's) over both `k` and `i`.

# We will separate plots by connection type (inh vs exc vs not-connected).
# So `k` will go first -- same as it was with STAs.

# Then tᵣ maybe?

# ## Estimate disk usage

# Estimated filesize (it's already 3GB for all STA's of one 10 min sim...)

set_print_precision(4)

mean_fr = 4Hz
duration = 10minute
windows_per_train = mean_fr * duration

samples_per_window = 1000
bytes_per_sample = 64bits / bytes
(window_disk_size = bytes_per_sample * samples_per_window) / kB

N_recorded = 50
N_pre_per_post = 3*40
N_conns = N_recorded * N_pre_per_post

# +
# Print with thousands-separator
fmt_bigint(x::Int; sep = ' ') =
    for (digit, i) in Iterators.reverse(zip(digits(x), 1:ndigits(x)))
        if (i % 3 == 0)
            print(sep)
        end
        print(digit)
    end

fmt_bigint(x) = Int(x) |> fmt_bigint;
# -

(N_windows = N_conns * windows_per_train) |> fmt_bigint

N_windows * window_disk_size / GB

# Haha. yeah.

# So saving them all on disk is not an option.

# This is annoying.  
#
# What can we reduce.
#
# Or, we do not save all datapoints, but save some aggregate.\
# 'The pdf'.\
# ig we'd bin then.\
# For a given tᵣ, which 1mV wide (e.g.) bin count do we increase.

# ## Binning strategy

# How many bins?
#
# What is the range of a typical STA.

# Scratch that, the STA has very small range compared to individual windows.
# Those go all the way to spike peak.

# But yes we want high density (resolution) in the sta range: -48 mV to -51 mV

# Can we have uniform resolution over whole v range, or is that costly.
#
# (The code is easier if uniform resolution).

# Algo would look sth like
# ```python
#
# for (pre, post) in pairs
#     for t in pre.spikes
#         for tᵣ in window_length
#             v = post.voltage[t + tᵣ]
#             pdf[pre, post, tᵣ, bin(v)] += 1
# ```

# Size of this pdf / bincounts on disk?

(N_pdfs = N_conns * samples_per_window) |> fmt_bigint

bytes_per_bin = 64bits/bytes  # Just one Int64. (could be Int32 too but eh not worth).
v_peak = 35mV  # Izh parameter
v_min = -90mV  # Guess. (Eᵢ = -80mV). We'd need two bins for if out of range.
v_range = v_peak - v_min;

# To get good resolution around STAs (-48 to -51 mV, https://tfiers.github.io/phd/nb/2022-09-01__1144_weights.html#average-sta-window)..
#
# that range should have maybe 1000 bins?\
# So 

sta_range = -48mV - -51mV
(v_resolution = sta_range / 1000) / mV

N_bins = round(Int, v_range / v_resolution) + 2

(disk_size = N_pdfs * N_bins * bytes_per_bin) / GB

# Damn.
#
# How is this larger?\
# `14 400 000 windows * 8 kB / window`\
# vs\
# `6 000 000 pdfs * 4 1000 bins * 8 byte / bin`\
#
# Hm, guess it's indeed faster to save values themselves rather than to bin them finely.

# We could:
# - simulate shorter
#     - ..but didn't we find that 10' is needed for conntesting
# - aggregate over connections, by types
#     - only 1000 * 3 pdf's then: exc, inh, unconn
#     - you then don't have option to see distr of false-positive conns
# - have coarser and/or non-uniform bins
# - bin in time also: not 1000 samples per window but e.g. 100. (1 per ms).

# For the non-uniform binning, I'd like to see histogram of *all* voltage.

# ## Voltage histogram
#
# (unconditioned, as in: not external-spike-aligned).

p = get_params(duration = 10minutes, p_conn = 0.04, g_EE = 1, g_EI = 1, g_IE = 4, g_II = 4, ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds), E_inh = -80 * mV, record_v = [1:40; 801:810]);

s = cached(sim, [p.sim]);

s = augment(s, p);

counts, bins, bars = 
    
    plt.hist(s.v[1] / mV, bins=200);

length(bins), length(counts)

bins[1:2], counts[1]

# Interesting, doesn't reach Eᵢ of -80 mV at all.
#
# <br>

bins[end-1:end], counts[end]

# Ye that last bin location tracks with izh's v_peak of 35 mV.
#
# `v_thr` is -40 mV (and then there's the slow quadratic runaway).
# This distribution might look different around -40 with a more realistic model, like AdEx (EIF).


