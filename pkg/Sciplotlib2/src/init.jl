"""
Matplotlib's style settings [1].

- [1] https://matplotlib.org/stable/tutorials/introductory/customizing.html#the-default-matplotlibrc-file
"""
rcParams = nothing

"""
A copy of the initial `mpl.rcParams`. Note that we do not use `mpl.rcParamsDefault` or
`mpl.rcParamsOrig`, as these are different to what's actually used by default (e.g. in a
Jupyter notebook).
"""
rcParams_original = nothing
# We can't do PythonCall.pynew() here (and then in init: `pycopy!(rcParams_original, rcParams)`),
# when using Sciplotlib as a dependency of a downstream package:
# "You must not interact with Python during module precompilation"
# (https://cjdoris.github.io/PythonCall.jl/stable/pythoncall/#Writing-packages-which-depend-on-PythonCall)

function __init__()
    if !is_precompiling()
        global rcParams = mpl.rcParams
        global rcParams_original = deepcopy(py_dictlike_to_Dict(rcParams))
        set_mpl_style!(sciplotlib_style)
    end
end

is_precompiling() = ccall(:jl_generating_output, Cint, ()) == 1
