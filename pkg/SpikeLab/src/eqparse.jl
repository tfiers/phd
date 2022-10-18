
struct Var
    name::Symbol
    diff::Bool
end

struct Model
    original_eqs   ::Vector{Expr}
    generated_func ::Expr
    f              ::Function
    rhss           ::Vector{Expr}
    vars           ::StructVector{Var}
    params         ::Vector{Symbol}
end

Base.show(io::IO, m::Model) = begin
    println(io, typeof(m))
    println(io, " with variables {", join(m.vars, ", "), "}")
    println(io, " and parameters {", join(m.params, ", "), "}")
end
Base.show(io::IO, x::Var) = print(io, x.name)


macro eqs(ex)
    f, original_eqs, rhss, vars, params = process_eqs!(ex)
    qg = Expr(:quote, f)  # Trick to return an expression from a macro
    return :( Model($original_eqs, $qg, $f, $rhss, $vars, $params) )
end

function process_eqs!(eqs::Expr)
    eqs = striplines(eqs)
    vars, params = get_names(eqs)
    lines = eqs.args
    original_eqs = deepcopy(lines)
    # `unblock`, as `dx/dt = …` makes the rhs a block.
    rhss = [unblock(line.args[2]) for line in lines]
    # Change the left-hand side of each line,
    # from `dx/dt = …` to `diff.x = …`
    for (i, (var, rhs)) in enumerate(zip(vars, rhss))
        buffer = (var.diff) ? :diff : :vars
        lines[i] = :( $(buffer).$(var.name) = $(rhs) )
    end
    # Unpack variables and params at the start
    insert!(lines, 1, :( @unpack ($(vars.name...),) = vars ))
    insert!(lines, 2, :( @unpack ($(params...),)    = params ))
    # Make an anonymous function
    f = :( (diff, vars, params) -> $(lines...) )
    return striplines(f), original_eqs, rhss, vars, params
end

function get_names(eqs::Expr)
    names = SortedSet{Symbol}()
    vars = Var[]
    for line in eqs.args
        @test line.head == :(=)
        lhs, rhs = line.args
        push!(vars, parse_var(lhs))
        record_names(unblock(rhs), names)
    end
    vars = StructVector(vars)
    params = [n for n in names if n ∉ vars.name]
    return vars, params
end

parse_var(lhs::Symbol) = Var(lhs, false)  # I_syn = …
parse_var(lhs::Expr) = begin
    @test lhs.head == :call
    f, dx, dt = lhs.args
    @test f == :/
    @test dt == :dt
    if dx isa Symbol                      # dx/dt = …
        x = string(dx)[2:end] |> Symbol
    else                                  # d(g_syn)/dt = …
        @test dx.head == :call
        f, arg = dx.args
        @test f == :d
        x = arg
    end
    Var(x, true)
end

record_names(x::Expr, out) = begin
    @test x.head == :call
    f, args... = x.args
    for e in args
        record_names(e,out)
    end
end
record_names(x::Symbol, out) = push!(out, x)

# For numeric literals:
record_names(x, out) = nothing
