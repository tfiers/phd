using WhatIsHappening, Suppressor

# Filter out annoying deprecation warning on PyPlot import. Can be removed and replaced by
# `prettify_logging_in_notebook!()` once this is released: https://github.com/JuliaPy/PyCall.jl/pull/950
using LoggingExtras
hasdepwarning(log) = log.message isa String && startswith(log.message, "`vendor()` is deprecated")
global_logger(ActiveFilteredLogger(!hasdepwarning, get_pretty_notebook_logger()))

hidden_stderr_info = @capture_err begin
    @withfeedback using Revise
    @withfeedback import Distributions
    @withfeedback import MyToolbox
    @withfeedback using VoltageToMap
end

# This cannot be reexported from a package (e.g. from MyToolbox), as it then clashes with
# Base's `/`. But `include`ing it, as is done with this file, does work.
using FilePathsBase: /
