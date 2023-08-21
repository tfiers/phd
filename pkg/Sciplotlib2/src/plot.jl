"""
Beautiful plots by default. Keyword arguments that apply to `Line2D`s
are passed to `ax.plot`. The rest are passed to `set`.
"""
function plot(args...; ax = nothing, kw...)
    if :data in keys(kw)
        error("'data' keyword not supported.")
    end
    isnothing(ax) && (ax = plt.gca())
    args = [args...]  # Tuple to Vector (so we can `pop!`)
    kw = Dict{Symbol, Any}(kw)  # to make mutable
    if :clip_on ∉ keys(kw)
        kw[:clip_on] = false
    end
    plotkw = Dict(k => v for (k, v) in kw if hasproperty(mpl.lines.Line2D, "set_$k"))
    otherkw = Dict(k => v for (k, v) in kw if k ∉ keys(plotkw))

    ax.plot((args .|> as_mpl_type)...; (plotkw |> mapvals $ as_mpl_type)...)
    _handle_units!(ax, args)  # Mutating, because `_extract_plotted_data!` peels off `args`
                              # until it's empty.
    set(ax; otherkw...)
    return ax
end


# """
# Create a new figure and axis, and call `ax.hist` and `set`. Distributes the given kwargs
# appropriately between those two. Returns: `(ax, counts, bins, bar_patches)`

# Docstring of plt.hist:

# $(@doc plt.hist)
# """
function hist(args...; kw...)
    inspect = pyimport("inspect")
    hsig = inspect.signature(plt.hist)  # https://docs.python.org/3.5/library/inspect.html#inspect.signature
    signames = collect(hsig.parameters.keys())  # Any[], actually Strings.
    is_hist_kw(name) = (String(name) in signames) || hasproperty(mpl.patches.Patch, "set_$name")
    histkw = Dict(k => v for (k, v) in kw if is_hist_kw(k))
    otherkw = Dict(k => v for (k, v) in kw if k ∉ keys(histkw))
    fig, ax = plt.subplots()
    out = ax.hist((args .|> as_mpl_type)...; (histkw |> mapvals $ as_mpl_type)...)
    set(ax; otherkw...)
    return (ax, out...)
end


function _handle_units!(ax, plotargs)
    if !isdefined(Main, :Unitful)
        return
    end
    xs, ys = _extract_plotted_data!(plotargs)
    for (arrays, axis) in zip([xs, ys], [ax.xaxis, ax.yaxis])
        isempty(arrays) && continue
        for array in arrays
            has_mixed_dimensions(array) &&
                error("Argument has mixed dimensions: $array")
        end
        arrays_dimensions = dimension.(arrays)
        all(isequal(first(arrays_dimensions)), arrays_dimensions) ||
            error("Not all $(axis.axis_name)-axis arrays have the same dimensions: $arrays_dimensions.")
        # Store units as a new property on the array object. Note that `units` property
        # already exists in Mpl.
        axis.unitful_units = unit(eltype(first(arrays)))
    end
end

function _extract_plotted_data!(plotargs)
    # Process `ax.plot`'s vararg by peeling off the front: [x], y, [fmt].
    # Based on https://github.com/matplotlib/matplotlib/blob/710fce/lib/matplotlib/axes/_base.py#L304-L312
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
