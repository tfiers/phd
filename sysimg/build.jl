
using Pkg

Pkg.activate(".")

using PackageCompiler

create_sysimage(
    ["PythonPlot"],
    sysimage_path = "mysys.dll",
    precompile_execution_file = "compile_me.jl",
    # Note: not `script`.
)
