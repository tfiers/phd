# We do not use this at the moment.
# The code in this package (e.g. `augment`) is not type stable, and can not be precompiled.
# The below has thus no effect (except for precompiling some JLD2 methods).

using SnoopPrecompile

@precompile_all_calls begin
    @info "precompiling sim"
    p = get_params(N = 10, duration = 10ms)
    empty_cache(sim, [p.sim])
    s = cached(sim, [p.sim])
    s = cached(sim, [p.sim])
    s = augment(s, p)
end
