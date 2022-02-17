using WhatIsHappening, Suppressor, Pkg

# Filter out annoying deprecation warning on PyPlot import. Can be removed and replaced by
# `prettify_logging_in_notebook!()` once this is released: https://github.com/JuliaPy/PyCall.jl/pull/950
using LoggingExtras
hasdepwarning(log) = log.message isa String && startswith(log.message, "`vendor()` is deprecated")
global_logger(ActiveFilteredLogger(!hasdepwarning, get_pretty_notebook_logger()))

hidden_stderr_info = @capture_err begin
    @withfeedback using Revise
    @withfeedback import Distributions
    @withfeedback import PyPlot
    @withfeedback import DataFrames, PrettyTables
    @withfeedback import MyToolbox
    @withfeedback using VoltageToMap
end

# Cannot be reexported from a package (i.e. MyToolbox / VoltageToMap), as it then clashes
# with Base's `/`. But `include`ing it, as is done with this file, does work.
using FilePathsBase: /
