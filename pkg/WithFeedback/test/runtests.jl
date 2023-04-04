
using WithFeedback

WithFeedback.nested()
# WithFeedback.always_print_newline()  # subsumed by nested

@withfb "Reticulating splines" begin
    sleep(1)
    N = 3
    for i in 1:N
        @withfb "Spline $i / $N" begin
            sleep(0.3)
        end
    end
end
