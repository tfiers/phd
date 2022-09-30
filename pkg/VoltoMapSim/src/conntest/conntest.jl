
# "peak-to-peak"
ptp(STA) = maximum(STA) - minimum(STA)

area_over_start(STA) = sum(STA .- STA[1])


function test_conn__ptp(real_STA, shuffled_STAs, α)
    pval, _ = calc_pval(ptp, real_STA, shuffled_STAs)
    area = area_over_start(real_STA)
    if     (pval > α)  predtype = :unconn
    elseif (area > 0)  predtype = :exc
    else               predtype = :inh end
    return (; predtype, pval, area)
end


function test_conn__corr(real_STA, shuffled_STAs, α; template)
    corr = cor(real_STA, template)
    if (corr > 0) test_stat = (STA -> cor(STA, template))
    else          test_stat = (STA -> -cor(STA, template)) end
    pval, _ = calc_pval(test_stat, real_STA, shuffled_STAs)
    if     (pval > α)  predtype = :unconn
    elseif (corr > 0)  predtype = :exc
    else               predtype = :inh end
    return (; predtype, pval, corr)
end
# To use with `test_conns`, curry it: `test_conn__corr $ (; template = …)`


function test_conns(f, conns, STAs, shuffled_STAs; α)
    # `f` is a function `f(real_STA, shuffled_STAs, α) -> (; predtype, …)`
    # `conns` is the output of `get_connections_to_test`
    # `α` is the p-value threshold.
    testresults = @showprogress "Testing connections: " (
        map(eachrow(conns)) do conn
            k = conn.pre => conn.post
            testresult = f(STAs[k], shuffled_STAs[k], α)
        end
    )
    tc = hcat(conns, DataFrame(testresults))
    # Reorder first cols:
    select!(tc, :posttype, :post, :pre, :conntype, :)
    return tc
end
