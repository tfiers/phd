using Pkg

Pkg.activate("..")

using IJulia

path = abspath(joinpath(@__DIR__, "mysys.dll"))

IJulia.installkernel(
    "Julia-mysys",
    "--project=@.",
    "--sysimage=$path",
)
