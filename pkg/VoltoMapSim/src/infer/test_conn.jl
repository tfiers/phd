
# "peak-to-peak"
ptp(STA) = maximum(STA) - minimum(STA)

area_over_start(STA) = sum(STA .- STA[1])

function ptp_test(STA)
    test_stat = ptp
    Eness = area_over_start(STA)
    return test_stat, Eness
end

function corr_test(STA; template)
    Eness = cor(STA, template)
    if (Eness > 0) test_stat = (sta -> cor(sta, template))
    else           test_stat = (sta -> -cor(sta, template)) end
    return test_stat, Eness
end
# To use with `test_conn`, curry it: `corr_test $ (; template = …)`


function test_conn(testfunc, real_STA, shuffled_STAs; α)
    # `testfunc` is a function `f(real_STA) -> (pval_test_stat, excitatory-ness)`
    #   - the former is passed to `calc_pval`
    # `α` is the p-value threshold.
    test_stat, Eness = testfunc(real_STA)
    pval, pval_type = calc_pval(test_stat, real_STA, shuffled_STAs)
    if        (pval  > α) predtype = :unconn
    elseif    (Eness > 0) predtype = :exc
    else                  predtype = :inh end
    return (; predtype, pval, pval_type, Eness)
end


function test_conns(f, conns, STAs, shuffled_STAs; α, pbar = true)
    # `conns` is the output of `get_connections_to_test`
    pb = Progress(nrow(conns), desc = "Testing connections: ", enabled = pbar)
    testresults = map(eachrow(conns)) do conn
        k = conn.pre => conn.post
        testresult = test_conn(STAs[k], shuffled_STAs[k]; α)
        if pbar next!(pb)
        else    print(".") end
        return testresult
    end
    tc = hcat(conns, DataFrame(testresults))
    # Reorder first cols:
    select!(tc, :posttype, :post, :pre, :conntype, :)
    return tc
end
