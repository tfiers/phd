
include("sim/init.jl")
include("sim/step.jl")

function sim(p::SimParams)
    state, rec, init = init_sim(p)
    @unpack sim_duration, num_timesteps = p
    @showprogress x for i in 1:num_timesteps
        step_sim!(state, rec, i, p, init)
    end
    t = linspace(zero(sim_duration), sim_duration, num_timesteps)
    return (; t, rec.v, rec.input_spikes)
end

const x = progress_bar_update_interval = 400ms
