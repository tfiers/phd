# For use with PackageCompiler.jl, to generate a "system image", like here:
# https://julialang.github.io/PackageCompiler.jl/stable/examples/plots.html.
#
# The goal is having to wait less long for package imports and first function calls in a
# fresh Julia session.
#
# Commands to run, in the repo root:
#=
using PackageCompiler
pkgs = [:Revise, :PyCall, :IJulia, :PyPlot, :DataFrames, :ComponentArrays]
sysimage_path             = "scripts/mysys.dll"
precompile_execution_file = "scripts/to_precompile.jl"
script                    = "scripts/pyplot_delay_init.jl"
create_sysimage(pkgs; sysimage_path, precompile_execution_file, script)
=#

using PyPlot, DataFrames, ComponentArrays

df = DataFrame([(a=1, b=2), (a=2, b=2)])
cv = ComponentVector(a=3, b=8)

fig, ax = plt.subplots()
ax.plot(df.a, collect(cv))
