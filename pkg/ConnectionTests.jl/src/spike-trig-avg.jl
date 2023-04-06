
using Random
using Statistics  # for `cor`
using ConnTestEval

abstract type STABasedConnTest <: ConnTestMethod end

# Type aliases.
# Used to distinguish between `test_conn` with (v, times),
# and `test_conn` with (real_STA, shuffled_STAs).
const Signal = STA = Spiketimes = Vector{Float64}

# Users may use this function; or if they have precalculated the STAs
# (e.g. cached on disk; caching is useful, as multiple methods use the
# STA), they can use the STA-taking func below directly.
test_conn(m::STABasedConnTest, v::Signal, times::Spiketimes) =
    test_conn(
        m,
        calc_STA(v, times),
        calc_shuffle_STAs(v, times)
    )

calc_shuffle_STAs(v, times, N = 100; seed = 1) = begin
    Random.seed!(seed)
    return [
        calc_STA(v, shuffle_ISIs(times))
        for _ in 1:N
    ]
end

shuffle_ISIs(spiketimes) = spiketimes |> to_ISIs |> shuffle! |> to_spiketimes!

to_ISIs(spiketimes) = [first(spiketimes); diff(spiketimes)]  # copying
to_spiketimes!(ISIs) = cumsum!(ISIs, ISIs)                   # in place

calc_STA(v, times, Δt = Δt, win_size = STA_length) = begin
    STA = zeros(eltype(v), win_size)
    # We assume here that spiketimes occur in [0, T)
    win_starts = floor.(Int, times ./ Δt) .+ 1
    num_wins = 0
    for a in win_starts
        b = a + win_size - 1
        if b ≤ lastindex(v)
            STA .+= @view v[a:b]
            num_wins += 1
        end
    end
    STA ./= num_wins
    return STA
end

calc_all_STAs(v, spiketime_vecs) = begin
    reals = STA[]
    shufs = Vector{STA}[]
    N = length(spiketime_vecs)
    for (i, times) in enumerate(spiketime_vecs)
        @withfb "Calculating STAs for connection $i / $N" begin
            push!(reals, calc_STA(v, times))
            push!(shufs, calc_shuffle_STAs(v, times))
        end
    end
    return (; reals, shufs)
end

calc_pval(test_stat, real_STA, shuffled_STAs) = begin
    # `shuffled_STAs` are STAs where the real presynaptic spikes have been ISI-shuffled.
    N = length(shuffled_STAs)
    real_t = test_stat(real_STA)
    H0_ts  = test_stat.(shuffled_STAs)      # What we'd see if unconnected.
    num_H0_larger = count(H0_ts .≥ real_t)  # [1]
    if num_H0_larger == 0
        pval = 1 / N
        type = "<"
    else
        pval = num_H0_larger / N
        type = "="
    end
    return (; pval, type)
end
# [1] Greater _or equal_, as p-value is probability of observing t values *at least as*
#     extreme as the real t:   p-value = P(T ≥ t | H0)

pval_to_c(p::Float64) = 1 - p
pval_to_c(tup::NamedTuple) = pval_to_c(tup.pval)

connectedness_via_shuffle_test(test_stat, real::STA, shuf::Vector{STA}) =
    (
        calc_pval(test_stat, real, shuf)
        |> pval_to_c
    )



struct STAHeight <: STABasedConnTest
end

# aka ptp, peak-to-peak
height(STA) = maximum(STA) - minimum(STA)

area_over_start(STA) = sum(STA .- STA[1])

test_conn(m::STAHeight, real::STA, shuf::Vector{STA}) = begin
    test_stat = height
    s = sign(area_over_start(real))
    t = connectedness_via_shuffle_test(height, real, shuf)
    return s * t
end



struct TemplateCorr <: STABasedConnTest
    template::STA
end

test_conn(m::TemplateCorr, real::STA, shuf::Vector{STA}) = begin
    ρ = cor(real, m.template)
    if (ρ > 0) test_stat = (STA -> cor(STA, m.template))
    else       test_stat = (STA -> -cor(STA, m.template)) end
    t = connectedness_via_shuffle_test(test_stat, real, shuf)
    return sign(ρ) * t
end



@kwdef struct TwoPassCorrTest <: STABasedConnTest
    θ::Float64 = 0.98  # Threshold on 'connectedness values'.
                       # = 1 - p_value_threshold
end

test_conns(
    m          ::TwoPassCorrTest,
    real_STAs  ::Vector{STA},
    shuf_lists ::Vector{Vector{STA}},
) = begin
    @withfb "First pass" begin
        tvals₁ = test_conns(STAHeight(), real_STAs, shuf_lists)
    end
    predtypes = ConnTestEval.predicted_types(tvals₁, m.θ)
    exc_STAs = real_STAs[predtypes .== :exc]
    template = mean(exc_STAs)  # Vectors add (ofc)
    @withfb "Second pass" begin
        tvals₂ = test_conns(TemplateCorr(template), real_STAs, shuf_lists)
    end
    return tvals₂
end

mean(xs) = sum(xs) ./ length(xs)
