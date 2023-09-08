using WithFeedback
using Test

get_output(expr) = begin
    cmd = `julia --project=@. --startup-file=no -E "using WithFeedback; $expr"`
    buf = IOBuffer()
    run(pipeline(cmd, buf))
    output = String(take!(buf))
end

@testset begin

    @test get_output("@withfb 1+1") == """
        1 + 1 … ✔
        2
        """

    @test get_output("@withfb \"Resting\" sleep(0.3)") == """
        Resting … ✔ (0.3 s)
        nothing
        """

    @test get_output("@withfb true \"Calculating\" 1+1") == """
        Calculating … ✔
        2
        """

    @test get_output("@withfb false \"Calculating\" 1+1") == """
        2
        """

    @test get_output("@withfb false 1+1") == """
        2
        """
end
