using ArrayLisp
# %%
sexpr"
(import Pkg)
((. Pkg add) (PackageSpec (kw path \"https://github.com/BenLauwens/ThinkJulia.jl\")))
"


# %%
sexpr"
(using ThinkJulia)
"

# %%
sexpr"
(@svg (begin
  (= t (Turtle))
  (for ((i (: 1 4)))
    (forward t 100)
    (turn t -90))))
"

# %%
sexpr"
(function (square t)
  (for ((i (: 1 4)))
    (forward t 100)
    (turn t -90)))

(= t (Turtle))
(@svg (begin
  (square t)))
"
