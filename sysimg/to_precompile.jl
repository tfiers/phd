# For use with PackageCompiler.jl, to generate a custom "system image", like here:
# https://julialang.github.io/PackageCompiler.jl/stable/examples/plots.html.
#
# The goal is having to wait less long for package imports and first function calls in a
# fresh Julia session.
#
# Commands to run, in the repo root:
#=
using PackageCompiler
pkgs = [:Revise, :PyCall, :IJulia, :PyPlot, :DataFrames, :ComponentArrays]
sysimage_path             = "sysimg/mysys.dll"
precompile_execution_file = "sysimg/to_precompile.jl"
script                    = "sysimg/pyplot_delay_init.jl"
create_sysimage(pkgs; sysimage_path, precompile_execution_file, script)
=#
# To use this system image:
# - On the command line: `julia --sysimg=sysimg/mysis.dll`
# - As a 'kernel' in Jupyter:
#     https://julialang.github.io/IJulia.jl/stable/manual/installation/#Installing-additional-Julia-kernels
#   Make sure to also add the flag "--project=@.".
#   For me, the generated kernel definition file is located at:
#     C:\Users\tfiers\AppData\Roaming\jupyter\kernels\julia-preloaded-1.7\kernel.json

using PyPlot, DataFrames, ComponentArrays

df = DataFrame([(a=1, b=2), (a=2, b=2)])
cv = ComponentVector(a=3, b=8)

fig, ax = plt.subplots()
ax.plot(df.a, collect(cv))
