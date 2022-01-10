#= 
Human friendly text representations of relevant types.

IJulia and the REPL call `show(::IO, ::MIME"text/plain", x)` on objects. 
(which defaults to `show(::IO, x)` -- which is meant for serialising, not humans.
Hence we overload).
=#

# Non-full precision printing of all floats.
Base.show(io::IO, ::MIME"text/plain", x::Float64) =
    show(with_defaults(io, :compact => true), x)

# m² instead of m^2
Base.show(io::IO, ::MIME"text/plain", x::Unitful.Unitlike) =
    Base.@invoke show(
        with_defaults(io, :fancy_exponent => true)::IO,
        x::Unitful.Unitlike
    )

function Base.show(io::IO, ::MIME"text/plain", x::AbstractArray{<:Quantity})
    summary(io, x)
    println(io, ":")
    Base.print_array(io, ustrip(x))
end

#=
Show summary of the type of a homogeneous unitful array.
`showarg(::Array)` is called by `summary(::Array)`, which in turn is called by 
`show(::Array)`. In the string "300-element Vector{Eltype}: …", `showarg` is responsible 
for the part "Vector{ElType}".
=#
function Base.showarg(
    io::IO,
    x::AbstractArray{<:Quantity{NumericType,Dimensions,Units},},
    _toplevel::Bool
) where {NumericType,Dimensions,Units}
    t = typeof(x)
    alias = Base.make_typealias(t)
    arraytype = isnothing(alias) ? nameof(t) : alias[1].name
    # For Vectors and Matrices, we don't want to use `nameof(t)`, as it returns "Array" .
    print(io, arraytype, "{", Quantity, "(::", NumericType, ", ", Units(), ")}")
end

"""Add `IOContext` settings to an `IO` object if they have not been yet set."""
function with_defaults(io::IO, defaults::Pair...)::IO
    settings = merge(Dict(defaults), IOContext(io).dict)
    IOContext(io, settings...)
end
