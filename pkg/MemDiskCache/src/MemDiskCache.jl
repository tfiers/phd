module MemDiskCache

using ThreadSafeDicts
using JLD2
using DefaultApplication
using WithFeedback

"""
The contents of the files on disk can be inspected using
`f = jldopen(filelist(my_cached_func)[1])` (shows groupnames),
and then `f["name"]`. Finally, `close(f)`
"""


struct CachedFunction
    f
    memcache     ::ThreadSafeDict
    disk         ::Bool
    mem          ::Bool
    dir          ::String
    kw_order     ::Vector{Symbol}
    default_kw
end
CachedFunction(
    f,
    prefixdir = nothing,
    kw_order = Symbol[],
    ;
    dir = nothing,
    disk = true,
    mem = true,
    default_f_kw...
) =
    CachedFunction(
        f,
        ThreadSafeDict(),
        disk,
        mem,
        fdir(f, prefixdir, dir),
        kw_order,
        default_f_kw
    )

fdir(f, prefixdir, dir) = begin
    if !isnothing(prefixdir)
        dir = joinpath(prefixdir, string(nameof(f)))
    elseif isnothing(dir)  # && isnothing(prefixdir)
        error("At least one dir must be given")
    end
    to_abs_dir(dir)
end

to_abs_dir(dir) = begin
    if !isabspath(dir)
        dir = joinpath(rootdir, dir)
    end
    dir
end

const rootdir = joinpath(homedir(), ".julia", "MemDiskCache.jl")


# Functor (calling the object itself)
(c::CachedFunction)(; kw...) = begin
    fkw = full_kw(c; kw...)
    if fkw in keys(c.memcache)
        # @info "Found $fkw in memory"
        output = c.memcache[fkw]
    else
        fp = filepath(c, fkw)
        if ispath(fp)
            @withfb "Loading [$fp]" begin
                output = load(fp, "output")
            end
        else
            @withfb_long "Running `$(c.f)` for $fkw" begin
                output = c.f(; fkw...)
            end
            if c.disk
                mkdir_if_needed(dirname(fp))
                @withfb "Saving output at [$fp]" begin
                    jldsave(fp; output)
                end
            end
        end
        if c.mem
            c.memcache[fkw] = output
        end
    end
    return output
end

mkdir_if_needed(dir) = begin
    if !isdir(dir)
        @info "Creating [$dir]"
        mkpath(dir)
    end
    return dir
end

filepath(c::CachedFunction; kw...) = filepath(c, full_kw(c; kw...))
filepath(c::CachedFunction, full_kw) = joinpath(c.dir, filename(full_kw))
filename(full_kw) = to_string(full_kw) * ".jld2"

"""
Joins the given keyword arguments with the default keyword args for this
cache, and returns a NamedTuple, sorted alphabetically by key.
(Actually: taking the user specified order, if any; and sorting the rest
alphabetically, after that).
"""
full_kw(c::CachedFunction; kw...) = begin
    out = Dict{Symbol, Any}()
    for (k, v) in c.default_kw
        out[k] = v
    end
    for (k, v) in kw
        out[k] = v
    end
    # Select names from the user-specified order that
    # we actually have
    names = [k for k in c.kw_order if k ∈ keys(out)]
    # Now collect the remaining `out` keys (not specified in user order)
    remaining = [k for k in keys(out) if k ∉ names]
    append!(names, sort!(remaining))
    return (; (k => out[k] for k in names)...)
end

to_string(full_kw::NamedTuple) = begin
    parts = ("$(k)=$v" for (k,v) in pairs(full_kw))
    "_  " * join(parts, "  ") * "  _"
end

empty_memcache!(c::CachedFunction) = empty!(c.memcache)

rm_from_memcache!(c::CachedFunction; kw...) =
    delete!(c.memcache, full_kw(c; kw...))

rm_from_disk(c::CachedFunction; kw...) =
    rm(filepath(c; kw...), force=true)

filelist(c::CachedFunction) = begin
    paths = readdir(c.dir, join=true)
    filter!(endswith(".jld2"), paths)
end

_rmdir(d) = begin
    rm(d, recursive=true, force=true)
    @info "Emptied and removed [$d]"
end

empty_diskcache(c::CachedFunction) = _rmdir(c.dir)

open_dir(c::CachedFunction) = DefaultApplication.open(c.dir)


export CachedFunction
export empty_memcache!, rm_from_memcache!
export filelist, empty_diskcache, rm_from_disk
export open_dir
export jldopen  # = a reexport

end
