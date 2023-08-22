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
        f = manager.canvas.figure
        fig = Figure(f)
        isempty(fig) || display(fig)
        # This is faster than calling `display` directly on the python object `f`.
        plt.close(f)
    end
end

function close_figs()
    for manager in Gcf.get_all_fig_managers()
        f = manager.canvas.figure
        plt.close(f)
    end
end



# Fig wrapper, taken from PythonPlot.jl

mutable struct Figure
    o::Py
end

PythonCall.Py(f::Figure) = getfield(f, :o)
PythonCall.pyconvert(::Type{Figure}, o::Py) = Figure(o)
Base.:(==)(f::Figure, g::Figure) = pyconvert(Bool, Py(f) == Py(g))
Base.isequal(f::Figure, g::Figure) = isequal(Py(f), Py(g))
Base.hash(f::Figure, h::UInt) = hash(Py(f), h)
Base.Docs.doc(f::Figure) = Base.Docs.Text(pyconvert(String, Py(f).__doc__))

# Note: using `Union{Symbol,String}` produces ambiguity.
Base.getproperty(f::Figure, s::Symbol) = getproperty(Py(f), s)
Base.getproperty(f::Figure, s::AbstractString) = getproperty(f, Symbol(s))
Base.setproperty!(f::Figure, s::Symbol, x) = setproperty!(Py(f), s, x)
Base.setproperty!(f::Figure, s::AbstractString, x) = setproperty!(f, Symbol(s), x)
Base.hasproperty(f::Figure, s::Symbol) = pyhasattr(Py(f), s)
Base.propertynames(f::Figure) = propertynames(Py(f))

Base.isempty(f::Figure) = isempty(f.get_axes())

Base.show(io::IO, m::MIME"image/png", f::Figure) =
    f.canvas.print_figure(io, format="png", bbox_inches="tight")
    # We omit the `_showable(m, f)` check.

Base.showable(m::MIME"image/png", f::Figure) = !isempty(f)
# We omit the `&& haskey(PyDict{Any,Any}(f.canvas.get_supported_filetypes()), "png")` check.

end
