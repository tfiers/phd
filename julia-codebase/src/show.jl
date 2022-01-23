using Unitful: Quantity, Unitlike, unit, ustrip

#= 
Human friendly text representations of relevant types.

IJulia and the REPL call `show(::IO, ::MIME"text/plain", x)` on objects. 
(which defaults to `show(::IO, x)` -- which is meant for serialising, not humans.
Hence we overload).
=#

# Non-full precision printing of all floats.
Base.show(io::IO, ::MIME"text/plain", x::Float64) =
    show(IOContext(io, :compact => true), x)

# m² instead of m^2
Base.show(io::IO, ::MIME"text/plain", x::Unitlike) =
    show(IOContext(io, :fancy_exponent => true), x)

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
    x::AbstractArray{<:Quantity{NumericType,Dimensions,Units},Ndims},
    toplevel::Bool,
) where {NumericType,Dimensions,Units,Ndims}
    t = typeof(x)
    alias = Base.make_typealias(t)
    arraytype = isnothing(alias) ? nameof(t) : alias[1].name
    #    For Vectors and Matrices, we don't want to use `nameof(t)`, as it returns "Array".
    io = IOContext(io, :fancy_exponent => get(io, :fancy_exponent, true))
    #    `print` doesn't have a MIME argument, so we cannot dispatch to our show(::Unitlike)
    #    above. Hence we need to set the fancy flag here.
    print(io, arraytype, "{", Quantity, "(::", NumericType, ", ", Units(), ")")
    (t <: AbstractVecOrMat && !isnothing(alias)) || print(io, ", ", Ndims)
    #    Don't print Ndims for Vector or Matrix.
    print(io, "}")
end

function Base.show(io::IO, ::MIME"text/plain", x::Signal)
    _show_dims_and_description(io, x)
    println(io, "Signal:\n")
    el = first(x)
    isunitful = (el isa Quantity)
    Base.print_array(io, isunitful ? ustrip(x) : x)
    println(io, "\n")
    printrow(key, val...) = println(io, lpad(key, 9), ": ", val...)
    isunitful && printrow("units", unit(el))
    printrow("duration", duration(x), " (Δt: ", x.Δt, ")")
    printrow("dtype", isunitful ? typeof(el.val) : typeof(el))
end

function Base.summary(io::IO, x::Signal)
    _show_dims_and_description(io, x)
    Base.showarg(io, x, true)
    print(io, ", duration ", duration(x))
end

function _show_dims_and_description(io::IO, x::Signal)
    print(io, Base.dims2string(size(x)), ' ')
    isnothing(x.description) || print(io, '"', x.description, '"', ' ')
end
