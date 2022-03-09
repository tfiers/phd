
include("sim/init.jl")
include("sim/step.jl")

function sim(params::SimParams)
    state, rec = init_sim(params)
    @unpack duration, num_timesteps = params
    @showprogress x for i in 1:num_timesteps
        step_sim!(state, params, rec, i)
    end
    t = linspace(zero(duration), duration, num_timesteps)
    return (; t, rec.v, rec.input_spikes)
end

const x = progress_bar_update_interval = 400ms
