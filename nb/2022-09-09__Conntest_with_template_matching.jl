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

# # 2022-09-09 • Connection test using template matching

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

p = get_params(
    duration = 10minutes,
    p_conn = 0.04,
    g_EE = 1,
    g_EI = 1,
    g_IE = 4,
    g_II = 4,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
    record_v = [1:40; 801:810],
);

# ## Run sim

s = cached(sim, [p.sim]);

s = augment_simdata(s, p);

# ## Peak-to-peak perf

perf = cached_conntest_eval(s, 1, p)
perf.detection_rates

# (this is just for one postsyn neuron. For all 40 recorded, see [here](https://tfiers.github.io/phd/nb/2022-09-01__1144_weights.html?highlight=average%20sta%20window#plot-perf:~:text=detplot(exc_post%2C%20%22excitatory%22)))

# Can we get TPR_exc up?
#
# Idea is to use a template STA to correlate STA with.
# Here we'll cheat and use the average (E→E) STA as template (cheating cause it presumes knowledge of what's connected).
# This is to test viability. If this works, we can move on to fitting a parametrized analytical STA shape to an individual STA (and then somehow compare it to shuffles..).

# ## Template: average STA

using PyPlot
using VoltoMapSim.Plot

# +
exc_post = [1:40;]
avgSTA = nothing
N = 0
@showprogress for n in exc_post
    ii = s.input_info[n]
    for m in ii.exc_inputs
        STA = calc_STA(m, n, s,p)
        if isnothing(avgSTA) avgSTA = STA
        else avgSTA .+= STA end
        N += 1
    end
end
avgSTA ./= N

plotsig(avgSTA / mV, p);
# -

# Great. Now we'll use this for conntest.
#
# We'll take one difficult connection as example.
# (See previous notebook)

m = 136
n = 1
plotSTA(m, n, s,p);

# Pval of 136 was 0.09.

STA = calc_STA(m,n,s,p);

ref_to_start(sig) = sig .- sig[1]
fig,ax = plt.subplots()
plotsig(ref_to_start(avgSTA) / mV, p; ax)
plotsig(ref_to_start(STA) / mV, p; ax)
add_refline(ax);

# And what if we ref to mean? (Which is what'd happen if we'd calculate (Pearson) correlation between signal and template).

centre(sig) = sig .- mean(sig)
fig,ax = plt.subplots()
plotsig(centre(avgSTA) / mV, p; ax)
plotsig(centre(STA) / mV, p; ax)
add_refline(ax);

# I like the former better, signals seem aligned better.
#
# Though otoh, the first sample is more noisy than the mean of all samples of the STA.

# Alright let's go for mean centring.

corr = cor(STA, avgSTA)

# ## Correlate shuffleds w/ template

# Now do the same for shuffled STAs.

spikes = s.spike_times[m]
v = s.signals[n].v
shuffled_corrs = Float64[]
for i in 1:100
    shuffled_STA = calc_STA(v, shuffle_ISIs(spikes), p)
    push!(shuffled_corrs, cor(template, shuffled_STA))
end

ydistplot(shuffled_corrs, ref = corr, ylim = [-1,1]);

# Aha, so for this one we beat the p = 0.09 :)  
# (with p < 0.01)

# ## Use as conntest, for all exc inputs

# We went to apply to all `1`'s exc inputs now.

# First, reuse our `test_connection` function in the codebase  
# (we add an argument `f` to pass an arbitrary test statistic function).

# +
test_statistic(STA) = cor(STA, avgSTA)

pval = test_connection(v, spikes, p, test_statistic)
# -

# Good, same as above.

ii = s.input_info[n]
corrs = Float64[]
pvals = Float64[]
@showprogress for m in ii.exc_inputs
    push!(pvals, test_connection(v, s.spike_times[m], p, test_statistic))
    push!(corrs, cor(calc_STA(m,n,s,p), avgSTA))
end;

ENV["COLUMNS"] = 100;

tn = perf.tested_neurons
df = tn[tn.real_type .== :exc, :]
df.pval_with_template_corr = pvals
df.corr_with_template = corrs
df

# Changes wrt previous statistic (peak-to-peak):
# - 565, 136, 194, 352, 800 correctly detected now
# - 101 and 33 still not detected (see prev nb for STA plots).
# - 132 not detected anymore (and 337's p value went up to 0.04)

plotSTA(132, 1, s,p);
plotSTA(337, 1, s,p);

# Ignoring the `predicted type == inh` for now (which is a different problem -- though we might solve by using `corr` instead of `area over start`) ..

df = df[df.predicted_type .!= :inh, :]
# TPR_exc_ptp = 
TPR_exc_ptp = count(df.pval .< 0.05) / nrow(df)

TPR_exc_template_match = count(df.pval_with_template_corr .< 0.05) / nrow(df)

# That seems like an improvement.

# ## Same but for inh inputs

test_statistic(STA) = -cor(STA, avgSTA);

# Here we use the negative corr as test stat.
#
# This will require determining the type of a potential connection first, before deciding whether it exists.

corrs = Float64[]
pvals = Float64[]
@showprogress for m in ii.inh_inputs
    push!(pvals, test_connection(v, s.spike_times[m], p, test_statistic))
    push!(corrs, cor(calc_STA(m,n,s,p), avgSTA))
end;

df = tn[tn.real_type .== :inh, :]
df.pval_with_template_corr = pvals
df.corrs_with_template = corrs
df

# Aha, the correlations are all negative.  
# And they were all positive for the exc inputs. So this is a better exc-or-inh decider.

# And same performance, voila :)

# ## Now for unconnected inputs.

df = tn[tn.real_type .== :unconn, :];

corrs = Float64[]
pvals = Float64[]
predtypes = Symbol[]
@showprogress for m in df.input_neuron_ID
    corr = cor(calc_STA(m,n,s,p), avgSTA)
    if (corr > 0) test_statistic(STA) = cor(STA, avgSTA)
    else          test_statistic(STA) = -cor(STA, avgSTA) end
    pval = test_connection(v, s.spike_times[m], p, test_statistic)
    if (pval ≥ 0.05)     predtype = :unconn
    elseif (corr > 0)    predtype = :exc
    else                 predtype = :inh end
    push!(pvals, pval)
    push!(corrs, corr)
    push!(predtypes, predtype)
end;

ENV["LINES"] = 100;
ENV["COLUMNS"] = 200;

df.predtype_corr = predtypes
df.pval_with_template_corr = pvals
df.corrs_with_template = corrs
df

FPR__ptp = count(df.pval .< 0.05) / nrow(df)

FPR__template_match = count(df.pval_with_template_corr .< 0.05) / nrow(df)

# So no change in the FPR (at α 0.05 at least).

# Plot the interesting cases where predictions differ.

function plotcase(m)
    row = first(df[df.input_neuron_ID .== m, :])
    title = jn("ptp:  $(row.predicted_type) ($(row.pval))",
               "corr: $(row.predtype_corr) ($(row.pval_with_template_corr))")
    plotSTA(m,n,s,p, hylabel="STA $m (unconn) → $n"; title)
end
for m in df[(df.predicted_type .!= :unconn) .| (df.predtype_corr .!= :unconn), :].input_neuron_ID
    plotcase(m)
end

# (For comparison, some clearly unconnecteds):

plotcase(23);
plotcase(25);

# Now, apply this to all recorded postsynaptic neurons.

# For that, we'll add this connection test (and connection type test) to our codebase.

# ## Copy-and-edit from codebase

# (These functions use external var `avgSTA`).

# Renaming some existing funcs 
STA_shuffle_test             = VoltoMapSim.test_connection
test_conn_using_ptp_and_area = VoltoMapSim.test_connection_and_type;

function test_conn_using_corr(v, spikes, p::ExpParams)
    @unpack α = p.evaluation
    STA = calc_STA(v, spikes, p)
    corr = cor(STA, avgSTA)
    if (corr > 0) test_stat = STA -> cor(STA, avgSTA)
    else          test_stat = STA -> -cor(STA, avgSTA) end
        # have to use anonymous funcs here: https://stackoverflow.com/a/65660721/2611913
    pval = STA_shuffle_test(v, spikes, p, test_stat)
    if     (pval ≥ α)  predtype = :unconn
    elseif (corr > 0)  predtype = :exc
    else               predtype = :inh end
    return predtype, (; pval, corr)
end;

# +
function evaluate_conntest_perf_v3(s, m, p::ExperimentParams, verbose = true, testfunc = test_conn_using_ptp_and_area)
    # s = augmented simdata
    # m = postsynaptic neuron ID
    # testfunc is a function taking (voltage, spikes, p) and 
    #   returning (predicted_type::Symbol, extra_info::NamedTuple)
    @unpack N_tested_presyn, rngseed = p.evaluation;
    resetrng!(rngseed)
    function get_IDs_labels(IDs, label)
        # Example output: `[(3, :exc), (5, :exc), (12, :exc), …]`.
        N = min(length(IDs), N_tested_presyn)
        IDs_sample = sample(IDs, N, replace = false, ordered = true)
        return zip(IDs_sample, fill(label, N))
    end
    ii = s.input_info[m]
    IDs_labels = chain(
        get_IDs_labels(ii.exc_inputs, :exc),
        get_IDs_labels(ii.inh_inputs, :inh),
        get_IDs_labels(ii.unconnected_neurons, :unconn),
    ) |> collect    
    tested_neurons = DataFrame(
        input_neuron_ID = Int[],     # global ID
        real_type       = Symbol[],  # :unconn, :exc, :inh
        predicted_type  = Symbol[],  # idem
    )
    extra_infos = []
    N = length(IDs_labels)
    pbar = Progress(N, desc = "Testing connections: ", enabled = verbose, dt = 400ms)
    for (n, label) in IDs_labels
        predtype, extra_info = testfunc(ii.v, s.spike_times[n], p)
        row = (
            input_neuron_ID = n,
            real_type       = label,
            predicted_type  = predtype,
        )
        push!(tested_neurons, Dict(pairs(row)))
        push!(extra_infos, extra_info)
        next!(pbar)
    end
    tn = tested_neurons
    # Add `extra_info` columns to table
    colnames = keys(first(extra_infos))
    for colname in colnames
        tn[!, colname] = [tup[colname] for tup in extra_infos]
    end
    # Calculate detection rates (false positive and true positive rates)
    det_rate(t) = count((tn.real_type .== t) .& (tn.predicted_type .== t)) / count(tn.real_type .== t)
    detection_rates = (
        TPR_exc = det_rate(:exc),
        TPR_inh = det_rate(:inh),
        FPR = 1 - det_rate(:unconn),
    )
    return perf = (; tested_neurons, detection_rates)
end

cached_conntest_eval_v3(s, m, p; verbose = true, testfunc = test_conn_using_ptp_and_area) =
    cached(evaluate_conntest_perf_v3, [s, m, p, verbose, testfunc]; key = [m, p, string(testfunc)], verbose);
# -

perf = cached_conntest_eval_v3(s, 1, p; testfunc = test_conn_using_corr)
perf.detection_rates

# +
# evaluate_conntest_perf_v3(s, 1, p, true, test_conn_using_corr)
# -

# Cool, works (and we now get our final improvement for neuron `1`, with the new exc/inh decider too).
# Peak-to-peak and area performance (from above):  
# `(TPR_exc = 0.615, TPR_inh = 0.9, FPR = 0.125)`

# Now apply to all 50 recorded postsynaptic neurons

# ## Conntest all recorded neurons

using Base.Threads
detrates_corr = Dict()
recorded_neurons = p.sim.network.record_v
pbar = Progress(length(recorded_neurons))
@threads for m in recorded_neurons
    perf = cached_conntest_eval_v3(s, m, p, verbose = false, testfunc = test_conn_using_corr)
    detrates_corr[m] = perf.detection_rates
    next!(pbar)
end

# (Time taken: ~13 minutes).

function statstable(funcs, df; funcnames = string.(funcs), print = true, funcs_are_rows = true)
    # Apply each function in `funcs` to each column of the given DataFrame.
    statcols = [
        fname => [f(col) for col in eachcol(df)]
        for (f, fname) in zip(funcs, funcnames)
    ]
    df = DataFrame("" => names(df), statcols...)
    if (funcs_are_rows) df = permutedims(df, 1) end
    if print
        printsimple(df, formatters = ft_printf("%.2f"), alignment = :r)
        println()
    end
    return df
end;

# +
to_df(detrates::Dict, ids) = DataFrame([detrates[n] for n in ids])

title(groupname, ids) = "Detection rates for $groupname neurons (n = $(length(ids)))"

detrate_distplot(detrates::DataFrame, hylabel) = ydistplot(
    "Exc. inputs" => detrates.TPR_exc,
    "Inh. inputs" => detrates.TPR_inh,
    "Unconn."     => detrates.FPR;
    ylim = [0,1],
    hylabel,
    ref = p.evaluation.α,
)
detrate_distplot(detrates, ids, groupname) = detrate_distplot(to_df(detrates, ids), title(groupname, ids))

function table(detrates, ids, groupname)
    println("\n", title(groupname, ids), ":", "\n")
    statstable([mean, median], to_df(detrates, ids))
    println("\n")
end;

function call_for_both(f, detrates)
    f(detrates, exc_post, "excitatory")
    f(detrates, inh_post, "inhibitory")
end

detrate_distplots(detrates) = call_for_both(detrate_distplot, detrates)
tables(detrates)            = call_for_both(table, detrates);
# -

exc_post = 1:40
inh_post = 801:810;

detrate_distplots(detrates_corr);

tables(detrates_corr);

# (Could do a 95% confidence interval on e.g. median by bootstrap).

# ## Compare with before (peak-to-peak & area-over-start)

detrates_ptp = Dict()
@showprogress for m in neurons
    perf = cached_conntest_eval(s, m, p, verbose = false)  # note: the previous eval func
    detrates_ptp[m] = perf.detection_rates
end

tables(detrates_ptp)

# ## Match with template but not using correlation; ref to start

ref_to_start(sig) = sig .- sig[1]
correspondence_with_template(STA) = mean(ref_to_start(STA) .* ref_to_start(avgSTA));

function test_conn_using_match_and_ref_to_start(v, spikes, p::ExpParams)
    @unpack α = p.evaluation
    STA = calc_STA(v, spikes, p)
    corr = correspondence_with_template(STA)
    if (corr > 0) test_stat = STA -> correspondence_with_template(STA)
    else          test_stat = STA -> -correspondence_with_template(STA) end
    pval = STA_shuffle_test(v, spikes, p, test_stat)
    if     (pval ≥ α)  predtype = :unconn
    elseif (corr > 0)  predtype = :exc
    else               predtype = :inh end
    return predtype, (; pval, corr_mV2 = corr / (mV^2))
end;

perf = cached_conntest_eval_v3(s, 1, p; testfunc = test_conn_using_match_and_ref_to_start)
perf.detection_rates

# Hah, so it works, but not as good as with correlation!
#
# For all neurons:

detrates_startref = Dict()
pbar = Progress(length(recorded_neurons))
@threads for m in recorded_neurons
    perf = cached_conntest_eval_v3(s, m, p, verbose = false, testfunc = test_conn_using_match_and_ref_to_start)
    detrates_startref[m] = perf.detection_rates
    next!(pbar)
end

detrate_distplots(detrates_startref);

tables(detrates_startref);

# ## Compare all three

# We'll take the median.

# +
maindf = DataFrame(
    test_method = String[],
    postsyn_type = Symbol[],
    detrate_type = Symbol[],
    median = Float64[],
)
data = [
    "ptp-area"     => detrates_ptp,
    "corr"         => detrates_corr,
    "ref-to-start" => detrates_startref,
]
for (test_method, detrates) in data, postsyn_type in (:exc, :inh)
    group = (postsyn_type == :exc) ? exc_post : inh_post
    df = to_df(detrates, group)
    for (detrate_type, col) in pairs(eachcol(df))
        row = (; test_method, postsyn_type, detrate_type, median = median(col))
        push!(maindf, Dict(pairs(row)))
    end
end

df = copy(maindf)
sort!(df, [:detrate_type, :postsyn_type])
rename!(df, "postsyn_type" => "postsyn", "detrate_type" => "")
printsimple_(df) = printsimple(df, formatters = ft_printf("%.2f"), alignment = :r)
printsimple_(df);
# -

# - `ptp-area` is what we did before (peak-to-peak of STA, and area-over-start to decide whether exc or inh.
# - `corr` is correlation of STA with template (which is average E→E STA)
# - `ref-to-start` is like corr, but using `mean(ref(STA) .* ref(avgSTA))` where `ref` centers around starting value (instead of around mean).

# So:
# - regarding FPR, `corr` is no better or worse than `ptp-area`. `ref-to-start` is worse.
# - for all TPRs, `ref-to-start` is better than the previous `ptp-area`, and `corr` is even better.

# Filtering and widening the table to highlight the detection improvements:

df = copy(maindf)
subset!(df, :test_method => ByRow(!=("ref-to-start")), :detrate_type => ByRow(!=(:FPR)))
df = unstack(df, :test_method, :median)
transform!(df, :detrate_type => ByRow(x -> string(x)[end-2:end]) => :pre, :postsyn_type => ByRow(string) => :post)
sort!(df, :pre)
select!(df, [:pre, :post] => ByRow((pre,post) -> "$pre → $post") => "", "ptp-area" => "before", "corr" => "after");

# ## Summary

println("Median detection rate:\n")
printsimple_(df)

# (And median FPRs stay the same).

# Significant improvement.
#
# Still, 1 out of 5 exc inputs still not detected (before was 2 out of 5).  
#
# Looking at their STAs though (101 and 33 ([here][1]), and 132 (here above)), it makes sense they're not detected: the STAs look like noise. Still, why do these inputs have a weaker STA?
#
# Also, we're still cheating (with `avgSTA` as template to correlate with). Now time to play fair and fit a func.  
# How much of improvement will remain :p
#
# [1]: https://tfiers.github.io/phd/nb/2022-09-05__Why-not-detected.html#id1:~:text=plott(101)%3B%0Aplott(33)%3B
