module ArrayLisp

using ReplMaker: initrepl

export expand, parse, SExpr, enable_repl

const KEYWORDS = Set([
    :function,
    :(=),
    :call,
    :macrocall,
    :block,
    :vect,
    :vcat,
    :ref,
    :curly,
    :using,
    :import,
    :(.)
])

struct Atom
    val::Any
end

function Base.show(io::IO, a::Atom)
    write(io, string(a.val))
end

function Base.parse(::Type{Atom}, x::AbstractString)
    val = something(
        tryparse(Int, x),
        tryparse(Float64, x),
        x == "true" ? true : nothing,
        x == "false" ? false : nothing,
        first(x) == '"' && last(x) == '"' ? strip1(x, '"') : nothing,
        first(x) == '\'' && last(x) == '\'' && length(x) == 3 ? strip1(x, '\'') :
            nothing,
        Symbol(x),
    )
    return Atom(val)
end

function strip1(x, char)
    left_ind = 1
    right_ind = lastindex(x)
    if x[left_ind] == char
        left_ind = nextind(x, left_ind)
    end
    if x[right_ind] == char
        right_ind = prevind(x, right_ind)
    end
    return x[left_ind:right_ind]
end

struct SExpr
    terms::Any
end
Base.length(s::SExpr) = length(s.terms)
Base.push!(s::SExpr, x) = push!(s.terms, x)
Base.getindex(s::SExpr, i::Int) = s.terms[i]
Base.lastindex(s::SExpr) = lastindex(s.terms)
Base.iterate(s::SExpr) = iterate(s.terms)
Base.iterate(s::SExpr, i::Int) = iterate(s.terms, i)

function Base.show(io::IO, s::SExpr)
    write(io, "(")
    for (i, e) in enumerate(s.terms)
        show(io, e)
        i < length(s) && write(io, " ")
    end
    write(io, ")")
end

const DELIM_REGEX = r"\s|\(|\)|\[|\]|\{|\}"

function Base.parse(::Type{SExpr}, x::AbstractString)
    s = SExpr([])
    s_stack = [s]
    i = firstindex(x)
    j = i
    while true
        # @show i x[i:j]
        delim = findfirst(DELIM_REGEX, x[i:end])
        delim === nothing && break
        j = last(delim) - 1 + i
        c = x[i:j]
        if c == "("
            push!(s, SExpr([]))
            push!(s_stack, s)
            s = s[end]
            i = nextind(x, j)
            j = i
        elseif c == "["
            push!(s, SExpr(Any[:ref]))
            push!(s_stack, s)
            s = s[end]
            i = nextind(x, j)
            j = i

        elseif c == "{"
            push!(s, SExpr(Any[:curly]))
            push!(s_stack, s)
            s = s[end]
            i = nextind(x, j)
            j = i
        elseif c == ")" || c == "]" || c == "}"
            s = pop!(s_stack)
            i = nextind(x, j)
            j = i
        elseif all(isspace, c)
            i = nextind(x, j)
            j = i
        else
            token_start = i
            token_end = prevind(x, j)
            token = x[token_start:token_end]
            push!(s, parse(Atom, token))
            i = nextind(x, token_end)
            j = i
        end
        i > lastindex(x) && break
    end
    return first(s_stack)
end

expand(x) = x
expand(x::Atom) = x.val
expand(x::SExpr) = expand(x.terms)
expand(x::LineNumberNode) = x

struct ModuleExpr
    module_spec::Any
end

function expand(x::ModuleExpr)
    x_str = expand(x.module_spec) |> string
    leading_dots_end = findfirst(r"[^.]", x_str)
    x_name = Symbol(x_str[last(leading_dots_end):end])
    n_dots = 1 + length(1:(prevind(x_str, first(leading_dots_end))))
    return Expr(vcat(repeat([:(.)], n_dots), [x_name])...)
end

function expand(x::Array)
    @show x
    head = expand(x[1])
    if head ∉ KEYWORDS || (head isa Array && x[1] == :curly)
        # check for macros
        if first(string(head)) == '@'
            return expand(vcat([:macrocall, x[1], LineNumberNode(1, :none)], x[2:end]))
        else
            return expand(vcat([:call], x))
        end
    elseif head === :function
        # (function (f <args>...) <body>...)
        # ->
        # (function (call f <args>...) (block <body>...))
        return Expr(:function, expand(x[2]), Expr(:block, expand.(x[3:end])...))
    elseif head === :(=)
        return Expr(head, expand.(x[2:end])...)
    elseif head === :using || head === :import
        module_exprs = expand.(ModuleExpr.(x[2:end]))
        return Expr(head, module_exprs...)
    elseif head === :(.)
        return Expr(head, expand(x[2]), QuoteNode(expand(x[3])))
    else
        return Expr(head, expand.(x[2:end])...)
    end
end


### REPL functionality
function enable_repl()
    initrepl(
        (x) -> map(eval ∘ eval, parse(SExpr, x));
        prompt_text = "arraylisp> ",
        prompt_color = :blue,
        start_key = ')',
        mode_name = "ArrayLisp_mode",
    )
end


### Testing utilities
macro dump_eval(expr)
    Meta.dump(expr)
    return :(@eval($(expr)))
end

export @sexpr_str
macro sexpr_str(sexpr_str)
    s = parse(SExpr, sexpr_str)
    terms = []
    for si in s
        @show si
        e = si |> expand
        @show e
        push!(terms, :(@eval($(e))))
    end
    return Expr(:block, terms...)
end

end # module
