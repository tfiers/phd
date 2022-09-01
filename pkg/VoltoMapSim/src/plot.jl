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
    vimsig, presynaptic_spikes, p::ExperimentParams; ax=nothing,
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


function plot_detection_rates(
    rates, p::ExperimentParams; xticklabels, xlabel = "", title = nothing
)
    xs = [1:length(xticklabels);]
    fig, ax = plt.subplots()

    function plotrate(r; kw...)
        if length(size(rates)) == 1  # can't put this check outside, as then "method redefined".
            plot(ax, xs, r, ".-"; clip_on = false, kw...)
        else
            plot_samples_and_means(ax, xs, r; kw...)
        end
    end

    plotrate(extract(:TPR_exc, rates), label="for excitatory inputs", c=color_exc)
    plotrate(extract(:TPR_inh, rates), label="for inhibitory inputs", c=color_inh)
    plotrate(extract(:FPR, rates), label="for unconnected neurons", c=color_unconn)

    set(ax; xtype=:categorical, ytype=:fraction, xticklabels, xlabel=(xlabel, :loc=>"center"))

    if !isnothing(title)
        ax.set_title(title, y = 1.5, loc = "center");
    end

    add_α_line(ax, p.evaluation.α)

    l = ax.legend(title="Detection rate", ncol=2, loc="lower right", bbox_to_anchor=(1.06, 1.1))
    l._legend_box.align = "left"
    return fig, ax
end

"""
Create an array of the same shape as the one given, but with just
the values stored under `name` in each element of the given array.
"""
function extract(name::Symbol, arr #=an array of NamedTuples or structs =#)
    getval(index) = getproperty(arr[index], name)
    out = similar(arr, typeof(getval(firstindex(arr))))
    for index in eachindex(arr)
        out[index] = getval(index)
    end
    return out
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

add_refline(ax, y; c = "black", lw = 1, ls = "dashed", zorder = 3, kw...) =
    ax.axhline(y; c, lw, ls, zorder, kw...)

add_α_line(ax, α; label = f"α = {α:.3G}", kw...) = add_refline(ax, α; label, kw...)


"""
    ydistplot(
        "group1" => [data1...],
        "group2" => [data2...],
        figsize = (4, 2.4),
        xpos = nothing,  # default: 1:num_groups
        ref = nothing,  # calls `add_refline` at the given y.
        set_kw...)

Draws a side-by-side vertical scatterplot and boxplot for each group.
"""
function ydistplot(
    pairs...;
    figsize = (4, 2.4),
    xpos = nothing,
    ref = nothing,
    clip_on = false,
    setkw...
)
    labels, datas = zip(pairs...)  # [(a,b), (c,d), (d,e)] → [(a,c,d), (b,d,e)]
    N = length(labels)
    isnothing(xpos) && (xpos = 1:N)
    fig, ax = plt.subplots(;figsize)
    for (x, ys) in zip(xpos, datas)
        xs = x .- 0.15 .+ 0.1*rand(length(ys))
        ax.plot(xs, ys, "k.", alpha=0.4; clip_on)
        ax.boxplot(
            ys, whis=(5,95), positions=[x+0.1], showfliers=false, showmeans=true,
            medianprops=Dict(:color=>"black"), boxprops=Dict(:clip_on=>clip_on),
            meanprops=Dict(:marker=>"D", :ms=>3, :mfc=>"black", :mec=>"none")
        )
    end
    set(ax; xtype=:categorical, xlim=[0.5, N+0.5], xticks=xpos, xticklabels=labels, setkw...)
    isnothing(ref) || add_refline(ax, ref, zorder=1, c="gray")
    return ax
end
