using ArrayLisp

# From Think Julia Exercise 3-3

# ArrayLisp Version
sexpr"""
(function (dotwice f)
  (f)
  (f))

(function (printspam)
  (println "spam"))

(dotwice printspam)
"""
# Julia equivalent
function dotwice(f)
    f()
    f()
end

function printspam()
    println("spam")
end

dotwice(printspam)
