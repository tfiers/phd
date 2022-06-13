
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
function add_VI_noise!(sim_state, sim_params::SimParams, VI_params::VoltageImagingParams)
    @unpack v_peak, v_rest = sim_params.general.izh_neuron
    @unpack spike_SNR, rngseed = VI_params
    spike_height = v_peak - v_rest
    σ_noise = spike_height / spike_SNR
    v = state.rec.voltage_traces
    VI_sig = similar(v)
    resetrng!(rngseed)
    for t in eachindex(v)
        noise = randn(length(v)) * σ_noise
        VI_sig[t] = v[t] + noise
    end
    return VI_sig
end
