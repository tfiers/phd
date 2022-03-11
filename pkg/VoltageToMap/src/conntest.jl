
function calc_STA(vimsig, presynaptic_spikes, p::ExperimentParams)
    Δt = p.sim.Δt
    win_size = round(Int, p.conntest.STA_window_length / Δt)
    STA = zeros(eltype(vimsig), win_size)
    win_starts = round.(Int, presynaptic_spikes / Δt)
    num_wins = 0
    for a in win_starts
        b = a + win_size - 1
        if b ≤ lastindex(vimsig)
            STA .+= @view vimsig[a:b]
            num_wins += 1
        end
    end
    STA ./= num_wins
    return STA
end

to_ISIs(spiketimes) = [first(spiketimes); diff(spiketimes)]  # copying
to_spiketimes!(ISIs) = cumsum!(ISIs, ISIs)                   # in place

shuffle_ISIs(spiketimes) = to_spiketimes!(shuffle!(to_ISIs(spiketimes)));

test_statistic(vimsig, presynspikes, p) = mean(calc_STA(vimsig, presynspikes, p))

function test_connection(vimsig, presynaptic_spikes, p::ExperimentParams)
    @unpack num_shuffles = p.conntest
    real_t = test_statistic(vimsig, presynaptic_spikes, p)
    shuffled_t = Vector{typeof(real_t)}(undef, num_shuffles)
    for i in eachindex(shuffled_t)
        shuffled_t[i] = test_statistic(vimsig, shuffle_ISIs(presynaptic_spikes), p)
    end
    N_shuffled_larger = count(shuffled_t .> real_t)
    return if N_shuffled_larger == 0
        p_value = 1 / num_shuffles
    else
        p_value = N_shuffled_larger / num_shuffles
    end
end
