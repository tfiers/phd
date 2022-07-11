@reexport using Sciplotlib

const color_exc = C0
const color_inh = C1
const color_unconn = Gray(0.3)


function plotsig(t, sig; tlim=nothing, ax=nothing, clip_on=false, kw...)
    # tlim = [200ms, 600ms] e.g
    isnothing(tlim) && (tlim = [t[1], t[end]])
    t0, t1 = tlim
    shown = t0 .≤ t .≤ t1
    if isnothing(ax)
        plot(t[shown], sig[shown]; clip_on, kw...)
    else
        plot(ax, t[shown], sig[shown]; clip_on, kw...)
    end
end

function plotSTA(
    vimsig, presynaptic_spikes, p::VoltoMapSim.ExperimentParams; ax=nothing,
    xlabel="Time after spike (ms)", hylabel="Spike-triggered average (mV)", kw...
)
    @unpack Δt = p.sim.general
    @unpack STA_window_length = p.conntest
    win_size = round(Int, STA_window_length / Δt)
    t_win = linspace(zero(STA_window_length), STA_window_length, win_size)
    STA = calc_STA(vimsig, presynaptic_spikes, p)
    if isnothing(ax)
        fig, ax = plt.subplots()
    end
    plot(ax, t_win / ms, STA / mV)
    set(ax; xlabel, hylabel, xlim=(0, STA_window_length / ms), kw...)
    return ax
end

"""
Rows of `data` correspond to `x` locations. Columns are samples (e.g. RNG seeds).
"""
function plot_samples_and_means(
    x::Vector, data::Matrix, ax;
    label=nothing, c=Gray(0.2), clip_on=false, kw...
)
    plot(x, mean(data, dims=2), ".-", ax; label, c, clip_on, kw...)
    plot(x, data, ".", ax; alpha=0.5, c, clip_on, kw...)
end

add_α_line(ax, α, c="black", lw=1, ls="dashed", label=f"α = {α:.3G}", zorder=3) =
    ax.axhline(α; c, lw, ls, label, zorder)


function rasterplot(spiketimes; tlim, ms = 1)
    # `spiketimes` is sim_state.rec.spike_times: a CVec with groups .exc and .inh, and each
    # element a vector of floats: the spike times of one neuron.
    t0, t1 = tlim
    # We make a flat list of all spiketimes, so we need to call the plot command only once
    # (and not for every neuron, which is quite slow).
    all_spiketimes = []
    neuron_nrs = []  # repeated neuron IDs/numbers: [1,1,1,1,2,2,2,3,3,3,3,3,…]
    for n in eachindex(spiketimes)
        spikes = spiketimes[n]
        i0 = findfirst(t -> t ≥ t0, spikes)  # isnothing if only spikes before t0
        i1 = findlast(t -> t ≤ t1, spikes)  # isnothing if only spikes after t1
        if isnothing(i0) || isnothing(i1)
            continue
        end
        spikes_in_view = spikes[i0:i1]
        push!(all_spiketimes, spikes_in_view)
        push!(neuron_nrs, fill(n, length(spikes_in_view)))
    end
    fig, ax = plt.subplots(figsize=(4.6, 2.3))
    plot(ax, vcat(all_spiketimes...), vcat(neuron_nrs...), "k.", clip_on=false,
            ylim=(0, length(spiketimes)), xlim=(t0, t1); ms);
    N_exc = length(spiketimes.exc)
    N_inh = length(spiketimes.inh)
    set(ax, xlabel="Time (s)", ylabel="Neuron number",
        hylabel="Spike times of $N_exc excitatory, $N_inh inhibitory neurons")
    return ax
end

function histplot_fr(spike_rates)
    fig, ax = plt.subplots()
    M = ceil(Int, maximum(spike_rates))
    bins = 0:0.1:M
    xlim = (0, M)
    ax.hist(spike_rates.exc; bins, label="Excitatory neurons")
    ax.hist(spike_rates.inh; bins, label="Inhibitory neurons")
    ax.legend()
    set(ax, xlabel="Spike rate (Hz)", ylabel="Number of neurons in bin"; xlim);
    return ax
end
