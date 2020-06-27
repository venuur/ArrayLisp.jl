(import Pkg)
;((. Pkg add) (PackageSpec (kw path "https://github.com/BenLauwens/ThinkJulia.jl")))

(using ThinkJulia)


(function (square t)
  (for ((i (: 1 4)))
    (forward t 100)
    (turn t -90)))

(= t (Turtle))
(@svg (begin
  (square t)))
