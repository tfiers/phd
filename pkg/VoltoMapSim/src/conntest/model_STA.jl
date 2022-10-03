

linear_PSP(t; τ1, τ2) =
    if (τ1 == τ2)   @. t * exp(-t/τ1)
    else            @. τ1*τ2/(τ1-τ2) * (exp(-t/τ1) - exp(-t/τ2)) end

gaussian(x; loc, width) =
    @. exp(-0.5*( (x-loc)/width )^2)


# Starting parameters for fitting procedure
p0 = CVec(
    tx_delay   = 10ms,
    PSP = (
        τ1     = 10ms,
        τ2     = 12ms
    ),
    dip = (
        loc    = 40ms,
        width  = 40ms,
        weight = 0.15,
    ),
    scale      = 0mV,
)
FitParams = typeof(p0)

pbounds = CVec(
    tx_delay   = [0, 60ms],
    PSP = (
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
lower = pbounds[1:2:end]
upper = pbounds[2:2:end]

function model_STA(ep::ExpParams, fp::FitParams)
    PSP, dip = model_STA_components(ep, fp)
    STA = (
        PSP .+ dip
        |> mult!(fp.scale)
        |> centre!
    )
end

function model_STA_components(ep::ExpParams, fp::FitParams)
    Δt::Float64  = ep.sim.general.Δt
    STA_duration = ep.conntest.STA_window_length
    @unpack tx_delay, PSP, dip = fp
    if isnan(tx_delay)
        # Occasional bug (?) in LsqFit, when near lower bound.
        tx_delay = toCVec(lower, FitParams).tx_delay
    end
    PSP_duration = STA_duration - tx_delay
    delay_size = round(Int, tx_delay / Δt)
    PSP_size   = round(Int, PSP_duration / Δt)
    STA_size   = round(Int, STA_duration / Δt)
    t_PSP = collect(linspace(0, PSP_duration, PSP_size))
    t_STA = collect(linspace(0, STA_duration, STA_size))
    add_delay(x) = vcat(zeros(Float64, delay_size), x)
    PSP = (
        linear_PSP(t_PSP; PSP.τ1, PSP.τ2)
        |> rescale_to_max!
        |> add_delay
    )
    dip = (
        gaussian(t_STA; dip.loc, dip.width)
        |> rescale_to_max!
        |> mult!(-dip.weight)
    )
    return (; PSP, dip)
end

mult!(by) = x -> (x .*= by)

centre!(x) = (x .-= mean(x))
centre(x)  = x .- mean(x)

rescale_to_max!(x) =
    x ./= maximum(abs.(x))


function fit_STA(STA, p::ExpParams)
    # Code to adapt to LsqFit's API (`curve_fit`), which cannot handle CVecs.
    model(xdata, pvec) = model_STA(p, pvec)
    xdata = []  # Our model function generates `xdata` itself (it's alway the same).
    ydata = centre(STA)
    p0_vec = collect(p0)
    fit = curve_fit(model, xdata, ydata, p0_vec; lower, upper)
    return toCVec(fit.param, FitParams)
end

model_STA(ep::ExpParams, fp::Vector{Float64}) = model_STA(ep, toCVec(fp, FitParams))

toCVec(data::Vector, template) = CVec(data, getaxes(template))
    # `template` can be a cvec, or a type of cvec.
