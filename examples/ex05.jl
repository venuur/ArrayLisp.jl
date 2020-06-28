(function (main)
  (for ((line (eachline "data/words.txt")))
    (if (> (length line) 20)
        (println line))))

(main)
