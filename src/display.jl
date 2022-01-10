#= 
Human friendly text representations of relevant types.

IJulia and the REPL call `show(::IO, ::MIME"text/plain", x)` on objects. 
(which defaults to `show(::IO, x)` -- which is meant for serialising, not humans.
Hence we overload).
=#

# Non-full precision printing of all floats.
function Base.show(io, ::MIME"text/plain", x::Float64)
    get(io, :compact, false) || (io = IOContext(io, :compact => true))
    show(io, x)
end

# m² instead of m^2
function Base.show(io, ::MIME"text/plain", x::Unitful.Unitlike)
    get(io, :fancy_exponent, false) || (io = IOContext(io, :fancy_exponent => true))
    show(io, x)
end

function Base.show(io, ::MIME"text/plain", x::AbstractArray{<:Quantity})
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
function Base.showarg(io, x::AbstractArray{<:Quantity{T,D,U},N}, toplevel) where {T,D,U,N}
    t = typeof(x)
    alias = Base.make_typealias(t)
    arraytype = isnothing(alias) ? nameof(t) : alias[1].name
    # For Vectors and Matrices, we don't want to use `nameof(t)`, as it returns "Array" .
    print(io, arraytype, "{", Quantity, "(::", T, ", ", U(), ")")
    (t <: AbstractVecOrMat && !isnothing(alias)) || print(io, ", ", N)
    print(io, "}")
end



function Base.show(io, ::MIME"text/plain", x::Signal)
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

function Base.summary(io, x::Signal)
    _show_dims_and_description(io, x)
    Base.showarg(io, x, true)
    print(io, ", duration ", duration(x))
end

function _show_dims_and_description(io, x::Signal)
    print(io, Base.dims2string(size(x)), ' ')
    isnothing(x.description) || print(io, '"', x.description, '"', ' ')
end
