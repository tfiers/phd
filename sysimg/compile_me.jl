
# `let` block, to not save the below names in the sysimg.
let
    using DataFrames, ComponentArrays
    df = DataFrame([(a=1, b=2), (a=2, b=2)])
    repr(MIME("text/html"), df)

    using ComponentArrays
    collect(ComponentVector(a=3, b=8))

    # `using PyPlot; plt.subplots() …`
    # ^ That does not work (PyPlot __init__ not run).
    #   So we only precompile (see `traced_nb`).

    using JLD2
    fn = tempname()*".jld2"
    struct MyType
        x::String
    end
    jldsave(fn; somedata=(; a=2, b=""), p=MyType("yo"))
    load(fn, "somedata", "p")

    using Distributions
    rand(LogNormal(1,1), 2)

    using ForwardDiff
    ForwardDiff.jacobian(identity, [1,1])
end
