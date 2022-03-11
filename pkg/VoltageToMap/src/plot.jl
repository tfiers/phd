@reexport using Sciplotlib

""" tzoom = [200ms, 600ms] e.g. """
function plotsig(t, sig, tzoom = nothing; ax = nothing, clip_on=false, kw...)
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
