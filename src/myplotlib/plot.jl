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
#   Note: cannot place this definition in `plot`.

function _handle_units!(ax, plotargs)
    xs, ys = _extract_plotted_data!(plotargs)
    for (arrays, axis) in zip([xs, ys], [ax.xaxis, ax.yaxis])
        for array in arrays
            has_mixed_dimensions(array) && 
                error("Argument has mixed dimensions: $array")
        end
        dims_collection = dimension.(arrays)
        all(isequal(first(dims_collection)), dims_collection) ||
            error("Not all $(axis.axis_name)-axis arrays have the same dimensions: $dims_collection.")
        # Store units as a new property on the array object. Note that `units` property
        # already exists in Mpl.
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
