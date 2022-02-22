
include("sim/init.jl")
include("sim/step.jl")

function sim(p::SimParams)
    state, init, rec = init_sim(p)
    @unpack duration, num_timesteps = p
    @showprogress x for i in 1:num_timesteps
        step_sim!(state, p, init, rec, i)
    end
    t = linspace(zero(duration), duration, num_timesteps)
    return (; t, rec.v, rec.input_spikes)
end

const x = progress_bar_update_interval = 400ms
