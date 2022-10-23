
"""
    LogNormal(; median, g)

Alternative parametrization of the log-normal distribution, using the real median ``m`` and
the _geometric standard deviation_, ``g``. The relationship with the standard
parametrization -- which uses the mean ``\\mu`` and the standard deviation ``\\sigma`` of
the log-transformed, unitless, normal distribution -- is as folows:
- ``m = e^\\mu · \\mathrm{unit}``
- ``g = e^\\sigma``

As a consequence of this relationship, ~two-thirds of the distribution lies within
``[ m/g, m·g ]``, and ~95% lies within ``[ m/g², m·g²]``.

`unit` is by default `oneunit(median)`. I.e, if `median = 5mV`, then `unit = 1mV`, and if
`median = 4`, then `unit = 1`. `unit` can also be explicitly specified, as an extra keyword
argument.

Unfortunately, Distributions.jl has no unit support ([yet](https://github.com/JuliaStats/Distributions.jl/issues/1413)).
To obtain correct results from this distribution, add the same `unit` manually to the
appropriate methods:
- `rand(d) * mV`
- `mean(d) * mV`
etc.
"""
LogNormal(; median, g, unit = oneunit(median)) =

    Distributions.LogNormal(log(median/unit), log(g))

# If you want to add other parametrizations:
# LogNormal(; kw...), and then a switch/match stmt.
