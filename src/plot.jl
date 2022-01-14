using PyCall, IJulia, FilePaths
using FilePathsBase: /
using PyPlot: PyPlot as plt, matplotlib as mpl
using Colors, ColorVectorSpace
using Unitful

"""
Beautiful plots by default
Keyword arguments that apply to `Line2D`s are passed to `ax.plot`.
The rest are passed to `set`.
"""
function plot(args...; kw...)
    :data in keys(kw) && error("'data' keyword not supported.")
    args = [args...]  # Tuple to Vector (so we can `pop!`)
    if last(args) isa PyObject && pyisinstance(last(args), plt.matplotlib.axes.Axes)
        ax = pop!(args)
    else
        ax = plt.gca()
    end
    plotkw = Dict(k => v for (k, v) in kw if hasproperty(mpl.lines.Line2D, "set_$k"))
    otherkw = Dict(k => v for (k, v) in kw if k ∉ keys(plotkw))
    plotkw = convertColorstoRGBAtuples(plotkw)
    ax.plot(map(ustrip, args)...; plotkw...)
    _handle_units!(ax, args)  # mutating, cause vararg parser peels off args till empty.
    set(ax; otherkw...)
    return ax
end

convertColorstoRGBAtuples(dictlike) =
    Dict(k => (v isa Colorant) ? toRGBAtuple(v) : v for (k, v) in dictlike)

"""Convert a Color to an `(r,g,b,a)` tuple ∈ [0,1]⁴, as accepted by Matplotlib."""
toRGBAtuple(c) = toRGBAtuple(RGBA(c))
toRGBAtuple(c::RGBA) = (c.r, c.g, c.b, c.alpha)

Unitful.ustrip(x) = x

function _handle_units!(ax, args)
    xs, ys = _parse_plot_varargs!(args)
    for (arrays, x_or_y) in zip([xs, ys], [X(), Y()])
        for array in arrays
            if has_mixed_dimensions(array)
                i = getindex(args, array)
                error("Elements of argument $i have different dimensions: $array")
            end
        end
        dims_collection = map(dimension, arrays)
        if !all(isequal $ first(dims_collection), dims_collection)
            error("Not all $x_or_y arrays have the same dimensions: $dims_collection.")
        end
        # Store units on the array object. `units` property exists already.
        setproperty!(get_axis(ax, x_or_y), :unitful_units, unit(eltype(first(arrays))))
    end
end

has_mixed_dimensions(x::AbstractArray{<:Quantity{T,D}}) where {T,D}  = false
has_mixed_dimensions(x::AbstractArray{<:Quantity})                   = true
has_mixed_dimensions(x::AbstractArray)                               = false

struct X end
struct Y end
get_axis(ax, ::X) = ax.xaxis
get_axis(ax, ::Y) = ax.yaxis
get_lim(ax, ::X) = ax.get_xlim()
get_lim(ax, ::Y) = ax.get_ylim()

function _parse_plot_varargs!(args)
    # Process ax.plot's vararg by peeling off the front: [x], y, [fmt].
    # Based on https://github.com/matplotlib/matplotlib/blob/710fce/lib/matplotlib/axes/_base.py#L304-L312
    xs = []
    ys = []
    while !isempty(args)
        if length(args) == 1
            push!(ys, popfirst!(args))
        else
            a = popfirst!(args)
            b = popfirst!(args)
            if b isa AbstractString  # fmt string
                push!(ys, a)
            else
                push!(xs, a)
                push!(ys, b)
                if !isempty(args) && first(args) isa AbstractString
                    popfirst!(args)
                end
            end
        end
    end
    return xs, ys
end

"""
Set Axes properties and apply beautiful defaults.
Use `xtickstyle` or `ytickstyle` = `:range` to mark the data range (and nothing else).
"""
function set(
    ax;
    xtickstyle = :default,
    ytickstyle = :default,
    xminorticks = true,
    yminorticks = true,
    axeskw...
)
    axeskw = convertColorstoRGBAtuples(axeskw)
    ax.set(; axeskw...)
    _set_ticks(ax, [xtickstyle, ytickstyle], [xminorticks, yminorticks])
    # Various defaults that can't be set through rcParams
    ax.grid(axis = "both", which = "minor", color = "#F4F4F4", linewidth = 0.44)
    ax.spines["left"].set_position(("outward", 10))
    ax.spines["bottom"].set_position(("outward", 10))
end

function _set_ticks(ax, tickstyles, minortickss)
    for (tickstyle, minorticks, x_or_y) in zip(tickstyles, minortickss, [X(), Y()])
        axis = get_axis(ax, x_or_y)
        if tickstyle == :range
            # Because we set rcParam `autolimit_mode` to `data`, xlim/ylim == data range.
            a, b = get_lim(ax, x_or_y)
            digits = 2
            axis.set_ticks([round(a, RoundDown; digits), round(b, RoundUp; digits)])
            axis.grid(which = "major", visible = false)
            axis.set_minor_locator(mpl.ticker.NullLocator())
        elseif axis.get_scale() == "log"
            # Mpl default is good, do nothing.
        else
            axis.set_major_locator(mpl.ticker.MaxNLocator(nbins = 10, steps = [1, 5, 10]))
            minorloc = minorticks ? mpl.ticker.AutoMinorLocator() : mpl.ticker.NullLocator()
            axis.set_minor_locator(minorloc)
        end
        # LogLocator places ticks outside limits. So we trim those.
        ticks = axis.get_ticklocs()
        a, b = get_lim(ax, x_or_y)
        ticks = ticks[a .≤ ticks .≤ b]
        # Manually setting ticks avoids warning 
        # "FixedFormatter should only be used together with FixedLocator"
        axis.set_ticks(ticks)
        labels = [f"{t:.4g}" for t in ticks]
        units = getprop(axis, :unitful_units, unit(1))
        if units != unit(1)
            labels[end] *= " " * repr("text/plain", units)
        end
        axis.set_ticklabels(labels)
    end
end

getprop(obj, sym, default) = hasproperty(obj, sym) ? getproperty(obj, sym) : default

"""
Add a legend to the axes. Change the order of the items in the legend using
`reorder = [plot_order => legend_order,]`. Eg passing `(4 => 1, 1 => 2)` will make the
4th plotted line come 1st in the legend, and the 1st plotted line come 2nd.
"""
function legend(ax; reorder = false)
    handles, labels = ax.get_legend_handles_labels()
    order = [1:length(handles)...]
    if reorder != false
        for (i_old, i_new) in reorder
            insert!(order, i_new, popat!(order, i_old))
        end
    end
    ax.legend([handles[i] for i in order], [labels[i] for i in order])
end

"""Add a horizontal ylabel."""
function ylabel(ax, text; dx=0, dy=6, ha="left", va="bottom")
    offset = mpl.transforms.ScaledTranslation(dx / 72, dy / 72, ax.figure.dpi_scale_trans)
    fontsize = mpl.rcParams["axes.labelsize"]
    ax.text(0, 1, text; transform=ax.transAxes + offset, ha, va, fontsize)
end

# Hi-def ('retina') figures in notebook. [https://github.com/JuliaLang/IJulia.jl/pull/918]
function IJulia.metadata(x::plt.Figure)
    w, h = (x.get_figwidth(), x.get_figheight()) .* x.get_dpi()
    return Dict("image/png" => Dict("width" => 0.5 * w, "height" => 0.5 * h))
end

function savefig(fname; subdir)
    "figdir" in keys(ENV) || error("Set environment variable `figdir`.")
    dir = Path(ENV["figdir"]) / subdir
    exists(dir) || mkpath(dir)
    plt.savefig(string(dir / fname))
end

mplcolors = C0, C1, C2, C3, C4, C5, C6, C7, C9, C10 = parse.(RGB,
    ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
     "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf" ]
)

"""
Mix a color with white, by some `amount` (`1`: output is pure white, `0`: no change).
Equivalent to overlaying the color on a white background with alpha = `amount`.
"""
lighten(c::T, amount = 0.5) where {T<:Color} = T(mix(RGB(c), RGB(1, 1, 1), amount))

"""Linearly interpolate ("lerp") between `a` (`t = 0`) and `b` (`t = 1`)."""
mix(a, b, t=0.5) = a + t * (b - a)
