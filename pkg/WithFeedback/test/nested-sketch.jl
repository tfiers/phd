
using WithFeedback

WithFeedback.nested()

@withfb "Reticulating splines" begin
    sleep(1)
    N = 3
    for i in 1:N
        @withfb "Spline $i / $N" begin
            sleep(0.3)
        end
    end
end

# This is not implemented anymore. See commit 3cbc064 of `tfiers/phd`, where it still was.
