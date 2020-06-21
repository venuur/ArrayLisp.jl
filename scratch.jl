using Pkg; Pkg.activate(".")
using Revise
using ArrayLisp
# %%
ArrayLisp.@dump_eval function add(x, y)
    println("x is $x and y is $y")

    # Functions return the value of their last statement
    x + y
end

sexpr"(function (add x y) (println x y) (+ x y))"

# %%
ArrayLisp.@dump_eval(x = 3)
sexpr"(= x 1)"

# %%
ArrayLisp.@dump_eval(
    begin
        b = [4, 5, 6] # => 3-element Array{Int64,1}: [4, 5, 6]
        b = [4; 5; 6] # => 3-element Array{Int64,1}: [4, 5, 6]
        b[1]    # => 4
        b[end]  # => 6
    end
)
sexpr"""
(= b (vect 4 5 6))
(= b (vcat 4 5 6))
[b 1]
[b end]
"""

# %%
x = 1
ArrayLisp.@dump_eval(@show(x))
sexpr"(@show x)"

# %%
ArrayLisp.@dump_eval(b = Int8[4, 5, 6])
sexpr"(= b [Any 4 5 6])"

# %%
ArrayLisp.@dump_eval(begin
    struct A{T}
        x::T
    end
    A(x) = A{Int}(x)
    x = A{Float64}(3.0)
    y = A(4)
end)
sexpr"({Array Int} undef 2 3)"


# %%
ArrayLisp.@dump_eval(using Dates, Pkg)
sexpr"(using Dates ..Pkg)"

# %%
ArrayLisp.@dump_eval(import Dates, Pkg)
sexpr"(import Dates ..Pkg)"

# %%
ArrayLisp.@dump_eval(x = Dates.Date(2019, 6, 12))
sexpr"(import Dates ..Pkg)"

# %%
ArrayLisp.@dump_eval(begin
    struct A{T}
        x::T
    end
    A(x) = A{Int}(x)
    y = A{A{Int}}(A(1))
    y.x.x
end)
sexpr"(= y ({A {A Int}} (A 2))) (. (. y x) x)"
