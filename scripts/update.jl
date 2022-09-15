about = """
Usage:

    julia update.jl [--all]

Based on the dependencies listed in both `Project.toml` and in this script, generates a new
`Manifest.toml` with up-to-date versions of all dependencies, and installs those. [1]

If the `--all` flag is given, does the same for the projects in `pkg/` as well.

This script is not needed if you `instantiate` from the `Manifest.toml` commited to the
repository (see ReadMe) -- i.e. if you want to reproduce results with the exact package
versions used to generate the results.

[1] More precisely, this script `instantiate`s the Julia projects in this repository, with
    the specification that, for inter-dependencies _within_ this repository (namely the
    packages in `pkg/`), the local aka development versions of these packages must be used
    (`Pkg.develop`).
"""

using Pkg
using TOML

const reporoot = @__DIR__
const pkgdir = joinpath(reporoot, "pkg")

# Project & package directories
const mainproj         = reporoot
const VoltoMapSim      = joinpath(pkgdir, "VoltoMapSim")
const Sciplotlib       = joinpath(pkgdir, "Sciplotlib")
const MyToolbox        = joinpath(pkgdir, "MyToolbox")

const localdeps = [
    Sciplotlib       => [],
    MyToolbox        => [],
    VoltoMapSim      => [MyToolbox, Sciplotlib],
    mainproj         => [MyToolbox, Sciplotlib, VoltoMapSim],
                        # We must add indirect local deps as well, for the fix below to work.
                        # (could make recursive collecting function)
]
# Note that the list entries are sorted, with the higher level projects last.

pkgname(pkgdir) = joinpath(pkgdir, "Project.toml") |> TOML.parsefile |> dict -> dict["name"]

function install(projdir, depdirs)
    cd(projdir)
    rm("Manifest.toml", force = true)  # (`force` is just to not error if not exists).
    Pkg.activate(".")
    # Without the following fix, we'd get "LoadError: expected package {devdep} to be
    # registered" when calling `Pkg.develop` below.
    @info "Temporarily removing dev dependencies from current `Project.toml`"
    for depdir in depdirs
        try Pkg.rm(pkgname(depdir))
        catch # The dependency is already removed from `Project.toml`.
        end
    end
    for depdir in depdirs
        Pkg.develop(path = relpath(depdir))
    end
    Pkg.instantiate()  # Install all dependencies.
end

done() = println("\n💃 All done")

if isempty(ARGS)  # Install just the main project
    depdirs = Dict(localdeps)[mainproj]
    install(mainproj, depdirs)
    done()
elseif ARGS[1] == "--all"
    for (projdir, depdirs) in localdeps
        install(projdir, depdirs)
    end
    done()
else
    println(about)
end
