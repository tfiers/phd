"""
Give the user feedback on what is happening during slow operations.
See [`@withfb`](@ref).
"""
module WithFeedback

export @withfb

"""
    @withfb [options] ex

Print something just before and after running the expression.

## Example:

    julia> @withfb using DataFrames
    using DataFrames …

… which becomes, a bit later:

    julia> @withfb using DataFrames
    using DataFrames … ✔ (2.1 s)

The goal is to let the user know what is going on when the program
hangs.

If the expression took more than 0.1 seconds to run, the time taken is
also printed.

By default, the expression itself is printed before execution.
But a custom description of what is happening can be given instead:

    julia> @withfb "Reticulating splines" begin
              s = spline(8)
              r = reticulate(s)
           end;
    Reticulating splines …

(and an instant later:)

    Reticulating splines … ✔

A boolean flag may be used to dynamically turn off the feedback printing
(this can e.g. be useful when passing through a '`verbose`' flag):

    julia> @withfb false reticulate(s);

    julia> @withfb false "Doing work" reticulate(s);

(These print nothing).
"""
macro withfb(ex)
    _withfb(ex)
end

macro withfb(descr, ex)
    _withfb(ex; descr)
end

macro withfb(enabled::Bool, ex)
    _withfb(ex; enabled)
end

macro withfb(enabled::Bool, descr, ex)
    _withfb(ex; descr, enabled)
end

_withfb(ex; descr = nothing, enabled = true) =
    enabled ? _withfb(ex, descr) : esc(ex)


const descriptions::Vector{String} = String[]

_withfb(ex, descr) = begin
    isnothing(descr) && (descr = _stringify(ex))
    if _nested
        quote
            push!(WithFeedback.descriptions, $(esc(descr)))
            join(stdout, WithFeedback.descriptions, " > ")
            println(" … ")
            t0 = time()
            value = $(esc(ex))
            dt = time() - t0
            join(stdout, WithFeedback.descriptions, " > ")
            print(" … ✔")
            if dt ≥ 0.1
                print(" (", round(dt, digits=1), " s)")
            end
            println()
            pop!(WithFeedback.descriptions)
            value
        end
    else
        quote
            print($(esc(descr)), " … ")
            $always_newline && println()
            t0 = time()
            value = $(esc(ex))
            dt = time() - t0
            $always_newline && print($(esc(descr)), " … ")
            print("✔")
            if dt ≥ 0.1
                print(" (", round(dt, digits=1), " s)")
            end
            println()
            value
        end
    end
end

_stringify(ex) = begin
    if ex.head == :block
        ex = deepcopy(ex)
        Base.remove_linenums!(ex)
    end
    return string(ex)
end

always_newline::Bool = false
always_print_newline(val = true) = (global always_newline = val)

_nested::Bool = false
nested(val = true) = (global _nested = val)

end
