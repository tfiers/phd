module MemDiskCache

using ThreadSafeDicts
using JLD2
using DefaultApplication

"""
The contents of the files on disk can be inspected using
`f = jldopen(filelist(my_cached_func)[1])` (shows groupnames),
and then `f["name"]`. Finally, `close(f)`
"""


struct CachedFunction
    f
    memcache
    disk
    dir
    default_kw
end
CachedFunction(f; disk = true, dir = fdir(f), default_kw...) =
    CachedFunction(f, ThreadSafeDict(), disk, dir, default_kw)

fdir(f) = joinpath(get_cachedir(), string(nameof(f)))

# Functor (calling the object itself)
(c::CachedFunction)(; kw...) = begin
    fkw = full_kw(c; kw...)
    if fkw in keys(c.memcache)
        @info "Found $fkw in memory"
        output = c.memcache[fkw]
    else
        fp = filepath(c, fkw)
        if ispath(fp)
            @info "Loading [$fp]"
            output = load(fp, "output")
        else
            @info "Running `$(c.f)` for $fkw"
            output = c.f(; fkw...)
            if c.disk
                mkdir_if_needed(dirname(fp))
                @info "Saving output at [$fp]"
                jldsave(fp; output)
            end
        end
        c.memcache[fkw] = output
    end
    return output
end

const default_basedir = joinpath(homedir(), ".julia", "datacache")
const default_cachedir = joinpath(default_basedir, "global")
const cachedir = Ref(default_cachedir)

get_cachedir() = cachedir[]
set_cachedir(dir) = begin
    if !isabspath(dir)
        dir = joinpath(default_basedir, dir)
    end
    cachedir[] = dir
    mkdir_if_needed(dir)
    return dir
end

mkdir_if_needed(dir) = begin
    if !isdir(dir)
        @info "Creating [$dir]"
        mkpath(dir)
    end
    return dir
end

filepath(c::CachedFunction, full_kw) = joinpath(c.dir, filename(full_kw))
filename(full_kw) = to_string(full_kw) * ".jld2"

"""
Joins the given keyword arguments with the default keyword args for this
cache, and returns a NamedTuple, sorted alphabetically by key.
"""
full_kw(c::CachedFunction; kw...) = begin
    out = Dict{Symbol, Any}()
    for (k, v) in c.default_kw
        out[k] = v
    end
    for (k, v) in kw
        out[k] = v
    end
    sorted_names = sort!(collect(keys(out)))
    return (; (k => out[k] for k in sorted_names)...)
end

to_string(full_kw::NamedTuple) = begin
    parts = ("$(k)=$v" for (k,v) in pairs(full_kw))
    join(parts, "  ") * " "
end

empty_memcache!(c::CachedFunction) = empty!(c.memcache)

rm_from_memcache!(c::CachedFunction; kw...) =
    delete!(c.memcache, full_kw(c; kw...))

filelist(c::CachedFunction) = begin
    paths = readdir(c.dir, join=true)
    filter!(endswith(".jld2"), paths)
end

rmdir(d) = begin
    rm(d, recursive=true, force=true)
    @info "Emptied and removed [$d]"
end

empty_diskcache!(c::CachedFunction) = rmdir(c.dir)
empty_cachedir() = rmdir(get_cachedir())

open_cachedir() = DefaultApplication.open(get_cachedir())
open_dir(c::CachedFunction) = DefaultApplication.open(c.dir)


export CachedFunction
export set_cachedir, get_cachedir
export empty_memcache!, rm_from_memcache!
export filelist, empty_diskcache!, empty_cachedir
export open_cachedir, open_dir
export jldopen  # = a reexport

end
