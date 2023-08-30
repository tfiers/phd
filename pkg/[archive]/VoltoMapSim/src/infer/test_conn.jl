
# "peak-to-peak"
ptp(STA) = maximum(STA) - minimum(STA)

area_over_start(STA) = sum(STA .- STA[1])

function ptp_test(real_STA)
    test_stat(STA) = ptp(STA)
    Eness = area_over_start(real_STA)
    return test_stat, Eness
end

function corr_test(real_STA; template)
    Eness = cor(real_STA, template)
    if (Eness > 0) test_stat = (STA -> cor(STA, template))
    else           test_stat = (STA -> -cor(STA, template)) end
    return test_stat, Eness
end
# To use with `test_conn`, curry it: `corr_test $ (; template = …)`

function modelfit_test(real_STA; modelling_funcs)
    fit, model = modelling_funcs
    function test_stat(STA)
        fitted_model = model(fit(STA).param)
        μ, σ = mean(STA), std(STA)
        # z-scoring because unconnected/shuffled STA's have smaller scale -> lower MSE.
        t = -MSE(zscore(STA, μ, σ), zscore(fitted_model, μ, σ))
    end
    Eness = (fit(real_STA) |> toParamCVec).scale / mV
    return test_stat, Eness
end

MSE(y, ŷ) = mean((y .- ŷ).^2)


function test_conn(testfunc, real_STA, shuffled_STAs; α = 0.05)
    # `testfunc` is a function `f(real_STA) -> (pval_test_stat, excitatory-ness)`
    #   - the former is passed to `calc_pval`
    #   - the latter indicates whether predicted type is exc. (> 0) or inh. (< 0)
    # `α` is the p-value threshold.
    test_stat, Eness = testfunc(real_STA)
    pval, pval_type = calc_pval(test_stat, real_STA, shuffled_STAs)
    if        (pval  > α) predtype = :unconn
    elseif    (Eness > 0) predtype = :exc
    else                  predtype = :inh end
    return (; predtype, pval, pval_type, Eness)
end


function test_conns(testfunc, conns, STAs, shuffled_STAs; α = 0.05, pbar = true)
    # `conns` is the output of `get_connections_to_test`
    pb = Progress(nrow(conns), desc = "Testing connections: ", enabled = pbar)
    testresults = map(eachrow(conns)) do conn
        k = conn.pre => conn.post
        testresult = test_conn(testfunc, STAs[k], shuffled_STAs[k]; α)
        if (pbar) next!(pb) else print(".") end
        return testresult
    end
    if (!pbar) println() end
    tc = hcat(conns, DataFrame(testresults))
    # Reorder first cols:
    select!(tc, :posttype, :post, :pre, :conntype, :)
    return tc
end
