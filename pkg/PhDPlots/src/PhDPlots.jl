module PhDPlots

using Units
using Sciplotlib

using Sciplotlib: PythonPlot.@L_str
export @L_str

const color_exc = C0
const color_inh = C1
const color_both = Colors.Gray(0.6)
const color_unconn = Colors.Gray(0.3)

export color_exc, color_inh, color_both, color_unconn


# Based on the memoir-class latex pdf in ../thesis/.
# In inches.
const paperwidth = const pw = 8.3
const marginwidth = const mw = 0.28 * paperwidth  # From totex/Settings.tex → \marginwidth
const maintextwidth = const mtw = 324 / 72        # From latexmk output → Text width
const margin = 47.8 / 72
const contentwidth = const cw = paperwidth - 2margin

export paperwidth, pw, marginwidth, mw, maintextwidth, mtw, contentwidth, cw


last_figpath = nothing

function savefig_phd(name, fig = nothing; filetype="pdf")
    if isnothing(fig)
        if isempty(plt.get_fignums())
            print("No figure in gcf. Supply one as 2nd arg")
            return
        end
        fig = plt.gcf()
    end
    path = "../thesis/figs/$name.$filetype"
    fig.savefig(path)
    global last_figpath = path
    print("Saved at `$path`")
end
export savefig_phd


include("signal.jl")
export plotsig, plotSTA, linspace


using IJulia
using PythonCall
include("nb_retina_fix.jl")


end # module PhDPlots
