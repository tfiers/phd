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
