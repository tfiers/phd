cachedir = joinpath(homedir(), ".phdcache")

function cached(f, args::Vector, subdir=string(nameof(f)); params=last(args))
    dir = joinpath(cachedir, subdir)
    mkpath(dir)
    filename = string(hash(params), base=16) * ".jld2"
    path = joinpath(dir, filename)
    if isfile(path)
        @withfb "Loading output from `$path`" output = load(path, "output")
    else
        output = f(args...)
        @withfb "Saving output at `$path`" jldsave(path; params, output)
    end
    return output
end
