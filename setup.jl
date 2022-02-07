# Instantiate the Julia project and packages in this repository (i.e. for each, create a
# `Manifest.toml` with all dependencies, and install those), with the specification that the
# local, development versions of the packages present in this repo must be used.

using Pkg, TOML

reporoot = @__DIR__
mainpkgdir = joinpath(reporoot, "julia-codebase")
devdir = joinpath(mainpkgdir, "dev")  # These are all git submodules (cloned with `--recurse-submodules`).

# Project & package directories
#
nb_init           = reporoot  # `notebooks/nb_init.jl` uses the `Project.toml` and `Manifest.toml` of the root dir.
VoltageToMap      = mainpkgdir
Unitful           = joinpath(devdir, "Unitful")
WhatIsHappening_  = joinpath(devdir, "WhatIsHappening")  # `WhatIsHappening` name already taken, in my `startup.jl`.
Distributions     = joinpath(devdir, "Distributions")
Sciplotlib        = joinpath(devdir, "Sciplotlib")
MyToolbox         = joinpath(devdir, "MyToolbox")

dev_dependencies = (
    Distributions  => [Unitful],
    Sciplotlib     => [Unitful],
    MyToolbox      => [Sciplotlib, Unitful],
    VoltageToMap   => [MyToolbox, Distributions, Unitful],
    nb_init        => [WhatIsHappening_, VoltageToMap, MyToolbox, Sciplotlib, Distributions, Unitful],
)
# Note that these are sorted, with the higher levels last.

function apply_project_fix(deps)
    @info "Temporarily removing dev dependencies from main `Project.toml`"
    # Without this fix, we get "LoadError: expected package {devdep} to be registered".
    # This fix is only necessary for the (main) project, not the packages. Pkg.jl bug?
    for depdir in deps
        pkgname = joinpath(depdir, "Project.toml") |> TOML.parsefile |> d -> d["name"]
        try Pkg.rm(pkgname)
        catch # The dependency is already removed from `Project.toml`.
        end
    end
end

for (dir, deps) in dev_dependencies
    cd(dir)
    rm("Manifest.toml", force=true)
    Pkg.activate(".")
    dir == reporoot && apply_project_fix(deps)
    for depdir in deps
        Pkg.develop(path=relpath(depdir))
    end
    Pkg.instantiate()
end

println("\n💃 All done")
