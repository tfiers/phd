"""
Give the user feedback on what is happening during slow operations.
See [`@withfb`](@ref) and [`@withfb_long`](@ref).
"""
module WithFeedback

export @withfb, @withfb_long

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
macro withfb(ex)                       _withfb(ex) end
macro withfb(descr, ex)                _withfb(ex; descr) end
macro withfb(enabled::Bool, ex)        _withfb(ex; enabled) end
macro withfb(enabled::Bool, descr, ex) _withfb(ex; descr, enabled) end

"""
    @withfb_long [options] ex

Same as [`@withfb`](@ref), but allows output to be printed to stdout
during execution of the expression. See the following example:

    julia> @withfb_long "Reticulating" begin
               sleep(1)
               println("Halfway there")
               sleep(1)
           end
    Reticulating …
    Halfway there
    Reticulating ✔ (2.0 s)
"""
macro withfb_long(ex)                       _withfb(ex; long=true) end
macro withfb_long(descr, ex)                _withfb(ex; long=true, descr) end
macro withfb_long(enabled::Bool, ex)        _withfb(ex; long=true, enabled) end
macro withfb_long(enabled::Bool, descr, ex) _withfb(ex; long=true, descr, enabled) end

function _withfb(ex; descr=stringify(ex), enabled=true, long=false)
    if !enabled
        return esc(ex)
    end
    # else:
    return quote
        print($(esc(descr)), " … ")
        if $long
            # Leave space for output printed during execution of the
            # expression
            println()
        end
        flush(stdout)
        t₀ = time()
        # Actually run the expression:
        value = $(esc(ex))
        Δt = time() - t₀
        if $long
            # Repeat description line
            print($(esc(descr)), " ")
        end
        print("✔")
        if Δt ≥ 0.1
            print(" (", round(Δt, digits=1), " s)")
        end
        println()
        flush(stdout)
        value
    end
end

stringify(ex) = begin
    if ex.head == :block
        ex = deepcopy(ex)
        Base.remove_linenums!(ex)
    end
    string(ex)
end

end
