import unyt

# Automatically add units and signal names to axes.
unyt.matplotlib_support()

from unyt import unyt_array, unyt_quantity, Unit

# This is slightly verbose. Shorter would be: `from unyt import pF, V, ..`. But alas
# this shorter version doesn't allow for auto-imports in PyCharm. (All these names are
# generated dynamically, so PyCharm can't find them).
pF = Unit("pF")
V = Unit("V")
mV = Unit("mV")
A = Unit("A")
pA = Unit("pA")
ms = Unit("ms")
s = Unit("s")
min = Unit("min")

try:
    unyt.define_unit("S", (1, "A/V"), prefixable=True)
except:
    # Siemens was already defined -- i.e. it's not the first time this script has run.
    pass

S = Unit("S")
nS = Unit("nS")
