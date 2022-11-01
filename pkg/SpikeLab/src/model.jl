
"""
    SpikingInput(s, f!)

- `s`:  Vector of spiketimes.
- `f!`: Function of `(vars, params)`, called when a spike of `s` arrives at the target
        neuron.
"""
struct SpikingInput_
    sf::SpikeFeed
    f!::Function
end
SpikingInput_(spikes::Vector{Float64}, f!) = SpikingInput_(SpikeFeed(spikes), f!)
SpikingInput = SpikingInput_

count_new_spikes!(i::SpikingInput, t) = advance_to!(i.sf, t)
Base.length(::SpikingInput) = 1  # To work as part of a ComponentArray.
Base.show(io::IO, si::SpikingInput) = begin
    print(io, SpikingInput, " with ", si.sf, " and ", si.f!)
end


struct Model_
    eval_diffeqs!  ::Function
    has_spiked     ::Function
    on_self_spike! ::Function
    inputs         ::AbstractVector{SpikingInput}
end
Model_(pd::ParsedDiffeqs, args...) = Model_(pd.f!, args...)
Model = Model_


function sim!(m::Model, init, params; duration, Δt)
    N = to_timesteps(duration, Δt)
    # User can provide non-zero start time; but by default t = 0s.
    t = get(init, :t, zero(duration))
    # Initialize buffers:
    vars = CVector{Float64}(; init..., t)
    diff = similar(vars)  # = ∂x/∂t for every x in `vars`
    diff .= 0
    diff.t = 1second/second
    # Where to record to
    v_rec = Vector{Float64}(undef, N)
    spikes = Float64[]
    # The core, the simulation loop
    for i in 1:N
        m.eval_diffeqs!(diff, vars, params)
        vars .+= diff .* Δt  # Euler integration
        @unpack t, v = vars
        v_rec[i] = v
        if m.has_spiked(vars, params)
            push!(spikes, t)
            m.on_self_spike!(vars, params)
        end
        for input in m.inputs  # ..of this neuron
            n = count_new_spikes!(input, t)
            for _ in 1:n
                input.f!(vars, params)
            end
        end
    end
    return v_rec, spikes
end
# Note we're not passing `diff` to the new m. and input. funcs;
# but a model may want that.
