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

# # 2022-09-13 • Fit simpler model to STA -- part 2

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

s = augment(s, p);

# ## Model function

linear_PSP(t; τ1, τ2) =
    
    if (τ1 == τ2)   @. t * exp(-t/τ1)
    else            @. τ1*τ2/(τ1-τ2) * (exp(-t/τ1) - exp(-t/τ2))
    end;

# +
gaussian(x; loc, width) =  

    @. exp(-0.5*( (x-loc)/width )^2);

# Note that unlike in the previous notebook, we do add the 1/2 factor in the exponent here

# +
rescale_to_max!(x) = 
    
    x ./= maximum(abs.(x));

# Note that this returns `NaN`s if x .== 0
# -

centre!(x) = (x .-= mean(x))
centre(x) = centre!(copy(x));

mult!(by) = x -> (x .*= by);

# +
p0 = CVec(
    tx_delay   = 10ms,
    bump = (
        τ1     = 10ms,
        τ2     = 12ms
    ),
    dip = (
        loc    = 40ms,
        width  = 40ms,
        weight = 0.15,
    ),
    scale      = 0mV,
);

FitParams = typeof(p0);
# -

pbounds = CVec(
    tx_delay   = [0, 60ms],
    bump = (
        τ1     = [0, 100ms],
        τ2     = [0, 100ms],
    ),
    dip = (
        loc    = [20ms, 80ms],
        width  = [20ms, 80ms],
        weight = [0, 0.6],
    ),
    scale      = [-2mV, 2mV],
)
pb_flat = collect(CVec(pbounds))
lower = pb_flat[1:2:end]
upper = pb_flat[2:2:end];

# +
function model_STA_components(ep::ExpParams, fp::FitParams)

    Δt::Float64  = ep.sim.general.Δt
    STA_duration = ep.conntest.STA_window_length

    @unpack tx_delay, bump, dip = fp
    
    PSP_duration = STA_duration - tx_delay

    delay_size = round(Int, tx_delay / Δt)
    PSP_size   = round(Int, PSP_duration / Δt)
    STA_size   = round(Int, STA_duration / Δt)

    t_PSP = collect(linspace(0, PSP_duration, PSP_size))
    t_STA = collect(linspace(0, STA_duration, STA_size))
    
    add_delay(x) = vcat(zeros(Float64, delay_size), x)
    
    # τ1, τ2 = bump
    bump = (
        linear_PSP(t_PSP; bump.τ1, bump.τ2)
        |> rescale_to_max!
        |> add_delay
    )
    
    # loc, width, weight = bump
    dip = (
        gaussian(t_STA; dip.loc, dip.width)
        |> rescale_to_max!
        |> mult!(-dip.weight)
    )
    
    return (; bump, dip)
end


function model_STA(ep::ExpParams, fp::FitParams)
    bump, dip = model_STA_components(ep, fp)
    STA = (
        bump .+ dip
        |> mult!(fp.scale)
        |> centre!
    )
end;
# -

# ## Fit

using LsqFit

# +
# Code to adapt to LsqFit's API

p_buffer = copy(CVec(p0))

function toCVec(params::Vector, cv_buffer::CVec = p_buffer)
    cv_buffer .= params
    return cv_buffer
end

function fit_STA(STA, p0)
    model(xdata, params) = model_STA(p, toCVec(params))
    xdata = []  # Our model function generates 
                # xdata itself (it's alway the same).
    ydata = centre(STA)
    p0_vec = collect(CVec(p0))
    fit = curve_fit(model, xdata, ydata, p0_vec; lower, upper)
end;
# -

using PyPlot
using VoltoMapSim.Plot

function fit_STA(m::Int, p0 = p0, plot = true)
    STA = calc_STA(m=>1, s, p)
    fitt = fit_STA(STA, p0)
    fp = toCVec(fitt.param)
    bump, dip = model_STA_components(p, fp)
    sgn = sign(fp.scale)
    plt.subplots()
    plotsig(sgn * bump, p)
    plotsig(sgn * dip, p)
    plt.subplots()
    plotsig(centre(STA) / mV, p, hylabel = "STA $m → 1")
    plotsig(model_STA(p, fp) / mV, p)
    println(NamedTuple(fp))
    return fp
end;

fit_STA(894);

# Aha! So it was the problem :D
#
# Great. (Lesson: make parameters independent of each other).

# Now to retry the STAs fitted two nb's earlier.

# ## Exc inputs

fit_STA.([139, 136, 132]);

# Excellent. No more wonky fits.
#
# (The last one had ptp pval 0.03 btw. And avgSTA cor pval 0.12)

# ## Inh inputs

fit_STA.([988, 894, 831]);

# The first one could use the more important weighting around the bump.
#
# The last one.. Well it's the hardest inh input to detect.

# We could do like a voting approach :P  : "curve_fit thinks :non-input, ptp-area thinks :inh".

# ### After changing max dip.weight to 0.6:

# (From 1)

fit_STA.([831]);

# Great, much better.

# ## Non-inputs

fit_STA.([23, 197, 367,332]);

# - first and last (23, 332) good, nice and noisy
# - 367 was a FP for the other two algo's too.
#
# 197.. this one together with 367 and the last of the inh's above makes me think the max weight of the bump is too high.
#
# and again, that we should weight around the bump more somehow.

# ### After changing max dip.weight to 0.6:

# (Middle two)

fit_STA.([197, 367]);

# Nice, the 197 is much less well fit now.
