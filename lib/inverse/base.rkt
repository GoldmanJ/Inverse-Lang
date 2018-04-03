#lang racket

(require (prefix-in un: racket))
(require (for-syntax syntax/parse))
(require racket/require)

(module reader syntax/module-reader
  inverse/base
  #:read
  read
  #:read-syntax
  read-syntax)

(provide
 lambda-create-invertible
 lambda-auto-invert
 invert
 declare-invertible
 #%module-begin
 #%datum
 #%top
 #%top-interaction
 module
 require
 provide
 prefix-in
 all-from-out
 for-syntax
 define
 λ
 lambda
 only-in
 except-out
 quote
 #%app
 subtract-in
 (rename-out
 ; [apply-func #%app]
  [lambda-create-invertible λ-create-invertible]
  [invfunc-wrap? invertible?]
  [lambda-auto-invert λ-auto-invert]
  [invfunc-wrap-func noinvert]))

(define (invertible-arg? invfunc)
  (λ (arg)
    (define res ((invfunc-wrap-func invfunc) arg))
    (define ret (equal? ((invfunc-wrap-invfunc invfunc) res) arg))
    (displayln ret)
    ret))

(define/contract (apply-check-invfunc invfunc arg)
  (->i ([invfunc invfunc-wrap?]
        [arg (invfunc) (invertible-arg? invfunc)])
       any)
  ((invfunc-wrap-func invfunc) arg))

; A Function is one of:
(struct invfunc-wrap (func invfunc) #:transparent
  #:property prop:procedure apply-check-invfunc
  #;(λ (func arg)
    (define result ((invfunc-wrap-func func) arg))
    (define result-inv ((invfunc-wrap-invfunc func) result))
    (if (not (equal? arg result-inv))
        (error (format (string-append "Not a true invertible function for argument ~a. "
                                      "Applying the inverse to the result yields ~a "
                                      "instead.")
                       arg result-inv))
        result)))

; Create an invertible lambda function
(define-syntax lambda-create-invertible
  (syntax-parser
    [(_ (arg) body invbody)
     #'(invfunc-wrap (un:lambda (arg) body)
                     (un:lambda (arg) invbody))]))

; Create a function composed of other invertible functions
; Automatically construct the inverse
(define-syntax lambda-auto-invert
  (syntax-parser
    [(_ (arg) body)
     #`(lambda-create-invertible
        (arg)
        body
        (construct-inverse arg body arg))]))

(define-for-syntax get-innermost
  (syntax-parser
    [(_ (invertiblefunc funcarg))
     (get-innermost #'funcarg)]
    [(_ funcarg)
     (displayln #'funcarg)
     #'funcarg]))

(define (proc-takes-one-arg func)
  (and (procedure? func) (procedure-arity-includes? func 1)))

(define-for-syntax decl-top-err "Declarations must be at top level")

(define-syntax declare-invertible
  (syntax-parser
    [(_ func1:id func2:id)
     #:fail-unless (equal? (syntax-local-context) 'module) decl-top-err
     #'(if (and (proc-takes-one-arg func1)
                (proc-takes-one-arg func2))
           (begin (set! func1 (invfunc-wrap func1 func2))
                  (set! func2 (invert func1)))
           (error "Cannot declare these invertible"))]
    [(_ func1:id func2)
     #:fail-unless (equal? (syntax-local-context) 'module) decl-top-err
     #'(if (and (proc-takes-one-arg func1)
                (proc-takes-one-arg func2))
           (set! func1 (invfunc-wrap func1 func2))
           (error "Cannot declare these invertible"))]
    [(_ func1 func2:id)
     #:fail-unless (equal? (syntax-local-context) 'module) decl-top-err
     #'(declare-invertible func2 func1)]))
  
; Construct the inverse of the body of a function
; ACCUMULATOR: inner represents the inverses of outer function calls
(define-syntax construct-inverse
  (syntax-parser
    [(_ inner (invertiblefunc ifuncarg) correctarg)
     #:fail-unless (not (contains (local-expand #'invertiblefunc 'expression '()) #'correctarg))
     "Argument to auto-invertible function can only be used in the innermost function call"
     #'(construct-inverse ((invert invertiblefunc) inner) ifuncarg correctarg)]
    [(_ inner arg:id correctarg:id)
     #:fail-unless (free-identifier=? #'arg #'correctarg)
     (format
      "Expected ~a, got ~a. "
      (syntax->datum #'correctarg) (syntax->datum #'arg))
     #'inner]))

(define-for-syntax (contains stx id-to-look-for) 
  (syntax-parse stx
    [(stuff ...) (ormap
                  (lambda (sx) (contains sx id-to-look-for))
                  (syntax->list #'(stuff ...)))]
    [stuff                
     (and (identifier? #'stuff) (free-identifier=? #'stuff id-to-look-for))]))

; Invert an invertible function
(define (invert func)
  (cond
    [(invfunc-wrap? func) (invfunc-wrap (invfunc-wrap-invfunc func)
                                        (invfunc-wrap-func func))]
    [else (error "Not an invertible function")]))