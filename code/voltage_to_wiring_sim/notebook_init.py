"""
Get going in a Jupyter notebook (or an IPython REPL session), by running:
```
from voltage_to_wiring_sim.notebook_init import *`
```
This preloads packages, configures IPython, and populates the namespace with some useful
objects.
"""

# fmt: off



# Utility class to report what we do in this script

from IPython.display import display_markdown, clear_output
from typing import List

class MarkdownPrinter:
    def __init__(self):
        self.displayed_texts: List[str] = []
    
    def print(self, text: str, append=False):
        if append:
            self.displayed_texts[-1] += text
            clear_output()
            for t in self.displayed_texts:
                display_markdown(t, raw=True)
        else:
            self.displayed_texts.append(text)
            display_markdown(text, raw=True)

md = MarkdownPrinter()


md.print("Importing `np`, `mpl`, `plt`  … ")
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
md.print("✔", append=True)



md.print("Importing package `voltage_to_wiring_sim` as `v` … ")
import voltage_to_wiring_sim as v
md.print("✔", append=True)


from voltage_to_wiring_sim.util import *
from voltage_to_wiring_sim.units import *
md.print("Imported `*` from `v.util` and from `v.units` ✔")


# Bookkeeping, see below.
existing_names = dir()

# Import some commonly used methods and other objects directly into the global namespace
from .neuron_sim import simulate_izh_neuron
from .plot_style import figsize
from .spike_train import generate_Poisson_spike_train
from .synapses import calc_synaptic_conductance
from .time_grid import TimeGrid

# /bookkeeping, and reporting of what's newly imported
new_names = set(dir()) - set(existing_names) - {'existing_names'}
md.print(f"Imported {', '.join([f'`{name}`' for name in new_names])} ✔")


# The following allows you to edit the source code while running a notebook, and then
# use this updated code in the notebook, without having to restart the kernel on every
# code change.
# Note that this isn't foolproof, and kernel restarts may still be required.
from IPython import get_ipython
ipython = get_ipython()
ipython.run_line_magic("reload_ext", "autoreload")
ipython.run_line_magic("autoreload", "2")
# Exclude ourself from autoreloading, to avoid an exponential recursive import monster.
ipython.run_line_magic("aimport", "-voltage_to_wiring_sim.notebook_init")
md.print("Setup autoreload ✔")


# If the last expression of a code cell is eg `product = 3 * 7`, and the cell is run,
# IPython prints nothing, by default. Here, we make it print the result (`21`).
# This avoids having to type an extra line with just `product` to see the result.
# (Such a print can still be suppressed by ending the line with `;`).
from IPython.core.interactiveshell import InteractiveShell
InteractiveShell.ast_node_interactivity = "last_expr_or_assign"


# Double resolution plots (without taking up twice as much screen space).
from IPython.display import set_matplotlib_formats
set_matplotlib_formats('retina')


# Print precision for (floating point) numbers.
def set_np_precision(digits=4):
    # The ".4G" format allows eg `array([1000, 1E+05, 0.111])`
    np.set_printoptions(formatter={
        'float_kind': lambda x: format(x, f'.{digits}G'),
    })

set_np_precision()


# Utility function from the Python standard library.
# Given a function, returns a copy of that function, but with some arguments already
# applied.
from functools import partial
