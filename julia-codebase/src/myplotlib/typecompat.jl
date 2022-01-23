as_mpl_type(x::Colorant)                   = toRGBAtuple(x)
as_mpl_type(x::AbstractArray{<: Quantity}) = ustrip(x)
as_mpl_type(x::Quantity)                   = ustrip(x)
as_mpl_type(x::Units)                      = ustrip(x)
as_mpl_type(x)                             = x

mapvals(f, dictlike) = [k => f(v) for (k, v) in dictlike]
