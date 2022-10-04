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

# # 2022-09-30 • Use parametric STA model for connection testing

# ## Imports

# +
#
# -

using MyToolbox

# +
using VoltoMapSim

# Note that we've consolidated code from the last model-fitting notebook
# in this codebase (namely in `src/conntest/model_STA.jl`).
# -

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

# ## Load STA's

# (They're precalculated).

out = cached_STAs(p);

(ct, STAs, shuffled_STAs) = out;

# +
# `ct`: "connections to test table", or simply "connections table".
# -

# ## Test single

MSE(y, yhat) = mean(abs2, y .- yhat);
# We don't use the regression definition of `mse` in LsqFit.jl,
# where they devide by DOF (= num_obs - num_params) instead of num_obs.

function get_predtype(pval, Eness, α)
    # Eness is 'excitatory-ness'
    if        (pval  > α) predtype = :unconn
    elseif    (Eness > 0) predtype = :exc
    else                  predtype = :inh end
    predtype
end;

function test_conn__model_STA(real_STA, shuffled_STAs, α; p::ExpParams)
    fitted_params = fit_STA(real_STA, p)
    fitted_model = model_STA(p, fitted_params)
    test_stat(STA) = - MSE(fitted_model, centre(STA))
    pval, _ = calc_pval(test_stat, real_STA, shuffled_STAs)
    scale = fitted_params.scale / mV
    predtype = get_predtype(pval, scale, α)
    return (; predtype, pval, MSE = test_stat(real_STA), scale)
end;

α = 0.05 
conns = ct.pre .=> ct.post
example_conn(typ) = conns[findfirst(ct.conntype .== typ)]
testconn(conn) = test_conn__model_STA(STAs[conn], shuffled_STAs[conn], α; p)
conn = example_conn(:exc)

testconn(conn)

conn = example_conn(:inh)

testconn(conn)

conn = example_conn(:unconn)

testconn(conn)

# Yeah this obviously won't work: the MSE of the STA used for fitting will always be better than the MSE of other STAs -- even if the real STA is unconnected.

# What is fit btw of this last one

real_STA = STAs[conn]
fitted_params = fit_STA(real_STA, p)
fitted_model = model_STA(p, fitted_params)
plotsig(centre(real_STA) / mV, p)
plotsig(fitted_model / mV, p);
plt.subplots()
plotsig(centre(shuffled_STAs[conn][1]) / mV, p)
plotsig(fitted_model / mV, p);

# (real STA left, one of the shuffled STAs right).

# Let's see how bad it is for all connections:

# +
# tc = test_conns(test_conn__model_STA $ (;p), ct, STAs, shuffled_STAs; α = 0.05);
# -

# ^ This is too slow to run fully.
#
# And there's an error when fitting `813 => 1`.

# How slow?

@time testconn(conn);

ETA = 0.468124seconds * length(conns) / minutes

# Imagine if we fit all shuffles (which would work ig).
# For all our tested connections, we'd have to wait:

ETA * (1+p.conntest.num_shuffles) * minutes / hours

# 4+ days. A bit long.

# Let's subsample the connections, to get some estimate for how bad performance is.

# ## Test sample



samplesize = 100
resetrng!(1234)
i = sample(1:nrow(ct), samplesize, replace = false)
ctsample = ct[i, :];

summarize_conns_to_test(ctsample)

# (I forgot to resetrng at first run. Tables below are for below sample:
# ```
# We test 100 putative input connections to 42 neurons.
# 34 of those connections are excitatory, 13 are inhibitory, and the remaining 53 are non-connections.
# ```
# )

# We have to fix that occasional fitting error too, first.

# +
testconn(917 => 8)   # Gives `InexactError: trunc(Int64, NaN)`
# (which I could step-debug in jupyter; I'll go to vscode, and use the .jl version of this nb).

# reason for error: `tx_delay / Δt` is somehow NaN.

# ~~Fixed when lower pound for tx_delay = 1 ms, instead of 0. Strange.~~
# Even then it errored for other conns. Manually checked for NaN tx_delay in model function.
# That actually fixed it.
# -

@time tc = test_conns(test_conn__model_STA $ (;p), ctsample, STAs, shuffled_STAs; α = 0.05);

# +
# strange. it somehow swallows output?
# but if I copy the cell (or add a `@show` in the loop), the output shows.
# just copy it, in jupyter, no execution! weird.
# -

perftable(tc)

# So detection rates not bad, but low precision, and 64% false positive rate for non-connections.

1-.36

# At least we had some with pval > 0.05, I would've expected all unconn's to be detected.

# ## Try proper test

# ..where we fit every shuffle as well.
# This will be very slow, so we do it on just one connection, to get an idea if it's worth pursuing (and speeding up, via automatic differentiation of our model STA, maybe).

# This is what we got above:

conn = example_conn(:unconn)

testconn(conn)

# i.e. pval 0.01.
#
# With template matching, we get pval 0.42 ([ref](https://tfiers.github.io/phd/nb/2022-09-09__Conntest_with_template_matching.html#now-for-unconnected-inputs)).
# So it is definitely predictable as unconnected.

# +
function test_conn__model_STA__proper(real_STA, shuffled_STAs, α; p::ExpParams)
    function test_stat(STA)
        print(".")  # hack to progress-track
        fitted_params = fit_STA(STA, p)
        fitted_model = model_STA(p, fitted_params)
        t = - MSE(fitted_model, centre(STA))
    end
    pval, _ = calc_pval(test_stat, real_STA, shuffled_STAs)
    scale = fit_STA(real_STA, p).scale / mV
    predtype = get_predtype(pval, scale, α)
    return (; predtype, pval, scale)
end

testconn2(conn) = test_conn__model_STA__proper(STAs[conn], shuffled_STAs[conn], 0.05; p);
# -

testconn2(conn)

# Aha! That looks good.

# Now for the example exc and inh of above.

testconn2(example_conn(:exc))

testconn2(example_conn(:inh))

# That's no good.

function plot_with_fit(STA, fitparams; kw...)
    fitted_model = model_STA(p, fitparams)
    plt.subplots()
    plotsig(centre(STA) / mV, p; kw...)
    plotsig(fitted_model / mV, p)
end;

function fit_and_plot(STA)
    fitted_params = fit_STA(STA, p)
    fitted_model = model_STA(p, fitted_params)
    rmse = √MSE(fitted_model, centre(STA)) / mV
    title = "RMSE: " * @sprintf "%.3f mV" rmse
    ylim = [-0.25, 0.35]
    plot_with_fit(STA, fitted_params; ylim, title)
end;

conn = example_conn(:exc)

fit_and_plot(STAs[conn])
fit_and_plot(shuffled_STAs[conn][1])
fit_and_plot(shuffled_STAs[conn][2])
fit_and_plot(shuffled_STAs[conn][3]);

# So the shuffleds have a better MSE.. but that's because their scale is narrower.

# We'll normalize before calculating mse:

# +
function test_conn__model_STA__proper2(real_STA, shuffled_STAs, α; p::ExpParams)
    function test_stat(STA)
        print(".")  # hack to progress-track
        fitted_params = fit_STA(STA, p)
        fitted_model = model_STA(p, fitted_params)
        zscore(x) = (x .- mean(STA)) ./ std(STA)
        t = - MSE(zscore(fitted_model), zscore(STA))
    end
    pval, _ = calc_pval(test_stat, real_STA, shuffled_STAs)
    scale = fit_STA(real_STA, p).scale / mV
    predtype = get_predtype(pval, scale, α)
    return (; predtype, pval, scale)
end

testconn3(conn) = test_conn__model_STA__proper2(STAs[conn], shuffled_STAs[conn], 0.05; p);
# -

testconn3(example_conn(:unconn))

testconn3(example_conn(:exc))

testconn3(example_conn(:inh))

# Alright! This seems to work.

# ## Try autodiff for speedup

conn

# It's hard to get ForwardDiff.jl to work with ComponentArrays.jl and @unpack.
# (might be possible). But simpler to re-write model func, more 'basic':

# +
Δt = p.sim.general.Δt::Float64
STA_duration = p.conntest.STA_window_length
t = collect(linspace(0, STA_duration, STA_win_size(p)))

linear_PSP(t, τ1, τ2) =
    if (τ1 == τ2)   @. t * exp(-t/τ1)
    else            @. τ1*τ2/(τ1-τ2) * (exp(-t/τ1) - exp(-t/τ2)) end

gaussian(t, loc, width) =
    @. exp(-0.5*( (t-loc)/width )^2)

rescale_to_max!(x) =
    x ./= maximum(abs.(x))

function model_(t, params)
    tx_delay, τ1, τ2, dip_loc, dip_width, dip_weight, scale = params
    bump = linear_PSP(t .- tx_delay, τ1, τ2)
    tx_size = round(Int, tx_delay / Δt)
    bump[1:tx_size] .= 0
    rescale_to_max!(bump)
    dip = gaussian(t, dip_loc, dip_width)
    rescale_to_max!(dip)
    dip .*= -dip_weight
    STA_model = (bump .+ dip) .* scale
    STA_model .-= mean(STA_model)
    return STA_model
end

p0_vec = collect(VoltoMapSim.p0)
lower, upper = VoltoMapSim.lower, VoltoMapSim.upper
function fit_(STA; autodiff = :finite)  # or :forwarddiff
    curve_fit(model_, t, STA, p0_vec; lower, upper, autodiff)
end;

# +
real_STA = STAs[conn]

@time fit_finite = fit_(real_STA; autodiff = :finite);  # default
# -

# Hah, our simpler function is also just faster with the default.

# +
real_STA = STAs[conn]

@time fit_AD = fit_(real_STA; autodiff = :forwarddiff);
# -

# :DDD

# Amazing.

# Is the result correct though?

plot_with_fit(real_STA, fit_STA(real_STA, p), hylabel = "Old model func")
plot_with_fit(real_STA, fit_finite.param, hylabel = "Leaner model func. Finite diff.");
plot_with_fit(real_STA, fit_AD.param, hylabel = "Leaner model func. Autodiff.");

# All three give a slightly different fit, interestingly.

# Is there a diff between our two model functions, for the same params, btw?

plt.subplots()
plotsig(centre(real_STA) / mV, p)
plotsig(model_(t, fit_AD.param) / mV, p);

# No, nothing perceptible.

# Now, use this model and AD fit for a proper conntest.

# +
function test_conn__model_STA__proper_AD(real_STA, shuffled_STAs, α; p::ExpParams, verbose = true)
    function test_stat(STA)
        verbose && print(".")
        fit = fit_(STA, autodiff = :forwarddiff)
        fitted_model = model_(t, fit.param)
        zscore(x) = (x .- mean(STA)) ./ std(STA)
        return - MSE(zscore(fitted_model), zscore(STA))
    end
    pval, _ = calc_pval(test_stat, real_STA, shuffled_STAs)
    scale = fit_STA(real_STA, p).scale / mV
    predtype = get_predtype(pval, scale, α)
    return (; predtype, pval, scale)
end

testconn4(conn) = test_conn__model_STA__proper_AD(STAs[conn], shuffled_STAs[conn], 0.05; p);
# -

# Are the pval results the same on our three examples?

testconn4(example_conn(:unconn))

# Was also 0.35 above.

testconn4(example_conn(:exc))

testconn4(example_conn(:inh))

# Same pvals (and same scales).

# Btw. Can we speedup more by calculating the jacobian beforehand, once?

# +
# ] add ForwardDiff
# -

# ..wait no. ForwardDiff api has just `jacobian(f,x)`, which is the jac evaluated at a specific point.
# No general `jacobian(f)` function.

# Another speedup might be achieved by using non-allocating (i.e. in-place, i.e. buffer-overwriting) model functions: https://github.com/JuliaNLSolvers/LsqFit.jl#in-place-model-and-jacobian

@time testconn4(example_conn(:inh));

# So testing one connection, the 'proper' way, is now 11 seconds.

# Compare before AD (and before leaner model func):

@time testconn3(example_conn(:inh));

# So 51/11 = 4.6x speedup through AD.

# Testing our sample of 100 connections would take 18 minutes.

# Let's try a non-allocating model func.

# ## In-place model & jacobian

# We cannot combine in-place with ForwardDiff by default: https://github.com/JuliaDiff/ForwardDiff.jl/issues/136
#
# We need https://github.com/SciML/PreallocationTools.jl
#
# We only need it only for our bump and dip buffers though, not for the output buffer:
# that one is handled by ForwardDiff's in-place-model API (`jacobian(f!, y, x)`).

using PreallocationTools, ForwardDiff

# +
linear_PSP!(y, t, τ1, τ2) =
    if (τ1 == τ2)   @. y = t * exp(-t/τ1)
    else            @. y = τ1*τ2/(τ1-τ2) * (exp(-t/τ1) - exp(-t/τ2)) end

gaussian!(y, t, loc, width) =
    @. y = exp(-0.5*( (t-loc)/width )^2)

rescale_to_max_!(x) =
    x ./= maximum(x)
    # Here we assume x positive, so `abs.(x)` (which allocates) is not needed.

function model_!(STA, t, params, dualcaches, Δt)
    # -- 
    # -- https://github.com/SciML/PreallocationTools.jl
    tc, bc, dc = dualcaches
    u = params[1]  # just to get type of input: Float or Dual
    tshift = get_tmp(tc, u)
    bump = get_tmp(bc, u)
    dip = get_tmp(dc, u)
    # --
    tx_delay, τ1, τ2, dip_loc, dip_width, dip_weight, scale = params
    tshift .= t .- tx_delay
    linear_PSP!(bump, tshift, τ1, τ2)
    tx_size = round(Int, tx_delay / Δt)
    bump[1:tx_size] .= 0
    rescale_to_max_!(bump)
    gaussian!(dip, t, dip_loc, dip_width)
    rescale_to_max_!(dip)
    dip .*= -dip_weight
    STA .= (bump .+ dip) .* scale
    STA .-= mean(STA)
    return nothing
end;
# -

F0 = similar(t)
tc = dualcache(similar(t))
bc = dualcache(similar(t))
dc = dualcache(similar(t))
# For curve_fit api:
model_!(STA, t, params) = model_!(STA, t, params, (tc,bc,dc), Δt);  

y = similar(t)
model_!(y, t, p0_vec)
time() = @time model_!(y, t, p0_vec)
time();

# +
f! = (F,p) -> model_!(F,t,p)

Jbuf = ForwardDiff.jacobian(f!, F0, p0_vec);
# -

# For curve_fit api:
jac_model!(J, t, params) = ForwardDiff.jacobian!(J, f!, F0, params);

jac_model!(Jbuf, t, p0_vec)
time() = @time jac_model!(Jbuf, t, p0_vec)
time();

# :OOO so few allocs 😁😁😁

@time curve_fit(model_!, jac_model!, t, real_STA, p0_vec; lower, upper, inplace = true);

# Hmm, that's lotsa allocs, and not much faster than non-inplace, it seems.
#
# non-inplace:

@time curve_fit(model_, t, real_STA, p0_vec; lower, upper, autodiff = :forward);

# Yeah. guess LsqFit.jl problem doesn't do inplace very well.
#

# Let's test for full pval loop anyway.

# +
fit_inplace(STA) = curve_fit(model_!, jac_model!, t, STA, p0_vec; lower, upper, inplace = true);

fitted_model = similar(t)  # Buffer

function test_conn__model_STA__proper_AD_inplace(real_STA, shuffled_STAs, α; p::ExpParams, verbose = true)
    function test_stat(STA)
        verbose && print(".")
        fit = fit_inplace(STA)
        model_!(fitted_model, t, fit.param)
        zscore(x) = (x .- mean(STA)) ./ std(STA)
        return - MSE(zscore(fitted_model), zscore(STA))
    end
    pval, _ = calc_pval(test_stat, real_STA, shuffled_STAs)
    verbose && println()
    scale = fit_inplace(real_STA).param[end] / mV
    predtype = get_predtype(pval, scale, α)
    return (; predtype, pval, scale)
end

testconn5(conn) = test_conn__model_STA__proper_AD_inplace(STAs[conn], shuffled_STAs[conn], 0.05; p);
# -

@time testconn5(example_conn(:inh));

# So yeah, same perf as the allocating, non-inplace version  
# (11 seconds, 1.98 M allocations: 17.231 GiB)

# +
# using ProfileView
# @profview testconn5(example_conn(:inh));
# -

# Annotated flamegraph (execution time profiling):

# ![](images/profile_curve_fit.png)
# (open original for full size)

# Conclusions from this profile:
# - The gains by writing an in-place model function were negated by performance hit of that `get_tmp` function.
#   (Hence why it was ~as fast as the previous, allocating model).
# - I do not expect a big gain by writing a jacobian function manually: the `f` evaluation
#   (right `model` 'tower' in the flamegraph) is almost as big as the `jac(f)` evaluation (left `model` tower).
#     - In other words, automatic differentiation (ForwardDiff.jl) is magic.
# - More generally: I do not expect substantial speedups are possible for this connection test method:
#   Most time is already spent in the basic operations to construct our model (`exp`, `*`).
#   Maybe a fitting algorithm that needs less function/jacobian evaluations.

# To squeeze out all performance:
# - `rescale_to_max` not needed: just divide by analytic expression for height of alpha-synpase and gaussian.
#     - I'd wager one exists for the alpha-synapse, vaguely remember seeing one somewhere even.
#     - (better than division: multiply by pre-calculated inverse)
# - Only one extra buffer (besides the first arg) is needed (so only one costly `get_tmp()` call).
#     - Maybe we can make a faster version of that dualcache, too
#     - Actually maybe we don't need any: use first arg buffer `y` for `tshift`, then `linear_PSP!(y, y, τ1, τ2)`; then add the gaussian to it; etc.
# - Provide that `JacobianConfig()` beforehand (if possible)
# - I'd wager there's faster versions of `exp` available (and we can likely get away with a bit less precision).
#     - We can try [`@fastmath`](https://docs.julialang.org/en/v1/base/math/#Base.FastMath.@fastmath), though must check whether results are still correct.
#         - ah, it indeed uses `exp_fast`: [src](https://github.com/JuliaLang/julia/blob/master/base/fastmath.jl)
# - Experiment with levenberg marquardt params & reporting: how many f/jac evals now? Can we get a good fit with fewer evaluations?
#
# The above are quite easy. More difficult:
# - Write manual jacobian (so ForwardDiff.jl machinery not needed).
#     - Seems feasible. Can test correctness with autodiff (or finite differences).

# ## Use proper method, with autodiff, on sample

# +
f = test_conn__model_STA__proper_AD $ (; p, verbose=false)

@time tc = test_conns(f, ctsample, STAs, shuffled_STAs; α = 0.05, pbar = false);
# -

1085/minutes

# 1.7 TiB allocations 😄

# backup
tc_proper = tc;

perftable(tc)

# That's not bad!\
# Comparing with the two-pass (ptp and corr) test of previous nb:

# |Tested connections: 3906|&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; |&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; |&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; |&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; |&nbsp; &nbsp; &nbsp; |&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; |
# |------------------|--------|------------|-------------|------------|-------|-------------|
# |                  |        |**┌───────**|**Real type**|**───────┐**|       |**Precision**|
# |                  |        |    `unconn`|        `exc`|       `inh`|       |             |
# |             **┌**|`unconn`|        1704|          274|          25|       |          85%|
# |**Predicted type**|   `exc`|         139|         1235|           0|       |          90%|
# |             **└**|   `inh`|         157|            6|         366|       |          69%|
# |                  |        |            |             |            |       |             |
# |   **Sensitivity**|        |         85%|          82%|         94%|       |             |

# Time comparison:
# given precalculated STAs, the ptp-then-corr method takes about 10 seconds to test 3906 connections.
# The curve fitting method takes 18 minutes for 100 connections.

(18minutes/100) / (10seconds/3906)

# 4000x faster 😄

# ## Conclusion

# In conclusion: connection-testing by curve-fitting a parametric STA model to the STAs (real and shuffled) seems to give respectable performance. However, it is multiple orders of magnitude slower than the ptp-then-corr method, taking 18 minutes to test 100 connections.

# The advantage of the parametric curve-fitting is that it can handle different transmission delays and time scales per synapse, while the ptp-then-corr method might not.
# (Though we haven't tested either assertion).

# ---

# ## [appendix]

# ### Squeezing out last drop of performance

# Max of the gaussian func as I defined it is simply 1 (namely at `t = loc`).
#
# Max of $t e^{-t/τ}$ is at $t = τ$, so: $τ/e$  
#
#
# Max of $\frac{τ_1 τ_2}{τ_1 - τ_2} \left( e^{-t/τ_1} - e^{-t/τ_2} \right)$
#
# is at $t = \frac{τ_1 τ_2}{τ_1 - τ_2} \log\left( \frac{τ_2}{τ_1} \right)$
#
# evaluated: max = $τ_2 \left( \frac{τ_2}{τ_1} \right)^\frac{τ_2}{τ_1 - τ_2}$
#
# ([thanks wolfram](https://www.wolframalpha.com/input?i=d%2Fdt+%28+a*b%2F%28a-b%29+*+%28exp%28-t%2Fa%29+-+exp%28-t%2Fb%29%29+%29+%3D+0))

# +
linear_PSP_fm!(y, t, τ1, τ2) =
    if (τ1 == τ2)   @. @fastmath y = t * exp(-t/τ1)
    else            @. @fastmath y = τ1*τ2/(τ1-τ2) * (exp(-t/τ1) - exp(-t/τ2)) end

function turbomodel!(y, t, params, Δt)
    tx_delay, τ1, τ2, dip_loc, dip_width, dip_weight, scale = params
    T = round(Int, tx_delay / Δt) + 1
    y[T:end] .= @view(t[T:end]) .- tx_delay    
    @views linear_PSP_fm!(y[T:end], y[T:end], τ1, τ2)
    if (τ1 == τ2) max = τ1/ℯ
    else          max = τ2*(τ2/τ1)^(τ2/(τ1-τ2)) end
    @views y[T:end] .*= (1/max)
    y[1:T-1] .= 0
    y .-= @. @fastmath dip_weight * exp(-0.5*( (t-dip_loc)/dip_width )^2)
    y .*= scale
    y .-= mean(y)
    return nothing
end;
# -

# Check if correct:

STA = similar(t)
p0_ = @set (p0_vec[end] = 1)
turbomodel!(STA, t, p0_, Δt)
STA_prev = model_(t, p0_)
plt.subplots()
plotsig(STA_prev, p, lw=4)
plotsig(STA, p);
# plotsig(1e5 * (STA .- STA_prev), p);

# Yah that's the same

# Comparison with previous in place model:

@benchmark model_!(y, t, p0_vec)

@benchmark turbomodel!(y, t, p0_vec, Δt)

# (Yay, got rid of last alloc).
#
# Alright, so our last optims got us a 1.5x speedup.
# -- for the Float case. When called with Duals (in the autodiff), it's probably faster still.
# Let's try.

turbomodel!(y, t, params) = turbomodel!(y, t, params, Δt)
ft! = (y,p) -> turbomodel!(y, t, p)
y = similar(t)
jac_turbomodel!(J, t, params) = ForwardDiff.jacobian!(J, ft!, y, params);

# +
turbofit(STA) = curve_fit(turbomodel!, jac_turbomodel!, t, STA, p0_vec; lower, upper, inplace = true);

fitted_model = similar(t)

function test_conn__turbofit(real_STA, shuffled_STAs, α; p::ExpParams, verbose = true)
    function test_stat(STA)
        verbose && print(".")
        fit = turbofit(STA)
        turbomodel!(fitted_model, t, fit.param)
        zscore(x) = (x .- mean(STA)) ./ std(STA)
        return - MSE(zscore(fitted_model), zscore(STA))
    end
    pval, _ = calc_pval(test_stat, real_STA, shuffled_STAs)
    verbose && println()
    scale = turbofit(real_STA).param[end] / mV
    predtype = get_predtype(pval, scale, α)
    return (; predtype, pval, scale)
end

testconn6(conn) = test_conn__turbofit(STAs[conn], shuffled_STAs[conn], 0.05; p);
# -

conn

@time testconn6(conn)

# 😁😁 we got it down
#
# (from 9 seconds to 6.4 weliswaar maar)

# Summary of speedups  
# (All for the 'proper', working, test, where we fit all shuffles)
#
# Time to test one connection:
#
# ```
# - finite differences:          51 seconds
# - autodiff:                    11 seconds
# - autodiff, in-place:           9 seconds
# - autodiff, in-place, squeezed: 6 seconds
# ```

# The 18.1 minutes for 100 connections of above was using the second out of this list.
# With the fastest version, we'd get it down to 11 minutes.
#
# Ofc we haven't multithreaded here. For 7 threads, we'd get 6x speedup say. So ~2 minutes / 100 connections.
# The 3906 tested connections would then take 1h12.

# +
# @profview testconn6(conn);
# -

# In the new flamegraph, we find exactly the improvements we expected:
# the three `get_tmp` chimneys gone, the fat `rescale_to_max` towers in jac squeezed out.
# In general, a cleaned up picture. Relatively more time in the LM BLAS calls versus our model than before.
# Much usage of exp_fast.
