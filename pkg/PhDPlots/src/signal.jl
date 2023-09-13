

Δt::Float64 = 0.1ms
set_Δt(x) = (global Δt = x)


"""
## Example:

    plotsig(x, ms)
    plotsig(x, [200, 400], ms)
"""
plotsig(sig, tscale = minutes; kw...) = plotsig(sig, nothing, tscale; kw...)
plotsig(sig, tlim, tscale; xlabel = nothing, kw...) = begin
    t = timevec(sig) / tscale
    isnothing(tlim) && (tlim = [t[1], t[end]])
    t0, t1 = tlim
    shown = t0 .≤ t .≤ t1
    xunit = (tscale == ms)     ? "ms"      :
            (tscale == second) ? "seconds" :
            (tscale == minute) ? "minutes" : ""
    if :yunit in keys(kw)
        sig = sig / eval(kw[:yunit])
    end
    plot(t[shown], sig[shown]; xlabel, xunit, kw...)
end

plotSTA(
    STA;
    xlabel = "Time after presynaptic spike",
    hylabel = "Spike-triggered average membrane voltage",
    yunit = :mV,
    kw...
) = plotsig(STA, nothing, ms; xlabel, hylabel, yunit, kw...)

timevec(sig) = begin
    T = duration(sig)
    return t = linspace(zero(T), T, length(sig))
end

duration(sig) = length(sig) * Δt


"""
    linspace(start, stop, num; endpoint = false)

Example:

    linspace(0, 10, num=5)  →  [0, 2, 4, 6, 8]

Create a `range` of `num` numbers evenly spaced between `start` and `stop`. The endpoint
`stop` is by default not included. `num` can be specified positionally or as keyword.

Why this function? Because `endpoint = false` functionality is missing in Base.
"""
function linspace(start, stop, num; endpoint = false)
    if endpoint
        return range(start, stop, num)
    else
        return range(start, stop, num + 1)[1:end-1]
    end
end
linspace(start, stop; num, endpoint = false) = linspace(start, stop, num; endpoint)

# - `linspace` functionality will not come to Base [1] (i.e. to `range` aka
#   `start:step:stop`; nor to `LinRange()`, which does not correct for floating point
#   error).
#   I disagree: the vanilla solution is kinda verbose and unclear. And `linspace` is a
#   common need: e.g. to get the correct timepoints for an evenly sampled signal:
#   `timepoints = linspace(0, N/fs, N)`,
#   where `N` is the number of samples in the signal, and `fs` is the sampling rate.
#
# - An alternative to `linspace` is this nice conceptualization [2]:
#   "binspace(left|center|right)"
#   `linspace(endpoint=False)` is like making bins and returning just the left edges.
#
# [1]: https://github.com/JuliaLang/julia/issues/27097
# [2]: https://discourse.julialang.org/t/proposal-of-numpy-like-endpoint-option-for-linspace/6916/13
