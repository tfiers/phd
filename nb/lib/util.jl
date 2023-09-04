

# -----------------------------------------------------------------------------------------


"""No more red backgrounds in IJulia output. Also, `@info` will be less verbose."""
function prettify_logging_in_IJulia()
    global_logger(get_interactive_logger())
    redirect_stderr(stdout)
end

# The default logger in IJulia is a `SimpleLogger(stderr)`, which prints source information
# not only for `@warn` but also for `@info`. The default logger in the Julia REPL is a
# `ConsoleLogger(stdout)`, which is smarter.
get_interactive_logger() = ConsoleLogger(stdout)
    # `stdout` is a writeable global (e.g. IJulia modifies it). Hence this is a getter and
    # not a constant.


# -----------------------------------------------------------------------------------------


"""
showsome(x; kw...)
showsome(io::IO, x; kw...)

Print an overview of the vector `x`, by showing example entries. The first and last
entries are shown, and a few randomly sampled entries in between.

Keyword arguments `nfirst`, `nlast`, and `nsample` determine how many samples to print at
the beginning, end, and in between. Each defaults to `2`. `io` is `stdout` if not specified.
"""
showsome(x;         nfirst = 2, nlast = 2, nsample = 2) = showsome(stdout, x; nfirst, nlast, nsample)
showsome(io::IO, x; nfirst = 2, nlast = 2, nsample = 2) = begin
    if length(x) ≤ nfirst + nlast + nsample
        nfirst = length(x)
        nlast, nsample = 0, 0
    end
    println(io, summary(x), ":")  # eg "640-element Vector{String}:"
    all_i = 1:length(x)  # Always `Int`s
    all_ix = eachindex(x)  # Generally same, but can also be `CartesianIndex`, `Symbol`, …
    shown_i = @views vcat(
        all_i[1:nfirst],
        all_i[nfirst+1:end-nlast] |> (is -> sample(is, nsample)) |> sort,
        all_i[end-nlast+1:end],
    )
    shown_ix = all_ix[shown_i]
    padlen = 1 + maximum(length, string.(shown_ix))
        # The initial extra `1` is the one-space indent of vanilla Vector printing.
    printrow(ix) = println(io, lpad(ix, padlen), ": ", repr(x[ix]))
    printdots() = println(io, lpad("⋮", padlen))
    first(shown_i) == first(all_i) || printdots()
    for (i, inext) in ziplongest(shown_i, shown_i[2:end])
        printrow(all_ix[i])
        isnothing(inext) || inext == i + 1 || printdots()
    end
    last(shown_i) == last(all_i) || printdots()
    return nothing
end


# -----------------------------------------------------------------------------------------


const default_float_fmt = "%.16g"
# This is approximately (but not entirely) what the default `show(::Float64)` does.

const float_fmt = Ref(default_float_fmt)

function set_float_print_fmt(fmt_str)
    float_fmt[] = fmt_str
    fmt = Printf.Format(fmt_str)
    Main.eval( :( Base.show(io::IO, x::Float64) = Printf.format(io, $fmt, x) ) )
    return nothing
end
# We don't specify `::MIME"text/plain"` in `show`, so that we also get compact floats in
# composite types (like when displaying a NamedTuple). Disadvantage is that we cannot use
# `show(x)` to see full float repr anymore. (One solution is to fmt with many digits).

set_print_precision(digits::Int = 3)         = set_float_print_fmt("%.$(digits)G")
set_print_precision(digits_and_type::String) = set_float_print_fmt("%.$(digits_and_type)")

# Something like `with_print_precision(3) do … end` wouldn't work:
# it can't be a function, must be a macro.
macro with_print_precision(p, expr)
    oldfmt = float_fmt[]
    return quote
        set_print_precision($p)
        $(esc(expr))
        set_float_print_fmt($oldfmt)
    end
end
