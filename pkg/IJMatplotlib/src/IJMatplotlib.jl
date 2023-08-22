module IJMatplotlib

# Have PythonCall not use CondaPkg.jl, to not create a new (GB+) conda
# env per julia project, which would also not allow the user to install
# their own package with `pip install -e`.
ENV["JULIA_CONDAPKG_BACKEND"] = "Null"

using PythonCall
using WithFeedback

const Gcf = PythonCall.pynew()
const plt = PythonCall.pynew()
const mpl = PythonCall.pynew()

export plt, mpl

function __init__()

    if !isdefined(Main, :IJulia) || !Main.IJulia.inited
        error("Must be running in an IJulia jupyter notebook.")
    end

    key = "JULIA_PYTHONCALL_EXE"
    if key ∈ keys(ENV)
        print("Using `$(ENV[key])`. ")
        # No newline; added below in @withfb (to keep it all on one line).
    else
        error("""Please create an environment variable `$key`
                 pointing to the Python executable to use.
                 (You might have to restart your terminal
                 and jupyter afterwards).""")
    end

    @withfb "Loading matplotlib" pyimport("matplotlib.pyplot")

    PythonCall.pycopy!(Gcf, pyimport("matplotlib._pylab_helpers").Gcf)
    PythonCall.pycopy!(plt, pyimport("matplotlib.pyplot"))
    PythonCall.pycopy!(mpl, pyimport("matplotlib"))

    # By default, an mpl fig is only displayed in an IJulia notebook if
    # the `fig` is the last object in the cell, or if the user
    # explicitly calls `display(fig)`. With these hooks, we replicate
    # the default behaviour of a python notebook, where figures always
    # show up automatically.
    Main.IJulia.push_postexecute_hook(display_figs)
    Main.IJulia.push_posterror_hook(close_figs)
end

function display_figs()
    for manager in Gcf.get_all_fig_managers()
        fig = manager.canvas.figure
        if !isempty(fig.get_axes())
            display(fig)
        end
        plt.close(fig)
    end
end

function close_figs()
    for manager in Gcf.get_all_fig_managers()
        fig = manager.canvas.figure
        plt.close(fig)
    end
end

end
