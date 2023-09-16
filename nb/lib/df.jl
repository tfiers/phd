using WithFeedback

@withfb using DataFrames

ENV["DATAFRAMES_ROWS"]    = 10   # Default: 25
ENV["DATAFRAMES_COLUMNS"] = 100  # Default: 100

# See https://dataframes.juliadata.org/stable/lib/functions/#Base.show
# and https://ronisbr.github.io/PrettyTables.jl/stable/man/usage/
showsimple(
    df::DataFrame;
    summary         = false,
    eltypes         = false,
    show_row_number = false,
    alignment       = :l,                      # for text, not numbers
    kw...
) = show(df; summary, eltypes, show_row_number, alignment, kw...)

nothing;
