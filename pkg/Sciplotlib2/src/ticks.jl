
function _set_ticks(ax, axtypes, minorticks, ticklabels, units)

    xypairs = zip([ax.xaxis, ax.yaxis], axtypes, minorticks, ticklabels, units)
    for (axis, axtype, minorticks, ticklabels, unit) in xypairs

        turn_off_minorticks() = axis.set_minor_locator(mpl.ticker.NullLocator())

        if axtype == :keep
            continue

        elseif axtype == :range
            # Because we set the rcParam `autolimit_mode` to `data`, xlim/ylim == data range.
            a, b = axis.get_view_interval()
            digits = 2
            axis.set_ticks([round(a, RoundDown; digits), round(b, RoundUp; digits)])
            # Turn off all gridlines.
            axis.grid(which = "major", visible = false)
            turn_off_minorticks()

        elseif axtype == :categorical
            # Do not mess with ticklocs. Except:
            turn_off_minorticks()

        elseif axis.get_scale() == "log"
            # Mpl default is good, do nothing.

        else
            axis.set_major_locator(mpl.ticker.MaxNLocator(nbins = 7, steps = [1, 2, 5, 10]))
            #   `nbins` should probably depend on figure size, i.e. how large texts are wrt
            #   other graphical elements.
            #   For `steps` we omit 2.5.
            if minorticks
                axis.set_minor_locator(mpl.ticker.AutoMinorLocator())
            else
                turn_off_minorticks()
            end
        end

        # LogLocator places ticks outside limits. So we trim those.
        ticklocs = pyconvert(Vector, axis.get_ticklocs())
        a, b = pyconvert(Vector, axis.get_view_interval())
        ticklocs = ticklocs[a .≤ ticklocs .≤ b]

        if isnothing(ticklabels)
            ticklabels = [@sprintf "%.4g" t for t in ticklocs]
        end

        if unit != nothing
            suffix = " $unit"
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
            "facecolor" => mpl.rcParams["figure.facecolor"],
            "edgecolor" => "none",
            "pad" => 3,  # Relative to fontsize (google "bbox mutation scale").
        )
        # Goal: labels stay visible when overlapping with elements of an adjactent Axes.

        axis.set_ticks(ticklocs, ticklabels; bbox)
        # Note that this changes the tick locator to a FixedLocator. As a result, changing
        # the lims (e.g. zooming in) after this, you won't get useful ticks. (Cannot replace
        # by just `axis.set_ticklabels` either: then labels get out of sync with ticks)
        # Solution is to call `set` again, to get good ticks again.
    end
end
