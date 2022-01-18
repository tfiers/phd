export Signal, duration

using Unitful: Time

const Optional = Union{T,Nothing} where {T}


"""An array where one dimension represents evenly spaced samples in time."""
struct Signal{T,N} <: AbstractArray{T,N}
    
    data::AbstractArray{T,N}
    
    """Time between two samples. Reciprocal of sampling frequency."""
    Δt::Time
    
    """Optional description of the values in `data`. E.g. "Membrane potential"."""
    description::Optional{AbstractString}
    
    """Time dimension of the array. Defaults to `1`."""
    tdim::Int
end

# Allow positional & keyword combos, as in Python. non-todo: macro this.
Signal(d, Δt, description; tdim=1) = Signal(d, Δt, description, tdim)
Signal(d, Δt; description=nothing, tdim=1) = Signal(d, Δt, description, tdim)
Signal(d; Δt, description=nothing, tdim=1) = Signal(d, Δt, description, tdim)

Base.size(x::Signal) = size(x.data)
Base.getindex(x::Signal{T,N}, I::Vararg{Int, N}) where {T,N} = x.data[I...]
Base.setindex!(x::Signal{T,N}, v, I::Vararg{Int, N}) where {T,N} = (x.data[I...] = v)

duration(x::Signal) = size(x, x.tdim) * x.Δt
