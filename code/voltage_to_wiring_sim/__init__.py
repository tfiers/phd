import unyt

# Import all submodules into the package namespace, so we have easy access via
# tab-completion. (Note that `from . import *` doesn't work for this purpose).
from . import (
    cortical_RS_neuron,
    neuron_sim,
    plot_style,
    presynaptic_spike_train,
    time_grid,
    util,
)


# Automatically add units to axes.
unyt.matplotlib_support()

