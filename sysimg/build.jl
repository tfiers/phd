using PackageCompiler

create_sysimage(
    [
        :Revise,
        :PyCall,
        :IJulia,
        :PyPlot,
        :DataFrames,
        :ComponentArrays,
    ];
    sysimage_path               = "sysimg/mysys.dll",
    precompile_execution_file   = "sysimg/to_precompile.jl",
    script                      = "sysimg/pyplot_delay_init.jl",
)
