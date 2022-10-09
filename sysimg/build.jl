using Pkg
Pkg.activate(".")
pkgs = [
    Symbol(pkg.name)
    for pkg in values(Pkg.dependencies())
    if pkg.is_direct_dep
]

using PackageCompiler
ENV["JULIA_DEBUG"] = PackageCompiler
create_sysimage(
    pkgs;
    sysimage_path              = "mysys.dll",
    precompile_statements_file = ["repl_trace.jl", "ijulia_trace.jl"],
    script                     = "compile_me.jl",
)
