# The below actions are necessary to install the project when not using the `Manifest.toml`
# committed to the repository (see ReadMe).
# (The below actions cannot be recorded in `Project.toml`).

using Pkg

Pkg.activate(".")

local_pkgs = [
    "Sciplotlib",  # Depends on MyToolbox
    "MyToolbox",
    "SpikeWorks",
    "ConnectionTests",  # Depends on ConnTestEval, WithFeedback
    "ConnTestEval",
    "MemDiskCache",  # Depends on WithFeedback
    "DistributedLoopMonitor",
    "WithFeedback",
]
# This list is sorted so the more top-level packages occur earlier.

for name in local_pkgs
    # Without these temporarily removals, we'd get "LoadError: expected package {local_dep}
    # to be registered" when calling `develop` below.
    Pkg.rm(name)
end
for name in reverse(local_pkgs)  # Install more low-level packages first.
    Pkg.develop(path = joinpath("pkg", name))
end


Pkg.add(url = "https://github.com/JuliaNLSolvers/LsqFit.jl", rev = "e9b9e8732")
# Unreleased version, to get https://github.com/JuliaNLSolvers/LsqFit.jl/pull/222
