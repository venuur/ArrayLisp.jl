(function (checkfermat a b c n)
  (if (&& (== (+ (^ a n) (^ b n)) (^ c n)) (> n 2))
      (println "Holy smokes, Fermat was wrong!")
      (println "No, that doesn't work.")))

(checkfermat 1 2 3 4)
(checkfermat 1 2 3 2)
