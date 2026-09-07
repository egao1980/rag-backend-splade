(defsystem "rag-backend-splade"
  :version "0.1.0"
  :description "Sparse term-weight store + encoder for rag-protocol (SPLADE-shaped)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("rag-protocol")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "backend"))
  :in-order-to ((test-op (test-op "rag-backend-splade/tests"))))

(defsystem "rag-backend-splade/tests"
  :depends-on ("rag-backend-splade" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "backend-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
