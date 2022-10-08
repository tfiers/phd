
# Parameters
# __________

# Default starting parameters for fitting procedure
const p0 = CVec(
    tx_delay   = 10ms,
    PSP = (
        τ1     = 10ms,
        τ2     = 12ms
    ),
    dip = (
        loc    = 40ms,
        width  = 40ms,
        height = 0.15,   # Height of the gaussian dip, relative to the PSP height.
    ),
    scale      = 0mV,    # Positive for excitory STAs, negative for inhibitory.
)
const pbounds = CVec(
    tx_delay   = [0, 60ms],
    PSP = (
        τ1     = [0, 100ms],
        τ2     = [0, 100ms],
    ),
    dip = (
        loc    = [20ms, 80ms],
        width  = [20ms, 80ms],
        height = [0, 0.6],
    ),
    scale      = [-2mV, 2mV],
)

const FitParams = typeof(p0)
toCVec(data, template::Union{CVec, Type{<:CVec}}) = CVec(data, getaxes(template))
toParamCVec(fitr::LsqFit.LsqFitResult) = toCVec(fitr.param, FitParams)


# Model
# _____

# The below model function is rather optimized.
# For a more didactic version, see here:
# https://github.com/tfiers/phd/blob/06f600f/pkg/VoltoMapSim/src/conntest/model_STA.jl
# or the notebooks (https://tfiers.github.io/phd/nb/2022-09-11__Fit_function_to_STA.html)

linear_PSP!(y, t, τ1, τ2) =
    if (τ1 == τ2)   @fastmath @. y = t * exp(-t/τ1)
    else            @fastmath @. y = τ1*τ2/(τ1-τ2) * (exp(-t/τ1) - exp(-t/τ2)) end

max_of_PSP(τ1, τ2) =
    if (τ1 == τ2)   τ1/ℯ
    else            τ2*(τ2/τ1)^(τ2/(τ1-τ2)) end

subtract_gaussian!(y, t, loc, w, h) =
    @fastmath @. y -= h * exp(-0.5*( (t-loc)/w )^2)

function model_STA!(y, t, params, Δt)
    tx_delay, τ1, τ2, dip_loc, dip_width, dip_height, scale = params
    k = round(Int, tx_delay / Δt)
    y[1:k] .= 0
    yv = @view(y[k+1:end])
    yv .= @view(t[k+1:end]) .- tx_delay  # [1]
    linear_PSP!(yv, yv, τ1, τ2)
    yv .*= (1 / max_of_PSP(τ1, τ2))
    subtract_gaussian!(y, t, dip_loc, dip_width, dip_height)
    y .*= scale
    y .-= mean(y)
    return nothing
end
# Some explanatory notes:
# - `y` is a buffer that by the end holds the STA model curve.
#   The goal is to not allocate any new memory in this function; only modify passed memory.
# - A 'view' is a lazy reference, i.e. it avoids copying / allocating memory on slicing.
# - In [1], we temporarily use `y` to store a shifted version of the time vector `t`.
#   (This then immediately gets used and overwritten in `linear_PSP!`).
# - The runtime of this function is dominated by calculating the `exp` functions (even when
#   using faster approximations of exp, through `@fastmath`).



# Fitting
# _______

centre(STA) = STA .- mean(STA)

function STA_modelling_funcs(ep::ExpParams; p0 = p0, pbounds = pbounds)
    Δt           = ep.sim.general.Δt::Float64
    STA_duration = ep.conntest.STA_window_length
    t = collect(linspace(0, STA_duration, STA_win_size(ep)))
    p0_vec = collect(p0)
    lower = pbounds[1:2:end]
    upper = pbounds[2:2:end]

    model!(y, t, params) = model_STA!(y, t, params, Δt)
    f!(y, p) = model!(y, t, p)
    y = similar(t)  # Allocate the one and only buffer
    cfg                      = ForwardDiff.JacobianConfig(f!, y, p0_vec)
    jac_model!(J, t, params) = ForwardDiff.jacobian!(J, f!, y, params, cfg)

    fit(STA; kw...) = curve_fit(
        model!, jac_model!, t, centre(STA), p0_vec;
        lower, upper, inplace = true, kw...
    )
    model(params) = (model!(y, t, params); y)

    return (; fit, model)
end
