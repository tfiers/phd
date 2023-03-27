"""
Give the user feedback on what is happening during slow operations.
See [`@withfb`](@ref).
"""
module WithFeedback

export @withfb

"""
    @withfb [descr] ex

Print something just before and after running an expression.

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

By default the expression itself is printed beforehand.
But a custom description of what is happening can be given too:

    julia> @withfb "Reticulating splines" begin
            s = spline(8)
            r = reticulate(s)
        end
    Reticulating splines …

(and an instant later:)

    Reticulating splines … ✔
"""
macro withfb(ex)
    _withfb(ex)
end

macro withfb(descr, ex)
    _withfb(ex, descr)
end

_withfb(ex, descr = nothing) = quote
    if isnothing($descr)
        print($(_stringify(ex)), " … ")
    else
        print($descr, " … ")
    end
    t0 = time()
    $(esc(ex))
    dt = time() - t0
    print("✔")
    if dt ≥ 0.1
        print(" (", round(dt, digits=1), " s)")
    end
    println()
end

_stringify(ex) = begin
    if ex.head == :block
        ex = deepcopy(ex)
        Base.remove_linenums!(ex)
    end
    return string(ex)
end

end
