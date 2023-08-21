
sciplotlib_style = Dict(
    "axes.spines.top"      => false,
    "axes.spines.right"    => false,
    "axes.grid"            => true,
    "axes.axisbelow"       => true,  # Grid _below_ patches (such as histogram bars), not on top.
    "axes.grid.which"      => "both",
    "grid.linewidth"       => 0.5,        # These are for major grid. Minor grid styling
    "grid.color"           => "#E7E7E7",  # is set in `set!`.

    "xtick.direction"      => "in",
    "ytick.direction"      => "in",
    "xtick.labelsize"      => "small", # Default is "medium"
    "ytick.labelsize"      => "small", # idem
    "legend.fontsize"      => "small", # Default is "medium"
    "axes.titlesize"       => "medium",
    "axes.labelsize"       => 9,
    "xaxis.labellocation"  => "right",
    "axes.titlelocation"   => "right",

    "legend.borderpad"     => 0.6,
    "legend.borderaxespad" => 0.2,

    "lines.solid_capstyle" => "round",

    "figure.facecolor"     => "white",
    "figure.figsize"       => (4, 2.4),
    "figure.dpi"           => 200,
    "savefig.dpi"          => "figure",
    "savefig.bbox"         => "tight",

    "axes.autolimit_mode"  => "round_numbers",  # Default: "data"
    "axes.xmargin"         => 0,
    "axes.ymargin"         => 0,
)

"""
Reset Matplotlib's style to `rcParams_original`, then apply the supplied dictionary of
`rcParams` settings. Call without arguments to reset to Matplotlib's defaults. To reset to
Sciplotlib's defaults, pass `sciplotlib_style`.

The initial reset is so that you can experiment with parameters; namely add and then remove
entries. Without the reset, once a parameter was set it would stay set.
"""
function set_mpl_style!(updatedRcParams = nothing)
    pymerge!(rcParams, rcParams_original)
    isnothing(updatedRcParams) || pymerge!(rcParams, updatedRcParams)
    return rcParams
end

function pymerge!(base, new)
    for (key, val) in new
        base[key] = val
    end
end

pymerge!(base, new::Py) = pymerge!(base, py_dictlike_to_Dict(new))

py_dictlike_to_Dict(x) = Dict(key => x[key] for key in x)
# `pyconvert(Dict, mpl.rcParams)` no work: it's some dict superclass,
# and you get a "fatal inheritance error: could not merge MROs".
