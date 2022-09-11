
function calc_STA(VI_sig, presynaptic_spikes, p::ExpParams)
    Δt::Float64 = p.sim.general.Δt  # explicit type annotation needed
    win_size = round(Int, p.conntest.STA_window_length / Δt)
    STA = zeros(eltype(VI_sig), win_size)
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

calc_STA((from, to)::Pair{Int, Int}, s::SimData, p::ExpParams) =
    calc_STA(s.signals[to].v, s.spike_times[from], p)


to_ISIs(spiketimes) = [first(spiketimes); diff(spiketimes)]  # copying
to_spiketimes!(ISIs) = cumsum!(ISIs, ISIs)                   # in place

shuffle_ISIs(spiketimes) = to_spiketimes!(shuffle!(to_ISIs(spiketimes)));

function test_connection(VI_sig, presynaptic_spikes, p::ExpParams, f = nothing)
    @unpack num_shuffles, STA_test_statistic = p.conntest
    isnothing(f) && (f = eval(Meta.parse(STA_test_statistic)))
    test_statistic(presynspikes) = f(calc_STA(VI_sig, presynspikes, p))
    real_t = test_statistic(presynaptic_spikes)
    shuffled_t = Vector{typeof(real_t)}(undef, num_shuffles)
    for i in eachindex(shuffled_t)
        shuffled_t[i] = test_statistic(shuffle_ISIs(presynaptic_spikes))
    end
    N_shuffled_larger = count(shuffled_t .> real_t)
    return if N_shuffled_larger == 0
        p_value = 1 / num_shuffles
    else
        p_value = N_shuffled_larger / num_shuffles
    end
end
