#lang s-exp inverse

(provide invert-result)

; [X Y Z] [X -> [Y <-> Z]] -> [Z <-> Y]
(define (invert-result func)
  (λ (input)
    (invert (func input))))
