
"""
`μ` and `σ` are mean and standard deviation of the underlying Gaussian.
`μₓ` is the mean of the log of the Gaussian.
"""
function LogNormal_with_mean(μₓ, σ)
    μ = log(μₓ) - σ^2 / 2
    return LogNormal(μ, σ)
end

"""'peak-to-peak'"""
ptp(signal) = maximum(signal) - minimum(signal)

# Area over start
area(STA) = sum(STA .- STA[1])

jn(strs...) = join(strs, "\n")


function bin(spiketimes; duration, binsize)
    # `spiketimes` is assumed sorted.
    # `duration` is of the spiketimes signal and co-determines the number of bins.
    num_bins = ceil(Int, duration / binsize)
    spikecounts = fill(0, num_bins)
    # loop counters:
    spike_nr = 1
    bin_end_time = binsize
    for bin in 1:num_bins
        while spiketimes[spike_nr] < bin_end_time
            spikecounts[bin] += 1
            spike_nr += 1
            if spike_nr > length(spiketimes)
                return spikecounts
            end
        end
        bin_end_time += binsize
    end
end


const SimData = NamedTuple

# Hack to not have the NamedTuple containing simulation data take up huge amounts of space
# in stacktraces and such.
print_type_compactly(x, typename = "SimData") =
    eval( :(Base.show(io::IO, ::Type{typeof($x)}) = print(io, $typename)) )


"""
When using a sysimg with PyPlot in it, PyPlot's `__init__` gets called before IJulia is
initialized. As a result, figures do not get automatically displayed in the notebook.
(https://github.com/JuliaPy/PyPlot.jl/issues/476).
Calling `autodisplay_figs()` after IJulia is initialized fixes that.
"""
function autodisplay_figs()
    if (isdefined(Main, :PyPlot) && isdefined(Main, :IJulia) && Main.IJulia.inited
        && (Main.PyPlot.isjulia_display[] == false)
    )
        Main.PyPlot.isjulia_display[] = true
        Main.IJulia.push_preexecute_hook(Main.PyPlot.force_new_fig)
        Main.IJulia.push_postexecute_hook(Main.PyPlot.display_figs)
        Main.IJulia.push_posterror_hook(Main.PyPlot.close_figs)
    end
end
