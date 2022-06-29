
include("net/init.jl")
include("net/step.jl")

include("Nto1/init.jl")  # See Nto1/ReadMe.md -- these need to be updated
include("Nto1/step.jl")

function sim(params::SimParams)
    state = init_sim(params)
    @showprogress (every = 400ms) "Running simulation: " (
    for i in 1:state.init.num_timesteps
        step_sim!(state, params, i)
    end)
    return state
end

# We don't add the VI noise in the main `sim` function, so that, for different noise levels,
# that function can be cached once and its output re-used.
function add_VI_noise(voltage_traces, p::ExperimentParams)
    @unpack v_peak, v_rest = p.sim.general.izh_neuron
    @unpack spike_SNR, rngseed = p.imaging
    spike_height = v_peak - v_rest
    σ_noise = spike_height / spike_SNR
    N = length(first(voltage_traces))
    VI_sigs = similar(voltage_traces)
    resetrng!(rngseed)
    for m in eachindex(voltage_traces)
        noise = randn(N) * σ_noise
        VI_sigs[m] = voltage_traces[m] + noise
    end
    return VI_sigs
end
