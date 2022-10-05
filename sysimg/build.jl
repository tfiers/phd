using Pkg
Pkg.activate("..")

using PackageCompiler
create_sysimage(
    [
        :Revise,
        :IJulia,
        :PyPlot,
        :DataFrames,
        :ComponentArrays,
        :DataStructures,
        :Parameters,
        :StatsBase,
        :JLD2,
    ];
    sysimage_path               = "mysys.dll",
    precompile_execution_file   = "to_precompile.jl",
)

# I should record frozen versions of the above packages here,
# in a file committed to the repo, for reproducibility.
# (The versions of these packages in the root `Manifest.toml` are lies, I think).
