using WhatIsHappening, Pkg

# Filter out annoying deprecation warning on PyPlot import. Can be removed and replaced by
# `prettify_logging_in_notebook!()` once this is released: https://github.com/JuliaPy/PyCall.jl/pull/950
using LoggingExtras
hasdepwarning(log) = startswith(log.message, "`vendor()` is deprecated")
global_logger(ActiveFilteredLogger(!hasdepwarning, get_pretty_notebook_logger()))

@withfeedback Pkg.resolve()

@withfeedback using Revise
@withfeedback import Distributions
@withfeedback import PyPlot
@withfeedback import DataFrames, PrettyTables
@withfeedback import MyToolbox
@withfeedback using VoltageToMap

# Cannot be reexported from a package (i.e. MyToolbox / VoltageToMap), as it then clashes
# with Base's `/`. `include`ing it does work.
using FilePathsBase: /
