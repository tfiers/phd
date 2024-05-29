
using WithFeedback

@withfb import PythonCall
@withfb import PythonPlot
@withfb using Sciplotlib
@withfb using PhDPlots

using ConnTestEval
using DefaultApplication


# Just as a reference
const default_figsize = Sciplotlib.sciplotlib_style["figure.figsize"]

openfig(path = PhDPlots.last_figpath) = DefaultApplication.open(path)
open_figdir() = DefaultApplication.open(abspath("../thesis/figs"))


# For the `figsize` argument to plt.subplots() and friends.
fs(width, aspect) = (width, width / aspect)


function plotROC(
    sweep;
    ax = newax(),
    title="",
    legend_font_size = 7.6,
    legend_loc = "lower center"
)
    # On `legend_font_size`: If using default / rcParams legend size,
    # legend will be bigger than other legends (cause monospace font).
    # The value here is chosen to match rcParams ["font.size" = 9] and
    # "legend.fontsize" = 8.
    AUCs = calc_AUROCs(sweep)
    AUCs = (; (k => round(AUCs[k], digits=2) for k in keys(AUCs))...)
    plot(sweep.FPR, sweep.TPRₑ; ax, label="Excitatory   $(AUCs.AUCₑ)", color=color_exc)
    plot(sweep.FPR, sweep.TPRᵢ; ax, label="Inhibitory   $(AUCs.AUCᵢ)", color=color_inh)
    plot(sweep.FPR, sweep.TPR ; ax, label="Both         $(AUCs.AUC)", color=color_both)
    set(ax, aspect="equal", xlabel="Non-inputs wrongly detected (FPR)", ylabel="Real inputs detected (TPR)",
        xtype=:fraction, ytype=:fraction, title=(title, :pad=>12, :loc=>"right"))
    font = Dict("family"=>"monospace", "size"=>legend_font_size)
    legend(ax, borderaxespad=1,     title="Input type   AUC ", loc=legend_loc,
            alignment="right", markerfirst=true, prop=font);
    # Using the same `font` dict for `title_fontproperties` does not apply the size (bug in Julia-Python, somehow)
    ax.legend_.get_title().set(family="monospace", size=legend_font_size, weight="bold");
    return ax
end

newax(; kw...) = ((fig, ax) = plt.subplots(; kw...); ax)

function distplot(
    x;
    ax = newax(figsize=(4, 0.4)),
    y = 0.0,
    jitter = 0.2,
    ylim = [-1,1],
    ms = 3,
    jitterseed = 1,
    lines = true,
    mean = lines,
    median = lines,
    kw...
)
    N = length(x)
    y = fill(y, N)
    Random.seed!(jitterseed)
    @. y += (2*rand()-1)*jitter
    plot(x, y, "."; ax, ytype=:off, ylim, ms, kw...)
    mean && ax.axvline(StatsBase.mean(x), lw=1, color="black")
    median && ax.axvline(StatsBase.median(x), lw=1, color="black", linestyle="--")
    return ax
end

function plot_dots_and_means(
    df, xcol, ycol;
    ax = newax(),
    xtype = :default,  # If :categorical, specify `xticklabels` too.
    ms_dots = 3,
    ms_means = 8,
    color_dots = lightgrey,
    color_means = black,
    xlabel = string(xcol),
    ylabel = string(ycol),
    line_label = nothing,
    kw...
)
    gd = groupby(df, xcol)
    dfm = combine(gd, ycol => mean => ycol)
    if xtype ∈ [:cat, :categorical]
        x = reduce(vcat, [fill(i, nrow(sdf)) for (i,sdf) in enumerate(gd)])
        xm = 1:nrow(dfm)
        if :xticklabels ∉ keys(kw)
            kw = Dict{Symbol,Any}(kw)
            kw[:xticklabels] = string.(dfm[!, xcol])
        end
    else
        x = df[!, xcol]
        xm = dfm[!, xcol]
    end
    plot(x, df[!, ycol], "."; ax, c=color_dots, ms=ms_dots, xtype, xlabel, ylabel, kw...)
    plot(xm, dfm[!, ycol], ".-"; ax, c=color_means, ms=ms_means, xtype, xlabel, ylabel, label=line_label, kw...)
    return ax
end

(; ScaledTranslation) = mpl.transforms

inch(pt) = pt / 72

function axtitle(
    ax,
    title,
    subtitle = nothing;
    dx_s=0, dy_s=4,   # Offset of subtitle from axes, in points
    dx_t=0, dy_t=1.3, # Offset of title from subtitle, in fractions of subtitle's bbox
    kw...
)
    offset = ScaledTranslation(inch(dx_s), inch(dy_s), ax.figure.dpi_scale_trans)
    transform = ax.transAxes + offset
    st = ax.text(; x=0, y=1, s=subtitle, transform, va="bottom", fontweight="normal")
    tt = ax.annotate(title; xy=(dx_t, dy_t), xycoords=st, va="bottom", fontweight="bold")
    return (tt, st)
end

nothing;
