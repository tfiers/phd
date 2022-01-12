using PyCall, IJulia, FilePaths
using FilePathsBase: /
import PyPlot as plt

"""Beautiful plots by default"""
function plot(x...; kw...)
    if (first(x) isa PyObject) && pyisinstance(first(x), plt.matplotlib.axes.Axes)
        ax = first(x)
        x = x[2:end]
    else
        ax = plt.gca()
    end
    kw = Dict{Symbol,Any}(kw)
    kw[:clip_on] = get(kw, :clip_on, false)
    ax.plot(x...; kw...)
    set!(ax)
    ax
end


function set!(ax; kw...)
    tick = plt.matplotlib.ticker
    roundout((min, max)) = (round(min, RoundDown; digits = 2), round(max, RoundUp; digits = 2))
    if get(kw, :xscale, nothing) != "log"
        if get(kw, :xrange, false) == true
            # make use of `"autolimit_mode" => "data"`. Only show data range.
            ax.set_xticks(roundout(ax.get_xlim()))
            ax.grid(false, axis = "x", which = "major")
        else
            ax.xaxis.set_major_locator(tick.MaxNLocator(nbins = 10, steps = [1, 5, 10]))
            ax.xaxis.set_minor_locator(tick.AutoMinorLocator())
        end
    end
    if get(kw, :yscale, nothing) != "log"
        if get(kw, :yrange, false) == true
            ax.set_yticks(roundout(ax.get_ylim()))
            ax.grid(false, axis = "y", which = "major")
        else
            ax.yaxis.set_major_locator(tick.MaxNLocator(nbins = 10, steps = [1, 5, 10]))
            ax.yaxis.set_minor_locator(tick.AutoMinorLocator())
        end
    end

    kw = Dict(k => v for (k,v) in kw if k ∉ (:xrange, :yrange))
    ax.set(; kw...)

    # Defaults that can't be set through rcParams
    ax.grid(which = "minor", axis = "both", color = "#F4F4F4", linewidth = 0.44)
    ax.xaxis.set_major_formatter(tick.StrMethodFormatter("{x:.4g}"))
    ax.yaxis.set_major_formatter(tick.StrMethodFormatter("{x:.4g}"))
    ax.spines["left"].set_position(("outward", 10))
    ax.spines["bottom"].set_position(("outward", 10))
end

# Hi-def ('retina') figures in notebook. [https://github.com/JuliaLang/IJulia.jl/pull/918]
function IJulia.metadata(x::plt.Figure)
    w, h = (x.get_figwidth(), x.get_figheight()) .* x.get_dpi()
    return Dict("image/png" => Dict("width" => 0.5*w, "height" => 0.5*h))
end

function savefig(fname; subdir)
    dir = Path(get(ENV, "figdir", ".")) / subdir
    exists(dir) || mkpath(string(dir))
    plt.savefig(string(dir / fname))
end
