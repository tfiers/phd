
println("[IJulia init done]")
flush(stdout)

using WithFeedback

@withfb using Revise
@withfb using Units
@withfb using Nto1AdEx
@withfb using ConnectionTests
@withfb using ConnTestEval

include("util.jl")
prettify_logging_in_IJulia()
set_print_precision(3)

nothing;
