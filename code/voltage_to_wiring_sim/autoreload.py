from importlib import reload

from . import (
    cortical_RS_neuron,
    neuron_sim,
    plot_style,
    presynaptic_spike_train,
    time_grid,
    util,
)


def load_ipython_extension(ipython):
    ipython.events.register("pre_execute", reload_code)


def reload_code():
    for mod in (
        cortical_RS_neuron,
        neuron_sim,
        presynaptic_spike_train,
        time_grid,
        util,
        plot_style,
    ):
        reload(mod)
