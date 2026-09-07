(in-package #:rag-backend-splade/tests)

(defun %chunk (id text &optional sparse)
  (rag-protocol:make-rag-chunk :id id :document-id "d"
                               :text text :sparse sparse))

(deftest default-encoder-ranks
  (let ((store (rag-backend-splade:make-sparse-store)))
    (rag-protocol:upsert store
                         (list (%chunk "a" "cat cat mat")
                               (%chunk "b" "cat")))
    (let ((hits (rag-protocol:query-store store "cat mat" :top-k 2)))
      (ok (= 2 (length hits)))
      (ok (equal "a" (rag-protocol:rag-chunk-id
                      (rag-protocol:rag-hit-chunk (first hits)))))
      (ok (> (rag-protocol:rag-hit-score (first hits))
             (rag-protocol:rag-hit-score (second hits)))))))

(deftest encode-fn-neural-hook
  (let ((store (rag-backend-splade:make-sparse-store
                :encode-fn (lambda (text)
                             (if (search "apple" text)
                                 '(("apple" . 2.0) ("fruit" . 0.5))
                                 '(("other" . 1.0)))))))
    (rag-protocol:upsert store
                         (list (%chunk "a" "red apple")
                               (%chunk "b" "blue car")))
    (let ((hits (rag-protocol:query-store store "apple" :top-k 2)))
      (ok (equal "a" (rag-protocol:rag-chunk-id
                      (rag-protocol:rag-hit-chunk (first hits)))))
      (ok (= 1 (length hits))))))

(deftest precomputed-sparse
  (let ((store (rag-backend-splade:make-sparse-store)))
    (rag-protocol:upsert store
                         (%chunk "a" "ignored" '(("zzz" . 1.0))))
    (let ((hits (rag-protocol:query-store
                 store (rag-protocol:make-rag-query :sparse '(("zzz" . 1.0)))
                 :top-k 1)))
      (ok (equal "a" (rag-protocol:rag-chunk-id
                      (rag-protocol:rag-hit-chunk (first hits))))))))

(deftest delete-and-missing
  (let ((store (rag-backend-splade:make-sparse-store)))
    (rag-protocol:upsert store (%chunk "a" "alpha"))
    (ok (equal '("a") (rag-protocol:delete-ids store "a")))
    (ok (signals (rag-protocol:delete-ids store "a")
                 'rag-protocol:rag-not-found))))

(deftest query-needs-text-or-sparse
  (let ((store (rag-backend-splade:make-sparse-store)))
    (rag-protocol:upsert store (%chunk "a" "alpha"))
    (ok (signals (rag-protocol:query-store store #(1.0 0.0) :top-k 1)
                 'rag-protocol:rag-error))))

(deftest use-sparse-binds
  (let ((rag-protocol:*rag-store* nil))
    (rag-backend-splade:use-sparse-store)
    (ok (typep rag-protocol:*rag-store* 'rag-backend-splade:sparse-store))
    (setf rag-protocol:*rag-store* nil)))
