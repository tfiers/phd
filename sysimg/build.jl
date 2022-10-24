using Pkg
Pkg.activate(".")
pkgs = [
    Symbol(pkg.name)
    for pkg in values(Pkg.dependencies())
    if pkg.is_direct_dep
]
# Problem with including ProfileView (and thus Gtk):
# in notebooks we get regular, repeated error messages (after leaving them open for a while):
# `julia.exe Gdk-CRITICAL [..] gdk_seat_default_remove_tool`

using PackageCompiler
ENV["JULIA_DEBUG"] = PackageCompiler
create_sysimage(
    pkgs;
    sysimage_path              = "mysys.dll",
    precompile_statements_file = "repl_trace.jl",
    script                     = "compile_me.jl",
)
