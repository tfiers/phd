
"""
Load the pre-computed output of `f` from disk, if available. Else, run `f` and save to disk.

Useful when re-running a cell in a notebook, or restarting a Julia session later.

Other arguments to the function `f`, besides the user parameters, should be derived from
these parameters (i.e, be intermediary data), or should have no influence on the output
(e.g, a 'verbose' flag). Function runs are identified by the parameters and the function
name. The parameters are saved on disk alongside the output, and can be inspected with an
HDF5 viewer.

Usage:

    function slow_func(intermediary_result_x, params::ExperimentParams) … end
    …
    output = cached(slow_func, [x, p])

..with `ExperimentParams <: ParamSet`.
"""
function cached(
    f,
    args::Vector,
    cacheroot = joinpath(homedir(), ".phdcache"),
    subdir = string(nameof(f));
    p::ParamSet = last(args),
)
    dir = joinpath(cacheroot, "datamodel v$datamodel_version", subdir)
    mkpath(dir)
    path = joinpath(dir, cachefilename(p))
    if isfile(path)
        output = load(path, "output")
    else
        output = f(args...)
        @withfb "Saving output at `$path`" (
            jldsave(path; params=p, output)
        )
    end
    return output
end

cachefilename(p::ParamSet) = string(hash(p), base=16) * ".jld2"

"""
The hash of a set of parameters is different if a value is changed, if the struct (the type)
is renamed, and if a field is renamed/added/removed. It does not change when fields are
reordered.
"""
Base.hash(p::ParamSet, h::UInt) = hash_contents(p, h)

# By default, `hash(x)` is based on `objectid(x)` (⇔ `is` aka `===`),
# which is not stable across Julia sessions. This function is.
function hash_contents(x, h::UInt)
    type = typeof(x)
    h = hash(nameof(type), h)
    # Sort field names, so reordering fields doesn't change hash.
    for fieldname in sort!(collect(fieldnames(type)))
        value = getproperty(x, fieldname)
        h = hash(fieldname, h)
        if isstructtype(typeof(value))
            h = hash_contents(value, h)
        else
            h = hash(value, h)
        end
    end
    return h
end
