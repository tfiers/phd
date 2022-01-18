convertColorantstoRGBAtuples(dictlike) =
    Dict(k => (v isa Colorant) ? toRGBAtuple(v) : v for (k, v) in dictlike)

"""Convert a Color to an `(r,g,b,a)` tuple ∈ [0,1]⁴, as accepted by Matplotlib."""
toRGBAtuple(c) = toRGBAtuple(RGBA(c))
toRGBAtuple(c::RGBA) = (c.r, c.g, c.b, c.alpha)

mplcolors = C0, C1, C2, C3, C4, C5, C6, C7, C9, C10 = parse.(RGB,
    ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
     "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf" ]
)

"""
Mix a color with white. `original` specifies how much is left of the original color.
(`0`: output is pure white. `1`: output is the original color).
Equivalent (visually) to setting alpha = `original` on a white background.
"""
lighten(c::C, original = 0.8) where {C<:Color} = C(mix(RGB(c), RGB(1, 1, 1), 1 - original))
#   White goes last, because colors can't have negative channels (`b - a` in `mix`), even
#   in ColorVectorSpace.

"""
Mix a color with black. `original` specifies how much is left of the original color.
(`0`: output is pure black. `1`: output is the original color).
"""
darken(c::C, original = 0.8) where {C<:Color} = C(mix(RGB(0, 0, 0), RGB(c), original))

"""Linearly interpolate ("lerp") between `a` (`t = 0`) and `b` (`t = 1`)."""
mix(a, b, t=0.5) = a + t * (b - a)
