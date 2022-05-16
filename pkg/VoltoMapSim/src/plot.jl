@reexport using Sciplotlib

color_exc = C0
color_inh = C1
color_unconn = Gray(0.3)


""" tzoom = [200ms, 600ms] e.g. """
function plotsig(t, sig, tzoom=nothing; ax=nothing, clip_on=false, kw...)
    isnothing(tzoom) && (tzoom = [t[1], t[end]])
    t0, t1 = tzoom
    shown = t0 .≤ t .≤ t1
    if isnothing(ax)
        plot(t[shown], sig[shown]; clip_on, kw...)
    else
        plot(t[shown], sig[shown], ax; clip_on, kw...)
    end
end

function plotSTA(vimsig, presynaptic_spikes, p::ExperimentParams)
    Δt = p.sim.Δt
    @unpack STA_window_length = p.conntest
    win_size = round(Int, STA_window_length / Δt)
    t_win = linspace(zero(STA_window_length), STA_window_length, win_size)
    STA = calc_STA(vimsig, presynaptic_spikes, p)
    plot(t_win / ms, STA / mV)
end

"""
Rows of `data` correspond to `x` locations. Columns are samples (e.g. RNG seeds).
"""
function plot_samples_and_means(
    x::Vector,
    data::Matrix,
    ax;
    label=nothing,
    c=Gray(0.2),
    clip_on=false,
    kw...
)
    plot(x, mean(data, dims=2), ".-", ax; label, c, clip_on, kw...)
    plot(x, data, ".", ax; alpha=0.5, c, clip_on, kw...)
end

add_α_line(ax, α, c="black", lw=1, ls="dashed", label=f"α = {α:.3G}", zorder=3) =
    ax.axhline(α; c, lw, ls, label, zorder)
