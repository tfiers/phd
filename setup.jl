# Generate a new `Manifest.toml`, both for the main project and the packages in `pkg/`.
#
# This script is not needed if you `instantiate` from the `Manifest.toml` commited to the
# repository, and don't hack on the packages (i.e. if you just want to reproduce results).
#
# More specifically, run this script to instantiate the Julia projects in this repository
# That is, for each, create a `Manifest.toml` with all its dependencies, and install those,
# with the specification that, for inter-dependencies _within_ this repository, the
# local/development versions of the packages in this repo must be used (`Pkg.develop`).

using Pkg
using TOML

const reporoot = @__DIR__
const pkgdir = joinpath(reporoot, "pkg")

# Project & package directories
const mainproj         = reporoot
const VoltageToMap     = joinpath(pkgdir, "VoltageToMap")
const WhatIsHappening  = joinpath(pkgdir, "WhatIsHappening")
const Sciplotlib       = joinpath(pkgdir, "Sciplotlib")
const MyToolbox        = joinpath(pkgdir, "MyToolbox")

const local_project_dependencies = [
    WhatIsHappening  => [],
    Sciplotlib       => [],
    MyToolbox        => [],
    VoltageToMap     => [MyToolbox, Sciplotlib],
    mainproj         => [WhatIsHappening, MyToolbox, Sciplotlib, VoltageToMap],
                        # We must add indirect local deps as well, for the fix below to work.
]
# Note that the list entries are sorted, with the higher level projects last.

function install_local_projects()
    for (projdir, depdirs) in local_project_dependencies
        cd(projdir)
        rm("Manifest.toml", force = true)  # (`force` is just to not error if not exists).
        Pkg.activate(".")
        @info "Temporarily removing dev dependencies from current `Project.toml`"
        # Without this fix, we'd get "LoadError: expected package {devdep} to be registered"
        # when calling `Pkg.develop` below.
        for depdir in depdirs
            try
                Pkg.rm(pkgname(depdir))
            catch
                # The dependency is already removed from `Project.toml`.
            end
        end
        for depdir in depdirs
            Pkg.develop(path = relpath(depdir))
        end
        Pkg.instantiate()  # Install all dependencies.
    end
end

pkgname(pkgdir) = joinpath(pkgdir, "Project.toml") |> TOML.parsefile |> dict -> dict["name"]


install_local_projects()
println("\n💃 All done")
