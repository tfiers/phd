
include("net/init.jl")
include("net/step.jl")

include("Nto1/init.jl")  # See Nto1/ReadMe.md -- these need to be updated
include("Nto1/step.jl")

include("post.jl")

function sim(params::SimParams)
    state = init_sim(params)
    @showprogress (every = 400ms) "Running simulation: " (
    for i in 1:state.num_timesteps
        step_sim!(state, params, i)
    end)
    return state
end
