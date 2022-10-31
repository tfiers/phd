
# Maybe good to make every `::Function` an `::F1`, `Model{F1}`.
# ..or is it ok with this, or with Any.

struct SpikingInput_
    sf::SpikeFeed
    after_spike_arrives_at_output!  #::Function
end
SpikingInput_(spikes::Vector{Float64}, f!) = SpikingInput_(SpikeFeed(spikes), f!)
SpikingInput = SpikingInput_

count_new_spikes!(i::SpikingInput, t) = advance_to!(i.sf, t)
Base.length(::SpikingInput) = 1  # To work as part of a ComponentArray.
Base.show(io::IO, si::SpikingInput) = begin
    print(io, SpikingInput, " with ", si.sf, " and ", si.after_spike_arrives_at_output!)
end

PoissonInput(rate, duration, f!) = SpikingInput(poisson_spikes(rate, duration), f!)


struct Model4
    diffeqs::ParsedDiffeqs
    has_spiked  # ::Function
    on_self_spike!  # ::Function
    inputs::AbstractVector{SpikingInput}
end
Model = Model4


function sim!(m::Model, init, params; duration, Δt)
    N = to_timesteps(duration, Δt)
    # User can provide non-zero start time; but by default t = 0s.
    t = get(init, :t, zero(duration))
    # Initialize buffers:
    vars = CVec{Float64}(; init..., t)
    diff = similar(vars)  # = ∂x/∂t for every x in `vars`
    diff .= 0
    diff.t = 1second/second
    # Where to record to
    v_rec = Vector{Float64}(undef, N)
    spikes = Float64[]
    # Readability alias
    eval_diffeqs! = m.diffeqs.f!
    # The core, the simulation loop
    for i in 1:N
        eval_diffeqs!(diff, vars, params)
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
                # f! = m.on_spike_arrival[input => 1]  # pre => post
                # hm, dict, not type stable right; though m.inputs isn't either.
                f! = input.after_spike_arrives_at_output!
                f!(vars, params)
            end
        end
        # Note we're not passing `diff` to the new m. funcs;
        # but a model may want that.
    end
    return v_rec, spikes
end
