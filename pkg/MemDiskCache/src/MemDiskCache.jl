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


"""
    CachedFunction(f, prefixdir = nothing, kw_order = Symbol[])

Example usage:

    f(; N, α) = ... # hard work
    cachedir = "2023-10-03__Cool_analysis"
    f_ = CachedFunction(f, cachedir; α = 3)
    f_(N = 1000)

Other keyword arguments (and their defaults):

    - `disk = True`
    - `mem = True`
    - `dir = nothing`. If given, `prefixdir` is ignored.
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




# -------------------------------------------------------------
# Simpler `@cached` interface, for ad-hoc saving of expressions
# -------------------------------------------------------------


dir::Union{String, Nothing} = nothing

set_dir(namespace::String) = (global dir; dir = joinpath(rootdir, namespace))

const memcache = ThreadSafeDict()

"""
    @cached [key] ex

Example:

    MemDiskCache.set_dir("2023-10-03__Cool_analysis")
    for b in 1:3
        x = @cached "sum_\$b" 1+b
    end
"""
macro cached(ex)
    key = string(ex)
    quote
        @cached $key $(esc(ex)) $key
        # Have to pass the description explicitly, otherwise it becomes
        # `Expr(:escape, …)`
    end
end

macro cached(key, ex, descr = nothing)
    quote
        f() = $(esc(ex))
        if isnothing($descr)
            descr = "`" * $(string(ex)) * "` with key `" * string($(esc(key))) * "`"
        else
            descr = $descr
        end
        _cached(f, $(esc(key)), descr)
    end
end

function _cached(f, key, descr)
    if key in keys(memcache)
        @info "Loading `$key` from memory"
        output = memcache[key]
    else
        path = filepath(key)
        if ispath(path)
            @withfb "Loading [$path]" begin
                output = load(path, "output")
            end
        else
            @withfb_long "Running $descr" begin
                output = f()
            end
            mkdir_if_needed(dirname(path))
            @withfb "Saving output at [$path]" begin
                jldsave(path; output)
            end
        end
        memcache[key] = output
    end
    return output
end

filepath(key) = joinpath(dir, key) * ".jld2"

empty_memcache!() = empty!(memcache)
rm_from_memcache!(key) = delete!(memcache, key)
rm_from_disk(key) = rm(filepath(key), force=true)
filelist() = begin
    paths = readdir(dir, join=true)
    filter!(endswith(".jld2"), paths)
end
empty_diskcache() = _rmdir(dir)
open_dir() = DefaultApplication.open(dir)


export @cached


end
