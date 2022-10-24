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
            print(sep)  # This will currently print " 100".
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

N_bins = N_bins__uniform_fine = round(Int, v_range / v_resolution) + 2

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
# - ~~simulate shorter~~
#     - ..but didn't we find that 10' is needed for conntesting
#     - ..this won't help for bin disk size, that's already aggregated over spikes (time)
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

ax, counts, bins, bars = hist(
    s.v[1] / mV,
    bins = 200,
    xlabel = "Vₘ (mV)",
    hylabel = "Simulated voltage distribution"
);

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

# ## Non-uniform bins

# To get non uniform bins, we could simply take the ecdf of the above historgram, and invert uniform probability bins.
#
# Problem with non-uniform: comparing pdf's between simulations. Say an AdEx simulation would have other bins.
#
# So we'd need to save the bins found here and use them for all future simulations.
#
# (..but then these bins might not be good for those simulations! They might have a different base-level voltage (say a higher EI input ratio), or have a different tail weight (like exponential vs quadratic spike runoff, presumably)).

@time vcdf = ecdf(s.v[1]);  # Sorts values. Returns a callable

extrema(vcdf) ./ mV

vcdf(-40mV)

x = range(extrema(vcdf)...; length=100)
plot(x / mV, vcdf.(x); xlabel="Vₘ (mV)", hylabel="ECDF");

# We need the inverse, i.e. quantiles, not the ECDF.

nqs = nquantile(s.v[1], 100);

plot(nqs / mV, "."; xlabel="Quantile nr.", hylabel="mV");

qbins = collect(zip(nqs[1:end-1], nqs[2:end]));
@show qbins[1] ./ mV
@show qbins[50] ./ mV
@show qbins[100] ./ mV;

# +
binsize(bin) = only(diff(collect(bin)))

@show binsize(qbins[1]) / mV
@show binsize(qbins[50]) / mV
@show binsize(qbins[100]) / mV;
# -

# With 100 bins, how big are pdfs on disk?

(N_pdfs * 100 * bytes_per_bin) / GB

# Pfoe! still too large :(

# Ok, with aggregating over connection type:

N_pdf_agg_conn = 3 * samples_per_window

N_pdf_agg_conn * 100 * bytes_per_bin / MB

# Ok. That's what we'll do then.
#
# We could have 10x (1000) bins, and still have only 20.4 MB.

# What with `N_bins__uniform_fine`? (at 0.003 mV per bin; i.e. so that typical sta range has 1000 bins)

N_bins__uniform_fine

N_pdf_agg_conn * N_bins__uniform_fine * bytes_per_bin / MB

# One gig. eh.

# I'll go for non-uniform; but more than 100 bins.
# And then we need to save these bins, so we can reuse for other simulations.

# +
nquantile_bins(x, n) = begin
    nqs = nquantile(x, n)
    collect(zip(nqs[1:end-1], nqs[2:end]));
end

binsize(bin) = only(diff(collect(bin)))
bin_info(bins, i, unit) = println(
    rpad("Bin $(i): ", 10), rpad(bins[i], 16), " $(unit). ",
    "Width: ", binsize(bins[i]), " $(unit)",
)
bin_info(bins, unit) = begin
    N = length(bins)
    mid = N ÷ 2
    for i in [1, 2, mid-1, mid, mid+1, N-1, N]
        bin_info(bins, i, unit)
    end
end

bin_info(nquantile_bins(s.v[1] / mV, 1000), "mV")
# -


