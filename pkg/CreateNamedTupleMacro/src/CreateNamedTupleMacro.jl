module CreateNamedTupleMacro

export @NT

"""
    @NT begin … end

Creates a `NamedTuple` containing the variables defined in the given
block.

With this macro, functions that output a large namedtuple (with values
that depend on each other) become more maintainable and a tad
shorter/DRYer.

Concretely,

    f(x) = @NT begin
        a = x + 3
        b = a * x
    end

is rewritten as

    f(x) = begin
        a = x + 3
        b = a * x
        (; a, b)
    end

This is similar to using `NamedTuple(Base.@locals)` (with a `let`
block), but that breaks type inference; this macro does not.
"""
macro NT(block)
    @assert block.head == :block
    lines = [e for e in block.args if !isa(e, LineNumberNode)]
    names = mapreduce(get_assigned_names, vcat, lines)
    push!(block.args, :( (; $(names...)) ))  # Add namedtuple creation as last line to block.
    return esc(block)  # `esc` needed, to avoid gensym variables, so type inference is possible.
end

function get_assigned_names(line::Expr)
    if line.head != :(=)
        return no_names  # Don't get names from lines like :( y .= 3 ) or :( println(x) ).
        # We also silently ignore line-wide macros here (like `@unpack x, y = …`).
        # Also missed: if-else, `function` defs;
        # more: https://docs.julialang.org/en/v1/devdocs/ast/
    end
    lhs, rhs = line.args
    if (lhs isa Expr) && (lhs.head == :ref)
        return no_names  # Don't get names from lines like :( A[1] = 3 )
    else
        return get_names(lhs)
    end
end
const no_names = Symbol[]

get_names(e::Symbol) = [e]  # :( x = f(y) )
get_names(e::Expr) =        # :( x,y = f(z) )
    if e.head == :tuple
        # Recursion needed in :( a,(b,c) = [1,[2,3]] ) case
        mapreduce(get_names, vcat, e.args)
    elseif e.head == :...
        # `b` in :( a, b... = [1,2,3] )
        get_names(only(e.args))
    elseif e.head == :(::)
        # :( x::Float64 = 8 )
        [e.args[2]]
    else
        error("Unrecognized left-hand-side expression: $e")
    end

end
