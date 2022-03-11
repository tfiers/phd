# Generate a new `Manifest.toml`, both for the main project, and the packages in `pkg/`.
# This script is not needed if you install from the `Manifest.toml` commited to the
# repository and don't hack on the packages (i.e. if you just want to reproduce results).
#
# More specifically, run this script to instantiate the Julia projects in this repository
# (i.e. for each, create a `Manifest.toml` with all its dependencies, and install those),
# with the specification that, for inter-dependencies _within_ this project, the
# local/development versions of the packages present in this repo must be used
# (`Pkg.develop`).

using Pkg, TOML

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
    VoltageToMap     => [MyToolbox],
    mainproj         => [WhatIsHappening, MyToolbox, Sciplotlib, VoltageToMap],
                        # gotta add MyTB as well, for the fix below to work.
]
# Note that these are sorted, with the higher level projects last.

function install_local_projects()
    for (projdir, depdirs) in local_project_dependencies
        cd(projdir)
        rm("Manifest.toml", force=true)
        Pkg.activate(".")
        projdir == mainproj && apply_expected_registered_fix(depdirs)
        for depdir in depdirs
            Pkg.develop(path=relpath(depdir))
        end
        Pkg.instantiate()
    end
end

function apply_expected_registered_fix(depdirs)
    @info "Temporarily removing dev dependencies from main `Project.toml`"
    # Without this fix, we get "LoadError: expected package {devdep} to be registered".
    # This fix is only necessary for the (main) project, not the packages. Pkg.jl bug?
    for depdir in depdirs
        pkgname = joinpath(depdir, "Project.toml") |> TOML.parsefile |> d -> d["name"]
        try Pkg.rm(pkgname)
        catch # The dependency is already removed from `Project.toml`.
        end
    end
end

install_local_projects()
println("\n💃 All done")
