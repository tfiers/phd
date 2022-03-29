
include("sim/init.jl")
include("sim/step.jl")

function sim(params::SimParams)
    state, rec = init_sim(params)
    @unpack duration, num_timesteps = params
    @showprogress x for i in 1:num_timesteps
        step_sim!(state, params, rec, i)
    end
    t = linspace(zero(duration), duration, num_timesteps)
    vimsig = add_VI_noise(rec.v, params.imaging.σ_noise)
    return (; t, rec.v, vimsig, rec.input_spikes, state)
end

const x = progress_bar_update_interval = 400ms

function add_VI_noise(v, σ_noise)
    noise = randn(length(v)) * σ_noise
    return v + noise
end
