
@precompile_all_calls begin
    p = get_params(N = 10, duration = 100ms)
    s = cached(sim, [p.sim])
    s = cached(sim, [p.sim])
    s = augment(s, p)
end
