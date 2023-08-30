
using PythonPlot

pygui(false)
fig, ax = pyplot.subplots()
plot([1,2,1])
PythonPlot.display_figs()

# Might have to call PythonPlot.__init__() in nb
