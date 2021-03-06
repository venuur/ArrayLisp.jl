module ArrayLisp

using ReplMaker: initrepl

export expand, parse, SExpr, enable_repl, include_lisp, format, format_file
export @sexpr_str


const KEYWORDS = Set([
    :function,
    :parameters,
    :kw,
    :(=),
    :call,
    :macrocall,
    :block,
    :begin,
    :vect,
    :vcat,
    :ref,
    :curly,
    :using,
    :import,
    :(.),
    :for,
    :if,
    :elseif,
    :else,
    :(&&),
    :(||),
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
Base.getindex(s::SExpr, i) = s.terms[i]
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

const DEFAULT_FORMAT_LINELENGTH = 92
const DEFAULT_FORMAT_INDENT = 0

function format(
    io::IO,
    s::SExpr;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    head = expand(s[1])
    if head === :function
        format_function(io, s; linelength = linelength, indent = indent)
    elseif head === :for
        format_for(io, s; linelength = linelength, indent = indent)
    elseif head === :begin
        format_begin(io, s; linelength = linelength, indent = indent)
    else
        format_call(io, s; linelength = linelength, indent = indent)
    end
end

function format(
    s::SExpr;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    format(stdout, s; linelength = linelength, indent = indent)
end

function format(
    io::IO,
    s::Atom;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    show(io, s)
end

function format(
    s::Atom;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    format(stdout, s; linelength = linelength, indent = indent)
end

function format_call(
    io::IO,
    s::SExpr;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    _format(io, s; indent = indent) =
        format(io, s; linelength = linelength, indent = indent)

    operator_str = let io = IOBuffer()
        print(io, "(")
        _format(io, s[1])
        length(s) > 1 && print(io, " ")
        String(take!(io))
    end
    print(io, operator_str)
    length(s) == 1 && (print(io, ")"); return)

    operands_str = let io = IOBuffer()
        for (i, expr) in enumerate(s[2:end])
            i > 1 && print(io, " ")
            _format(io, expr)
        end
        print(io, ")")
        String(take!(io))
    end
    max_operand_linelength = maximum(length.(split(operands_str, "\n")))
    if max_operand_linelength + indent <= linelength
        print(io, operands_str)
    else
        let indent = indent + length(operator_str)
            for (i, expr) in enumerate(s[2:end])
                i > 1 && print(io, "\n", repeat(" ", indent))
                _format(io, expr)
            end
        end
        print(io, ")")
    end
end

function format_function(
    io::IO,
    s::SExpr;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    _format(io, s; indent = indent) =
        format(io, s; linelength = linelength, indent = indent)

    func_start_str = let io = IOBuffer()
        print(io, "(")
        _format(io, s[1])
        print(io, " ")
        _format(io, s[2])
        String(take!(io))
    end
    if length(func_start_str) <= linelength - indent
        print(io, func_start_str)
    else
        func_start_str = let io = IOBuffer()
            print(io, "(")
            _format(io, s[1])
            print(io, " (")
            func_formals = s[2]
            _format(io, func_formals[1])
            String(take!(io))
        end
        if length(func_formals) > 1
            let indent = indent + length(func_start_str)
                for v in func_formals[2:end]
                    print(io, "\n")
                    print(io, repeat(" ", indent))
                    _format(io, v; indent = indent)
                end
            end
        end
        print(io, ")")
    end
    let indent = indent + 2
        for expr in s[3:end]
            print(io, "\n")
            print(io, repeat(" ", indent))
            _format(io, expr; indent = indent)
        end
    end
    print(io, ")")
end

function format_for(
    io::IO,
    s::SExpr;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    _format(io, s; indent = indent) =
        format(io, s; linelength = linelength, indent = indent)

    for_head = let io = IOBuffer()
        print(io, "(")
        _format(io, s[1])
        print(io, " (")
        String(take!(io))
    end
    print(io, for_head)
    let indent = indent + length(for_head)
        for (i, iter_expr) in enumerate(s[2])
            i > 1 && print(io, "\n", repeat(" ", indent))
            _format(io, iter_expr)
        end
    end
    print(io, ")")
    let indent = indent + 2
        for body_expr in s[3:end]
            print(io, "\n", repeat(" ", indent))
            _format(io, body_expr)
        end
    end
    print(io, ")")
end

function format_begin(
    io::IO,
    s::SExpr;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    _format(io, s; indent = indent) =
        format(io, s; linelength = linelength, indent = indent)

    print(io, "(")
    _format(io, s[1])
    let indent = indent + 2
        for body_expr in s[2:end]
            print(io, "\n", repeat(" ", indent))
            _format(io, body_expr)
        end
    end
    print(io, ")")
end

function format_file(
    io::IO,
    filename;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    for expr in parse(SExpr, read(filename, String))
        format(expr; linelength = linelength, indent = indent)
        println()
        println()
    end
end

function format_file(
    filename;
    linelength = DEFAULT_FORMAT_LINELENGTH,
    indent = DEFAULT_FORMAT_INDENT,
)
    format_file(stdout, filename; linelength = linelength, indent = indent)
end

const DELIM_REGEX = r"\s|\(|\)|\[|\]|\{|\}|;"

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
        elseif c == ";"
            next_newline = findfirst("\n", x[i:end])
            i = last(next_newline) - 1 + i
            j = i
        else
            token_start = i
            if x[token_start] == '"'
                quote_end = findfirst(r"[^\\]\"", x[nextind(x, i):end])
                if quote_end === nothing
                    throw(ArgumentError("Unterminated string found at index $(i)"))
                end
                token_end = last(quote_end)
            end
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

struct FunctionExpr
    function_spec::Any
end

function expand(x::FunctionExpr)
    # (function (f <args>...) <body>...)
    # <args> <- <pos_arg> | <kw_arg>
    # <pos_arg> <- <symbol>
    # <kw_arg> <- (<symbol> [<default>])
    # ->
    # (function (call f (parameters [<kw_args>...]) <pos_args>...) (block <body>...))
    function_name = expand(x.function_spec[2][1])
    pos_args = []
    kw_args = []
    for a in x.function_spec[2][2:end]
        if a isa Atom
            push!(pos_args, expand(a))
        elseif a isa SExpr
            ae = a.terms
            if length(ae) == 1
                push!(kw_args, (ae[1], nothing))
            elseif length(ae) == 2
                push!(kw_args, (ae[1], ae[2]))
            else
                throw(ArgumentError("Keyword argument must have form `(var)` or `(var default)`, got $(x.function_spec)"))
            end
        end
    end

    if length(kw_args) > 0
        @show function_name pos_args kw_args
        function_def = Expr(
            :call,
            function_name,
            Expr(
                :parameters,
                [
                    kw[2] !== nothing ? Expr(:kw, expand.(kw)...) : expand(kw[1])
                    for kw in kw_args
                ]...,
            ),
            pos_args...,
        )
    else
        function_def = Expr(:call, function_name, pos_args...)
    end

    body = expand.(x.function_spec[3:end])

    return Expr(:function, function_def, Expr(:block, body...))
end

function expand(x::Array)
    @show x
    head = expand(x[1])
    @show head
    if head ∉ KEYWORDS || (head isa Array && x[1] == :curly)
        # check for macros
        if first(string(head)) == '@'
            return expand(vcat([:macrocall, x[1], LineNumberNode(1, :none)], x[2:end]))
        else
            return expand(vcat([:call], x))
        end
    elseif head === :function
        return expand(FunctionExpr(x))
    elseif head === :begin
        return Expr(:block, expand.(x[2:end])...)
    elseif head === :(=)
        return Expr(head, expand.(x[2:end])...)
    elseif head === :using || head === :import
        module_exprs = expand.(ModuleExpr.(x[2:end]))
        return Expr(head, module_exprs...)
    elseif head === :(.)
        return Expr(head, expand(x[2]), QuoteNode(expand(x[3])))
    elseif head === :for
        # (for (<iter>...) <body>)
        # <iter> <- (<symbol> <expr>)
        # ->
        # (for (block (= <iter>...)) (block <body>)))
        iteration_expr = [Expr(:(=), expand.(it)...) for it in x[2]]
        @show iteration_expr
        body = Expr(:block, expand.(x[3:end])...)
        if length(iteration_expr) == 1
            return Expr(head, iteration_expr[1], body)
        else
            return Expr(head, Expr(:block, iteration_expr...), body)
        end
    elseif head === :if
        if length(x) == 3
            # (if <pred> <value>)
            # ->
            # (if <pred> (block <value>))
            return Expr(head, expand(x[2]), Expr(:block, expand(x[3])))
        elseif length(x) == 4
            # (if <pred> <true-value> <false-value>)
            # ->
            # (if <pred> (block <true-value>) (block <false-value>))
            return Expr(
                head,
                expand(x[2]),
                Expr(:block, expand(x[3])),
                Expr(:block, expand(x[4])),
            )
        elseif length(x) > 4
            # (if <pred> <body>... [elseif <pred> <body>...]... [else <body>...])
            # ->
            # (if <pred> (block <body>...)
            #     ([elseif <pred>]/else (block <body>) [elseif/else...]))
            i_else = findall(a -> a === :else, x)
            i_elseif = findall(a -> a === :elseif, x)
            if length(i_else) == 1
                tail_i = i_else[1]
                expr = Expr(:block, expand.(x[tail_i+1:end])...)
            elseif length(i_elseif) >= 1
                tail_i = pop!(i_elseif)
                expr = Expr(
                    :elseif,
                    Expr(:block, expand(x[tail_i+1])),
                    Expr(:block, expand.(x[tail_i+2:end])...),
                )
            else
                # No elseif or else blocks.
                return Expr(
                    :if,
                    Expr(:block, expand(x[2])),
                    Expr(:block, expand.(x[3:end])...),
                )
            end
            # Now walk backward for any elseif statements.
            while length(i_elseif) >= 1
                i = pop!(i_elseif)
                expr = Expr(
                    :elseif,
                    Expr(:block, expand(x[i+1])),
                    Expr(:block, expand.(x[i+2:tail_i-1])...),
                    expr,
                )
                tail_i = i
            end
            #Finally add the initial if block
            return Expr(
                :if,
                Expr(:block, expand(x[2])),
                Expr(:block, expand.(x[3:tail_i-1])...),
                expr,
            )
        end
    else
        return Expr(head, expand.(x[2:end])...)
    end
end


### REPL functionality
function enable_repl()
    initrepl(
        (x) -> map(eval ∘ expand, parse(SExpr, x));
        prompt_text = "arraylisp> ",
        prompt_color = :blue,
        start_key = ')',
        mode_name = "ArrayLisp_mode",
    )
end

function _sexpr_str(sexpr_str)
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

macro sexpr_str(sexpr_str)
    return _sexpr_str(sexpr_str)
end

function include_lisp(mod, names...)
    for name in names
        s = read(name, String)
        println(s)
        mod.eval(_sexpr_str(s))
    end
end

### Testing utilities
macro dump_eval(expr)
    Meta.dump(expr)
    return :(@eval($(expr)))
end

end # module
