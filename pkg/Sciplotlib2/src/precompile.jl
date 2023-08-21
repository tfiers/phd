
function _precompile_()
    @info "Running Sciplotlib._precompile_"
    plot(1:10, hylabel = "Piep")
    # This gets displayed when precompiling in IJulia. But that's fine.
end
