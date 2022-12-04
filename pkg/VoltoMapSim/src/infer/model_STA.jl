
# Parameters
# __________

# Default starting parameters for fitting procedure
get_p0() = CVec(
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
get_pbounds() = CVec(
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
# We make these functions instead of `const`s, so the CVecs needn't be compiled on package
# load.

toCVec(data, template::Union{CVec, Type{<:CVec}}) = CVec(data, getaxes(template))

toParamCVec(fitr::LsqFit.LsqFitResult) = toCVec(fitr.param, get_p0())


# Model
# _____

PSP(t, τ1, τ2) =
    if     (t ≤ 0)      0
    elseif (τ1 == τ2)   t * exp(-t/τ1)
    else                τ1*τ2/(τ1-τ2) * (exp(-t/τ1) - exp(-t/τ2)) end

max_of_PSP(τ1, τ2) =
    if     (τ1 == τ2)   τ1/ℯ
    else                τ2*(τ2/τ1)^(τ2/(τ1-τ2)) end

gaussian(t, loc, w, h) = h * exp(-0.5*((t-loc)/w)^2)

model_STA!(y, t, params) = @fastmath @. begin
    # Unpack parameters, and bind them
    delay, τ1, τ2, loc, w, h, scale = params
    PSP(t) = PSP(t, τ1, τ2)
    dip(t) = gaussian(t, loc, w, h)
    # To normalize PSP height to 1:
    m = max_of_PSP(τ1, τ2)
    # Evaluate the model
    y = ( PSP(t - delay) / m
        - dip(t)
        ) * scale
    # Center around 0
    y -= mean(y)
    return nothing
end
# The runtime of this function is dominated by calculating the `exp` functions (even when
# using faster approximations of exp, through `@fastmath`).



# Fitting
# _______

centre(STA) = STA .- mean(STA)

function STA_modelling_funcs(ep::ExpParams; p0 = get_p0(), pbounds = get_pbounds())
    STA_duration = ep.conntest.STA_window_length
    t = collect(linspace(0, STA_duration, STA_win_size(ep)))
    p0_vec = collect(p0)
    lower = pbounds[1:2:end]
    upper = pbounds[2:2:end]

    f!(y, p) = model_STA!(y, t, p)
    y = similar(t)  # Allocate the one and only buffer
    cfg                      = ForwardDiff.JacobianConfig(f!, y, p0_vec)
    jac_model!(J, t, params) = ForwardDiff.jacobian!(J, f!, y, params, cfg)

    fit(STA; kw...) = curve_fit(
        model_STA!, jac_model!, t, centre(STA), p0_vec;
        lower, upper, inplace = true, kw...
    )
    model(params) = (model_STA!(y, t, params); y)

    return (; fit, model)
end
