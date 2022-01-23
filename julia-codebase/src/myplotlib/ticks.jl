
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
