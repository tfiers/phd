"""
    SpikeFeed(sorted_spike_times)

Keeps track of how many spikes have been processed already.

Used with [`advance_to!`](@ref) in a simulation loop, to check whether an input spike train
has spiked in the current timestep (and if so, how many times).

# Usage

    julia> x = [1.0, 2.0, 4.0];  # The provided spike times must already be sorted

    julia> sf = SpikeFeed(x)
    SpikeFeed [0/3] (next: 1.0)  # [0/3] is the [seen/total] number of spikes

    julia> advance_to!(sf, 3.0)  # Provide the current time
    2                            # Get the number of new spikes

    julia> advance_to!(sf, 3.0)
    0

    julia> sf
    SpikeFeed [2/3] (next: 4.0)

    julia> advance_to!(sf, 4.0)  # We advance up to *and including* the given time
    1

    julia> sf
    SpikeFeed [3/3] (exhausted)

~
"""
struct SpikeFeed
    spikes  ::Vector{Float64}  # Spike times, assumed sorted
    next    ::Ref{Int}         # Index of next unseen spike
end
SpikeFeed(spikes) = SpikeFeed(spikes, Ref(1))

time_of_next(sf::SpikeFeed) = sf.spikes[sf.next[]]
is_exhausted(sf::SpikeFeed) = sf.next[] > length(sf.spikes); sort!()

"""
    n = advance_to!(sf::SpikeFeed, t)

Count the number of spikes `n` in the time interval `(tₚ, t]`,
where `tₚ` is the time `t` this method was last called with.
(On the first call, count all spikes before `t`).

In a simulation loop, `t - tₚ` will be the timestep, `Δt`,
and this method will count the number of spikes in the current timestep.

See [`SpikeFeed`](@ref) for an example.
"""
advance_to!(sf::SpikeFeed, t) = begin
    n = 0
    while !is_exhausted(sf) && (@inbounds time_of_next(sf) ≤ t)
        n += 1
        sf.next[] += 1
    end
    return n
end


num_processed(sf::SpikeFeed) = sf.next[] - 1
num_total(sf::SpikeFeed) = length(sf.spikes)

Base.show(io::IO, ::MIME"text/plain", sf::SpikeFeed) = begin
    print(io, SpikeFeed, " [", num_processed(sf), "/", num_total(sf), "] ")
    if is_exhausted(sf)
        println(io, "(exhausted)")
    else
        println(io, "(next: ", time_of_next(sf), ")")
    end
end
