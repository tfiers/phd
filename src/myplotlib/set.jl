"""
Set Axes properties and apply beautiful defaults.
Use `xtickstyle` or `ytickstyle` = `:range` to mark the data range (and nothing else).
"""
function set(
    ax;
    xtickstyle = :default,
    ytickstyle = :default,
    xminorticks = true,
    yminorticks = true,
    axeskw...
)
    ax.set(; (axeskw |> convertColorantstoRGBAtuples)...)
    # Various defaults that can't be set through rcParams
    ax.grid(axis = "both", which = "minor", color = "#F4F4F4", linewidth = 0.44)
    for pos in ("left", "right", "bottom", "top")
        ax.spines[pos].set_position(("outward", 10))
        #    `Spine.set_position` resets ticks, and in doing so removes text properties.
        #    Hence these must be called before `_set_ticks` below.
    end
    # Fix sloppy-looking behaviour where only top and left gridlines are visible when
    # gridlines are on the limits.
    ax.yaxis.get_gridlines()[1].set_clip_on(false)  # bottom
    ax.xaxis.get_gridlines()[end].set_clip_on(false)  # right
    # Our opinionated tick defaults. 
    _set_ticks(ax, [xtickstyle, ytickstyle], [xminorticks, yminorticks])
end

function _set_ticks(ax, tickstyles, minorticks_enableds)
    xypairs = zip([ax.xaxis, ax.yaxis], tickstyles, minorticks_enableds)
    for (axis, tickstyle, minorticks_enabled) in xypairs
        if tickstyle == :range
            # Because we set the rcParam `autolimit_mode` to `data`, xlim/ylim == data range.
            a, b = axis.get_view_interval()
            digits = 2
            axis.set_ticks([round(a, RoundDown; digits), round(b, RoundUp; digits)])
            # Turn off all gridlines.
            axis.grid(which = "major", visible = false)
            axis.set_minor_locator(mpl.ticker.NullLocator())
        elseif axis.get_scale() == "log"
            # Mpl default is good, do nothing.
        else
            axis.set_major_locator(mpl.ticker.MaxNLocator(nbins = 7, steps = [1, 2, 5, 10]))
            #   `nbins` should probably depend on figure size, i.e. how large texts are wrt
            #   other graphical elements.
            if minorticks_enabled 
                axis.set_minor_locator(mpl.ticker.AutoMinorLocator())
            else
                axis.set_minor_locator(mpl.ticker.NullLocator())
            end
        end
        # LogLocator places ticks outside limits. So we trim those.
        ticklocs = axis.get_ticklocs()
        a, b = axis.get_view_interval()
        ticklocs = ticklocs[a .≤ ticklocs .≤ b]
        ticklabels = [@sprintf "%.4g" t for t in ticklocs]
        units = hasproperty(axis, :unitful_units) ? axis.unitful_units : units
        if units != unit(1)
            suffix = " " * repr("text/plain", units)
            if axis == ax.xaxis
                prefix_width = round(Int, length(suffix) * 1.6)
                prefix = repeat(" ", prefix_width)  # Imprecise hack to shift label to the
                                                    # right, to get number back under tick.
            else
                prefix = ""
            end
            ticklabels[end] = prefix * ticklabels[end] * suffix
        end
        bbox = Dict(
            :facecolor => mpl.rcParams["figure.facecolor"],
            :edgecolor => "none",
            :pad => 3,  # Relative to fontsize (see "mutation scale").
        ) # Goal: labels stay visible when overlapping with elements of an adjactent Axes.
        axis.set_ticks(ticklocs, ticklabels; bbox)
    end
end

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
function hylabel(ax, text; dx=0, dy=4, ha="left", va="bottom")
    offset = mpl.transforms.ScaledTranslation(dx / 72, dy / 72, ax.figure.dpi_scale_trans)
    fontsize = mpl.rcParams["axes.labelsize"]
    t = ax.text(0, 1, text; transform=ax.transAxes + offset, ha, va, fontsize)
    ax.hylabel = t
end
