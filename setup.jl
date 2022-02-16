# - Instantiate the Julia projects in this repository (i.e. for each, create a `Manifest.toml`
#   with all its dependencies, and install those), with the specification that the local,
#   development versions of the packages present in this repo must be used.
# - Install unregistered versions of dependencies (which cannot be specified in
#   `Package.toml`).

using Pkg, TOML

const reporoot = @__DIR__
const mainpkgdir = joinpath(reporoot, "code")
const devdir = joinpath(mainpkgdir, "dev")  # These are all git submodules (cloned with `--recurse-submodules`).

# Project & package directories
const mainproj         = reporoot
const VoltageToMap     = mainpkgdir
const WhatIsHappening  = joinpath(devdir, "WhatIsHappening")
const Sciplotlib       = joinpath(devdir, "Sciplotlib")
const MyToolbox        = joinpath(devdir, "MyToolbox")

const local_project_dependencies = [
    Sciplotlib     => [],
    MyToolbox      => [Sciplotlib],
    VoltageToMap   => [MyToolbox],
    mainproj       => [
        WhatIsHappening,
        VoltageToMap,
        MyToolbox,
        Sciplotlib,
    ],
]   # Note that these are sorted, with the higher level projects last.

const unregistered_dependencies = [
    (url="https://github.com/fonsp/Suppressor.jl.git", rev="patch-1"),
        # See https://github.com/JuliaIO/Suppressor.jl/pull/37
]

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

function install_unregistered_dependencies()
    for dep in unregistered_dependencies
        Pkg.add(; dep...)
    end
end

install_local_projects()
install_unregistered_dependencies()
println("\n💃 All done")
