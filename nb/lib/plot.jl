
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


function plotROC(sweep; ax = newax(), title="")
    AUCs = calc_AUROCs(sweep)
    AUCs = (; (k => round(AUCs[k], digits=2) for k in keys(AUCs))...)
    plot(sweep.FPR, sweep.TPRₑ; ax, label="Excitatory   $(AUCs.AUCₑ)", color=color_exc)
    plot(sweep.FPR, sweep.TPRᵢ; ax, label="Inhibitory   $(AUCs.AUCᵢ)", color=color_inh)
    plot(sweep.FPR, sweep.TPR ; ax, label="Both         $(AUCs.AUC)", color=color_both)
    set(ax, aspect="equal", xlabel="Non-inputs wrongly detected (FPR)", ylabel="Real inputs detected (TPR)",
        xtype=:fraction, ytype=:fraction, title=(title, :pad=>12, :loc=>"right"))
    font = Dict("family"=>"monospace", "size"=>6)
    legend(ax, borderaxespad=1,     title="Input type   AUC ", loc="lower right",
            alignment="right", markerfirst=true, prop=font);
    # Using the same `font` dict for `title_fontproperties` does not apply the size (bug in Julia-Python, somehow)
    ax.legend_.get_title().set(family="monospace", size=6, weight="bold");
    return ax
end

newax() = ((fig, ax) = plt.subplots(); ax)



nothing;
