
@kwdef struct WinPoolLinReg <: ConnTestMethod
    winsize::Int = 100
    offset::Int = 0
end

function test_conn(m::WinPoolLinReg, v, times)
    fit = fitwins(m, v, times)
    t = calc_slope_0_test_stat(fit)
    return t
end

function fitwins(m::WinPoolLinReg, v, times)
    (; winsize, offset) = m
    wins = windows(v, times, winsize, offset)
    timepoints = (1:winsize) .+ offset
    X, y = build_Xy(wins, timepoints)
    β̂ = vec(X \ y)
    ŷ = X * β̂
    ε̂ = y .- ŷ
    return (;
        X, y, β̂,
        intercept   = β̂[1], # / mV,       # in mV
        slope       = β̂[2], # / mV / Δt,  # in mV/second
        predictions = ŷ,
        residuals   = ε̂,
    )
end

function windows(v, times, winsize, offset; Δt=Δt)
    # Assuming that times occur in [0, T)
    win_starts = floor.(Int, times / Δt) .+ 1 .+ offset
    wins = Vector{Vector{eltype(v)}}()
    for a in win_starts
        b = a + winsize - 1
        if b ≤ lastindex(v)
            push!(wins, v[a:b])
        end
    end
    return wins
end

function build_Xy(windows, timepoints)
    N = length(windows) * length(timepoints)
    T = eltype(eltype(windows))
    X = Matrix{T}(undef, N, 2)
    y = Vector{T}(undef, N)
    i = 1
    for win in windows
        for (tᵢ, yᵢ) in zip(timepoints, win[timepoints])
            # X[i,:] .= [1, tᵢ]  # Tryin to make faster:
            X[i,1] = 1
            X[i,2] = tᵢ
            y[i] = yᵢ
            i += 1
        end
    end
    @assert i == N + 1
    return (X, y)
end

function calc_slope_0_test_stat(fit)
    # Calculate test statistic `t` for H0: 'slope is zero'
    # See https://tfiers.github.io/phd/nb/2023-01-19__Fit-a-line.html#hypothesis-testing
    (; X, y, β̂) = fit
    n = length(y)
    p = 2  # Num params
    dof = n - p
    ε̂ = fit.residuals
    s² = ε̂' * ε̂ / dof
    Q = inv(X' * X)
    σ̂β₂ = √(s² * Q[2,2])
    t = β̂[2] / σ̂β₂
    return t
    # 𝒩 = Normal(0, 1)
    # pval = cdf(𝒩, -abs(t)) + ccdf(𝒩, abs(t))
end
