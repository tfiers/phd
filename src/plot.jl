using PyCall, IJulia, FilePaths, Printf
using FilePathsBase: /
using PyPlot: PyPlot as plt, matplotlib as mpl
using Colors, ColorVectorSpace
using Unitful

"""
Beautiful plots by default. To plot on an existing Axes, pass it as the last non-keyword
argument. Keyword arguments that apply to `Line2D`s are passed to `ax.plot`. The rest are
passed to `set`.
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
    ax.plot((args .|> ustrip)...; (plotkw |> convertColorantstoRGBAtuples)...)
    _handle_units!(ax, args)  # Mutating, because `_extract_plotted_data!` peels off `args`
                              # until it's empty.
    set(ax; otherkw...)
    return ax
end

Unitful.ustrip(x) = x

function _handle_units!(ax, plotargs)
    xs, ys = _extract_plotted_data!(plotargs)
    for (arrays, axis) in zip([xs, ys], [ax.xaxis, ax.yaxis])
        for array in arrays
            if has_mixed_dimensions(array)
                i = getindex(plotargs, array)
                error("Elements of argument $i have different dimensions: $array")
            end
        end
        dims_collection = dimension.(arrays)
        if !all(isequal $ first(dims_collection), dims_collection)
            error("Not all $(axis.axis_name)-axis arrays have the same dimensions: $dims_collection.")
        end
        # Store units as a new property on the array object. Note that `units` property
        # already exists.
        axis.unitful_units = unit(eltype(first(arrays)))
    end
end

has_mixed_dimensions(x::AbstractArray{<:Quantity{T,Dims}}) where {T,Dims}  = false
has_mixed_dimensions(x::AbstractArray{<:Quantity})                         = true
has_mixed_dimensions(x::AbstractArray)                                     = false

function _extract_plotted_data!(plotargs)
    # Process `ax.plot`'s vararg by peeling off the front: [x], y, [fmt].
    # Based on https://github.com/matplotlib/matplotlib
    #          /blob/710fce/lib/matplotlib/axes/_base.py#L304-L312
    xs = []
    ys = []
    while !isempty(plotargs)
        if length(plotargs) == 1
            push!(ys, popfirst!(plotargs))
        else
            a = popfirst!(plotargs)
            b = popfirst!(plotargs)
            if b isa AbstractString  # fmt string
                push!(ys, a)
            else
                push!(xs, a)
                push!(ys, b)
                if !isempty(plotargs) && first(plotargs) isa AbstractString
                    popfirst!(plotargs)
                end
            end
        end
    end
    return asarray.(xs), asarray.(ys)
end

asarray(x::Number) = fill(x)  # → zero-dimensional array.
asarray(x::AbstractArray) = x

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
    ax.set(; (axeskw |> convertColorantstoRGBAtuples)...)
    # Various defaults that can't be set through rcParams
    ax.grid(axis = "both", which = "minor", color = "#F4F4F4", linewidth = 0.44)
    for pos in ("left", "right", "bottom", "top")
        ax.spines[pos].set_position(("outward", 10))
        #    `Spine.set_position` resets ticks, and in doing so removes text properties.
        #    Hence these must be called before `_set_ticks` below.
    end
    # Fix sloppy-looking behaviour where only top and left gridlines are visible when
    # gridlines are on the limits.
    ax.yaxis.get_gridlines()[1].set_clip_on(false)  # bottom
    ax.xaxis.get_gridlines()[end].set_clip_on(false)  # right
    # Our opinionated tick defaults. 
    _set_ticks(ax, [xtickstyle, ytickstyle], [xminorticks, yminorticks])
end

function _set_ticks(ax, tickstyles, minorticks_enableds)
    xypairs = zip([ax.xaxis, ax.yaxis], tickstyles, minorticks_enableds)
    for (axis, tickstyle, minorticks_enabled) in xypairs
        if tickstyle == :range
            # Because we set the rcParam `autolimit_mode` to `data`, xlim/ylim == data range.
            a, b = axis.get_view_interval()
            digits = 2
            axis.set_ticks([round(a, RoundDown; digits), round(b, RoundUp; digits)])
            # Turn off all gridlines.
            axis.grid(which = "major", visible = false)
            axis.set_minor_locator(mpl.ticker.NullLocator())
        elseif axis.get_scale() == "log"
            # Mpl default is good, do nothing.
        else
            axis.set_major_locator(mpl.ticker.MaxNLocator(nbins = 7, steps = [1, 2, 5, 10]))
            #   `nbins` should probably depend on figure size, i.e. how large texts are wrt
            #   other graphical elements.
            if minorticks_enabled 
                axis.set_minor_locator(mpl.ticker.AutoMinorLocator())
            else
                axis.set_minor_locator(mpl.ticker.NullLocator())
            end
        end
        # LogLocator places ticks outside limits. So we trim those.
        ticklocs = axis.get_ticklocs()
        a, b = axis.get_view_interval()
        ticklocs = ticklocs[a .≤ ticklocs .≤ b]
        ticklabels = [@sprintf "%.4g" t for t in ticklocs]
        units = hasproperty(axis, :unitful_units) ? axis.unitful_units : units
        if units != unit(1)
            suffix = " " * repr("text/plain", units)
            if axis == ax.xaxis
                prefix_width = round(Int, length(suffix) * 1.6)
                prefix = repeat(" ", prefix_width)  # Imprecise hack to shift label to the
                                                    # right, to get number back under tick.
            else
                prefix = ""
            end
            ticklabels[end] = prefix * ticklabels[end] * suffix
        end
        bbox = Dict(
            :facecolor => mpl.rcParams["figure.facecolor"],
            :edgecolor => "none",
            :pad => 3,  # Relative to fontsize (see "mutation scale").
        ) # Goal: labels stay visible when overlapping with elements of an adjactent Axes.
        axis.set_ticks(ticklocs, ticklabels; bbox)
    end
end

"""
Add a legend to the axes. Change the order of the items in the legend using
`reorder = [plot_order => legend_order,]`. Eg passing `(4 => 1, 1 => 2)` will make the
4th plotted line come 1st in the legend, and the 1st plotted line come 2nd.
"""
function legend(ax; reorder = false, legendkw...)
    handles, labels = ax.get_legend_handles_labels()
    order = collect(1:length(handles))
    if reorder != false
        for (i_old, i_new) in reorder
            insert!(order, i_new, popat!(order, i_old))
        end
    end
    ax.legend([handles[i] for i in order], [labels[i] for i in order]; legendkw...)
end

"""Add a horizontal ylabel."""
function ylabel(ax, text; dx=0, dy=4, ha="left", va="bottom")
    offset = mpl.transforms.ScaledTranslation(dx / 72, dy / 72, ax.figure.dpi_scale_trans)
    fontsize = mpl.rcParams["axes.labelsize"]
    t = ax.text(0, 1, text; transform=ax.transAxes + offset, ha, va, fontsize)
    ax.horizontal_ylabel = t
end

"""
De-emphasises part of an Axes by colouring it light grey.
`part` is one of {:title, :xlabel, :ylabel, :xaxis, :yaxis}.
"""
function deemph(part::Symbol, ax; color = lightgrey)
    color = toRGBAtuple(color)
    if part == :title
        for loc in ("left", "center", "right")
            ax.set_title(ax.get_title(loc); color)
        end
    elseif part == :xlabel
        ax.set_xlabel(ax.get_xlabel(); color)
    elseif part == :ylabel
        ax.set_ylabel(ax.get_ylabel(); color)
        if hasproperty(ax, :horizontal_ylabel)
            ax.horizontal_ylabel.set_color(color)
        end
    elseif part == :xaxis
        ax.spines["top"].set_color(color)
        ax.spines["bottom"].set_color(color)
        ax.tick_params(; axis = "x", which = "both", color, labelcolor = color)
    elseif part == :yaxis
        ax.spines["left"].set_color(color)
        ax.spines["right"].set_color(color)
        ax.tick_params(; axis = "y", which = "both", color, labelcolor = color)
    end
end

const lightgrey = HSL(0, 0, 0.77)

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

convertColorantstoRGBAtuples(dictlike) =
    Dict(k => (v isa Colorant) ? toRGBAtuple(v) : v for (k, v) in dictlike)

"""Convert a Color to an `(r,g,b,a)` tuple ∈ [0,1]⁴, as accepted by Matplotlib."""
toRGBAtuple(c) = toRGBAtuple(RGBA(c))
toRGBAtuple(c::RGBA) = (c.r, c.g, c.b, c.alpha)

mplcolors = C0, C1, C2, C3, C4, C5, C6, C7, C9, C10 = parse.(RGB,
    ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
     "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf" ]
)

"""
Mix a color with white, by some `amount` (`1`: output is pure white, `0`: no change).
Equivalent color output to setting alpha = `amount` on a white background.
"""
lighten(c::C, amount = 0.4) where {C<:Color} = C(mix(RGB(c), RGB(1, 1, 1), amount))

"""
Mix a color with black, by some `amount` (`1`: output is pure black, `0`: no change).
"""
darken(c::C, amount = 0.4) where {C<:Color} = C(mix(RGB(c), RGB(0, 0, 0), amount))

"""Linearly interpolate ("lerp") between `a` (`t = 0`) and `b` (`t = 1`)."""
mix(a, b, t=0.5) = a + t * (b - a)
