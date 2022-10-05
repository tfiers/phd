
function calc_STA(VI_sig, presynaptic_spikes, p::ExpParams)
    win_size = STA_win_size(p)
    STA = zeros(eltype(VI_sig), win_size)
    Δt::Float64 = p.sim.general.Δt  # Explicit typing needed, as typeof(p.sim) unknown.
    win_starts = round.(Int, presynaptic_spikes / Δt)
    num_wins = 0
    for a in win_starts
        b = a + win_size - 1
        if b ≤ lastindex(VI_sig)
            STA .+= @view VI_sig[a:b]
            num_wins += 1
        end
    end
    STA ./= num_wins
    return STA
end

calc_STA((from, to), s::SimData, p::ExpParams) = calc_STA(s.v[to], s.spike_times[from], p)

STA_win_size(p::ExpParams) =
    round(Int, p.conntest.STA_window_length / p.sim.general.Δt::Float64)
        # Again, explicit type annotation on Δt.


function calc_all_STAs(s::SimData, p::ExpParams)
    # Multi-threaded calculation of the real and shuffled STAs of all tested connections.
    #
    # We use a Channel to gather calculations,
    # as inserting items into a Dict is not thread-safe.
    @unpack rngseed, num_shuffles = p.conntest
    conns = connections_to_test = get_connections_to_test(s, p)
    recorded_neurons = unique(connections_to_test.post)
    ch = Channel(Inf)  # `Inf` size, so no blocking on insert
    @info "Using $(nthreads()) threads"
    pbar = Progress(nrow(connections_to_test), desc = "Calculating STAs: ")
    @threads(
    for m in recorded_neurons
        v = s.v[m]
        inputs_to_test = conns.pre[conns.post .== m]
        for n in inputs_to_test
            spikes = s.spike_times[n]
            real_STA = calc_STA(v, spikes, p)
            shuffled_STAz = Vector(undef, num_shuffles)
            resetrng!(rngseed)
            for i in 1:num_shuffles
                shuffled_spikes = shuffle_ISIs(spikes)
                shuffled_STAz[i] = calc_STA(v, shuffled_spikes, p)
            end
            put!(ch, ((n => m), real_STA, shuffled_STAz))
            next!(pbar)
        end
    end)
    # Empty the channel, into the output dicts
    STAs          = Dict{Pair{Int, Int}, Vector{Float64}}()
    shuffled_STAs = Dict{Pair{Int, Int}, Vector{Vector{Float64}}}()
    while !isempty(ch)
        conn, real, shuffleds = take!(ch)
        STAs[conn]          = real
        shuffled_STAs[conn] = shuffleds
    end
    close(ch)
    return (; connections_to_test, STAs, shuffled_STAs)
end

cached_STAs(s, p) = cached(calc_all_STAs, [s, p], key = [p.sim, p.conntest])

# For if you don't want to load simdata `s`.
cached_STAs(p) = cached_STAs([], p)
