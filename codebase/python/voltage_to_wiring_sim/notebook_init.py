"""
Get going in a Jupyter notebook (or an IPython REPL session), by running:
```
from voltage_to_wiring_sim.support.notebook_init import *`
```
"""


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd

print("Imported `np`, `mpl`, `plt`, `sns`, `pd`")
# ────────────────────────────────────────────────────────────────────────────────────╯


#


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
import voltage_to_wiring_sim as v

print("Imported codebase (`voltage_to_wiring_sim`) as `v`")
# ────────────────────────────────────────────────────────────────────────────────────╯


#


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
from voltage_to_wiring_sim.support.units import *

print("Imported `*` from `v.support.units`")
# ────────────────────────────────────────────────────────────────────────────────────╯


#


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# The following allows you to edit the source code while running a notebook, and then
# use this updated code in the notebook, without having to restart the kernel on every
# code change.
# Note that this isn't foolproof, and kernel restarts may still be required.

from IPython import get_ipython

ipython = get_ipython()
if ipython:  # Allow running as a script too (i.e. not in a notebook or REPL).
    ipython.run_line_magic("reload_ext", "autoreload")
    ipython.run_line_magic("autoreload", "2")
    # Exclude ourself from autoreloading, to avoid an exponential recursive import
    # monster.
    ipython.run_line_magic("aimport", "-voltage_to_wiring_sim.notebook_init")
    print("Setup autoreload")
# ────────────────────────────────────────────────────────────────────────────────────╯


#


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# If the last expression of a code cell is eg `product = 3 * 7`, and the cell is run,
# IPython prints nothing, by default. Here, we make it print the result (`21`).
# This avoids having to type an extra line with just `product` to see the result.
# (Prints can still be suppressed by ending the line with `;`).

from IPython.core.interactiveshell import InteractiveShell

InteractiveShell.ast_node_interactivity = "last_expr_or_assign"
# ────────────────────────────────────────────────────────────────────────────────────╯


#


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# Double resolution plots (without taking up twice as much screen space).

from IPython.display import set_matplotlib_formats

set_matplotlib_formats("retina")
# ────────────────────────────────────────────────────────────────────────────────────╯


#


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# Print precision for (floating point) numbers.


def set_print_precision(digits=4):
    # The ".4G" format allows eg `array([1000, 1E+05, 0.111])`
    number_format = f".{digits}G"
    # Print precision for plain Python numbers..
    if ipython:
        ipython.run_line_magic("precision", "%" + number_format)
    # ..and for NumPy.
    np.set_printoptions(
        formatter={
            "float_kind": lambda x: format(x, number_format),
        }
    )


set_print_precision()
# ────────────────────────────────────────────────────────────────────────────────────╯


#


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# Utility function from the Python standard library.
# Given a function, returns a copy of that function, but with some arguments already
# applied.

from functools import partial

# ────────────────────────────────────────────────────────────────────────────────────╯


#


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# Labels on lines themselves, instead of in separate legend box.
# Quirks:
# - Set limits *before* labelling lines (issue 36).
#   Also, an xlim or ylim call is required for rotations to be correct, even if just
#   `ax.set_xlim()`.
# - The `lines` argument to `label_lines` is only used to get axis. It's not used to
#   choose which lines will be labelled -- all lines are always labbeled.

from labellines import labelLine as label_line, labelLines as label_lines

# ────────────────────────────────────────────────────────────────────────────────────╯


# Reassignment trick to stop PyCharm from complaining about unused imports:
mpl, plt, sns, pd = mpl, plt, sns, pd
v = v
Quantity = Quantity
partial = partial
label_line, label_lines = label_line, label_lines
