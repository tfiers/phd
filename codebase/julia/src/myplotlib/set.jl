export set, legend, hylabel

"""
Set Axes properties and apply beautiful defaults.
Use `xtickstyle` or `ytickstyle` = `:range` to mark the data range (and nothing else).
"""
function set(
    ax;
    yaxis = :left,
    xtickstyle = :default,
    ytickstyle = :default,
    xminorticks = true,
    yminorticks = true,
    kw...
)
    if yaxis == :right
        ax.yaxis.tick_right()
        ax.spines["right"].set_visible(true)
        ax.spines["left"].set_visible(false)
    elseif yaxis == :off
        ax.yaxis.set_visible(false)
        ax.spines["right"].set_visible(false)
        ax.spines["left"].set_visible(false)
    end

    # Instead of calling `ax.set(; kw...)`, we call the individual methods, so that we
    # can pass more than just the one argument for each.
    for (k, v) in kw
        hasproperty(ax, "set_$k") && _call(getproperty(ax, "set_$k"), v)
    end

    :hylabel in keys(kw) && _call((hylabel $ ax), kw[:hylabel])
    :legend in keys(kw) && _call((legend $ ax), kw[:legend])

    # Various defaults that can't be set through rcParams
    ax.grid(axis = "both", which = "minor", color = "#F4F4F4", linewidth = 0.44)
    for pos in ("left", "right", "bottom", "top")
        ax.spines[pos].set_position(("outward", 10))
        #    `Spine.set_position` resets ticks, and in doing so removes text properties.
        #    Hence these must be called before `_set_ticks` below.
    end
    
    # Fix default behaviour where only top and left gridlines are visible when gridlines are
    # on the limits.
    ax.yaxis.get_gridlines()[1].set_clip_on(false)  # bottom
    ax.xaxis.get_gridlines()[end].set_clip_on(false)  # right

    # Our opinionated tick defaults. 
    _set_ticks(ax, [xtickstyle, ytickstyle], [xminorticks, yminorticks])
end

"""Given a tuple like `("arg", :key => "val")`, call `f("arg"; key="val")`."""
function _call(f, x::Tuple)
    firstkw = findfirst(el -> el isa Pair, x)
    if isnothing(firstkw)
        args = x
        kwargs = ()
    else
        args = x[1:firstkw-1]
        kwargs = x[firstkw:end]        
    end
    f((args .|> as_mpl_type)...; (kwargs |> mapvals $ as_mpl_type)...)
end

_call(f, x) = f(x |> as_mpl_type)

"""
Add a legend to the axes. Change the order of the items in the legend using
`reorder = [plot_order => legend_order,]`. Eg passing `(4 => 1, 1 => 2)` will make the
4th plotted line come 1st in the legend, and the 1st plotted line come 2nd.
"""
function legend(ax; reorder = false, legendkw...)
    handles, labels = ax.get_legend_handles_labels()
    order = collect(1:length(handles))
    if reorder != false
        for (i_old, i_new) in reorder
            insert!(order, i_new, popat!(order, i_old))
        end
    end
    ax.legend([handles[i] for i in order], [labels[i] for i in order]; legendkw...)
end

"""Add a horizontal ylabel."""
function hylabel(ax, s; loc=:left, dx=0, dy=4)
    offset = mpl.transforms.ScaledTranslation(dx / 72, dy / 72, ax.figure.dpi_scale_trans)
    transform = ax.transAxes + offset
    fontsize = mpl.rcParams["axes.labelsize"]
    x = (loc == :left) ? 0 : (loc == :center) ? 0.5 : 1
    t = ax.text(; x, y=1, s, transform, ha=loc, va="bottom", fontsize)
    ax.hylabel = t
end
