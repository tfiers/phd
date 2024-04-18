

# -----------------------------------------------------------------------------------------

using Logging

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


using WithFeedback
@withfb using StatsBase


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


using Printf


default_float_fmt::String = "%.16g"
# This is approximately (but not entirely) what the default `show(::Float64)` does.

float_fmt::String = default_float_fmt

function set_float_print_fmt(fmt_str)
    float_fmt = fmt_str
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
    oldfmt = float_fmt
    return quote
        set_print_precision($p)
        $(esc(expr))
        set_float_print_fmt($oldfmt)
    end
end


# -----------------------------------------------------------------------------------------


using Base.Iterators


# `zip_longest` is not in Base.Itertools, and not merged yet in IterTools.jl.
# Hence, this.
"""
    ziplongest(iters...; padval = nothing)

`zip` the given iterators after appending `padval` to the shorter ones. The returned
iterator has the same length as the longest iterator in `iters`.

For example, `ziplongest([1,2,3], [1,2])` yields an iterator with the values
`[(1,1), (2,2), (3,nothing)]`.

If any iterators are infinite (*e.g.*: `countfrom`), the returned iterator runs to the
length of the longest finite iterator. If they are all infinite, simply `zip` them.
"""
function ziplongest(iters...; padval = nothing)
    iter_is_finite = applicable.(length, iters)
    if any(iter_is_finite)
        maxfinitelength = maximum(length, iters[collect(iter_is_finite)])
            # Logical index must be an Array, not a Tuple. Hence, `collect`.
        pad(iter) = chain(iter, repeated(padval))
        padded_zip = zip(pad.(iters)...)
        return take(padded_zip, maxfinitelength)
    else
        return zip(iters...)
    end
end

# To be consistent with e.g. `zip`'s interface. Also, `chain` is a more common name for this
# operation.
chain(iters...) = Iterators.flatten(iters)


# -----------------------------------------------------------------------------------------

# Underscores good for URLs of nbs; but they don't linebreak on mobile
nb_title(nb_name) = "# " * replace(nb_name, "__"=>" · ", "_"=>" ")

add_to_toc(nb_name) = begin
    toc_path = "../web/_toc.yml"
    toc = read(toc_path, String)
    line = "    - file: nb/$nb_name\n"
    if occursin(line, toc)
        @info "Notebook already present in TOC"
    else
        marker = "  chapters:\n"
        marker_range = findfirst(marker, toc)
        i = last(marker_range)
        new_toc = toc[1:i] * line * toc[(i+1):end]
        write(toc_path, new_toc)
        @info "Added notebook to `$toc_path`"
    end
end

new_nb(nb_name) = begin
    add_to_toc(nb_name)
    println("Title:\n")
    println(nb_title(nb_name))
    # (We don't auto-copy to `clipboard`: needs InteractiveUtils, and
    #  that takes 0.8 sec to load)
end


# -----------------------------------------------------------------------------------------


"""
    extract(name::Symbol, array)

Create an array of the same shape as the one given, but with just the
values stored under `name` in each element of the given array.

## Example

    julia> arr = [
               (x=3, y=2),
               (x=4, y=1),
           ];

    julia> extract(:x, arr)
    [3, 4]
.
"""
extract(name::Symbol, array) = [getproperty(el, name) for el in array]
    # Unlike in Python, the above comprehension syntax returns an array
    # of the same shape as `array` (e.g. a matrix).


# -----------------------------------------------------------------------------------------


# (Copied from archived VoltoMapSim/misc.jl)
function bin(spiketimes; duration, binsize)
    # `spiketimes` is assumed sorted.
    # `duration` is of the spiketimes signal and co-determines the number of bins.
    num_bins = ceil(Int, duration / binsize)
    spikecounts = fill(0, num_bins)
    # loop counters:
    spike_nr = 1
    bin_end_time = binsize
    for bin in 1:num_bins
        while spiketimes[spike_nr] < bin_end_time
            spikecounts[bin] += 1
            spike_nr += 1
            if spike_nr > length(spiketimes)
                return spikecounts
            end
        end
        bin_end_time += binsize
    end
end
