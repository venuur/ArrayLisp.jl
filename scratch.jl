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

# %%
ArrayLisp.@dump_eval function f(x; y=3, z)
    print("$(x) = ")
    println(y)
end
sexpr"(function (f x (y 3) (z)) (println x y z))"

# %%
ArrayLisp.@dump_eval(f(1, y=2, z=3))
sexpr"(f 1 (kw y 2) (kw z 3))"

# %%

ArrayLisp.@dump_eval(
    for i in 1:4
        println(i)
    end)

sexpr"(for ((i (: 1 4))) (println i))"

ArrayLisp.@dump_eval(
    for i in 1:4, j = 5:8
        println(i, j)
    end)

sexpr"(for ((i (: 1 4)) (j (: 5 8))) (println i j))"

# %%
using ThinkJulia
ArrayLisp.@dump_eval(@svg begin
    t = Turtle()
    for i in 1:4
        forward(t, 100)
        turn(t, -90)
    end
end)

# %%
sexpr"
(@svg (begin
  (= t (Turtle))
  (for ((i (: 1 4)))
    (forward t 100)
    (turn t -90))))
"

# %%
ArrayLisp.@dump_eval(
begin
    """Some documentation"""
    function fab()
        println("Hello")
    end
end
)

sexpr"""
(function
  """"Some documentation"""
  (fab)
  (println "Hello"))
"""
