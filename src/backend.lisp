(in-package #:rag-backend-splade)

;;; Sparse term-weight store. Default encoder is protocol log(1+tf).
;;; Neural SPLADE is :encode-fn (text → alist). We do not ship weights.

(defun make-splade-encoder (&key analyzer encode-fn)
  "SPLADE-shaped encoder. Default = log(1+tf) via ANALYZE. Neural = :ENCODE-FN."
  (rag-protocol:make-simple-sparse-encoder
   :analyzer analyzer :encode-fn encode-fn))

(defclass sparse-store (rag-protocol:rag-vector-store)
  ((docs :initform (make-hash-table :test 'equal) :accessor sparse-store-docs)
   (encoder :initarg :encoder :accessor sparse-store-encoder :initform nil)))

(defun make-sparse-store (&key encoder analyzer encode-fn)
  (make-instance 'sparse-store
                 :encoder (or encoder
                              (make-splade-encoder :analyzer analyzer
                                                   :encode-fn encode-fn))))

(defun use-sparse-store (&rest args &key &allow-other-keys)
  (setf rag-protocol:*rag-store* (apply #'make-sparse-store args)))

(defun %as-list (x)
  (if (listp x) x (list x)))

(defun %encoder (store)
  (or (sparse-store-encoder store)
      (make-splade-encoder)))

(defun %chunk-sparse (store chunk)
  (or (rag-protocol:rag-chunk-sparse chunk)
      (let ((vec (rag-protocol:encode-sparse (%encoder store) chunk)))
        (setf (rag-protocol:rag-chunk-sparse chunk) vec)
        vec)))

(defun %query-sparse (store query)
  (or (rag-protocol:query-sparse query)
      (let ((text (rag-protocol:query-text query)))
        (unless (and text (plusp (length text)))
          (error 'rag-protocol:rag-error
                 :message "sparse query needs text or :sparse"))
        (rag-protocol:encode-sparse (%encoder store) text))))

(defmethod rag-protocol:upsert ((store sparse-store) chunks)
  (dolist (ch (%as-list chunks))
    (unless (rag-protocol:rag-chunk-id ch)
      (error 'rag-protocol:rag-error :message "chunk id required for upsert"))
    (%chunk-sparse store ch)
    (setf (gethash (rag-protocol:rag-chunk-id ch) (sparse-store-docs store)) ch))
  store)

(defmethod rag-protocol:delete-ids ((store sparse-store) ids)
  (let* ((ids (%as-list ids))
         (missing '())
         (deleted '()))
    (dolist (id ids)
      (if (nth-value 1 (gethash id (sparse-store-docs store)))
          (progn
            (remhash id (sparse-store-docs store))
            (push id deleted))
          (push id missing)))
    (setf missing (nreverse missing)
          deleted (nreverse deleted))
    (when missing
      (restart-case
          (error 'rag-protocol:rag-not-found
                 :ids missing
                 :message (format nil "unknown chunk ids: ~s" missing))
        (continue ()
          :report "Skip missing ids"
          (return-from rag-protocol:delete-ids deleted))
        (use-value (value)
          :report "Return a supplied value"
          (return-from rag-protocol:delete-ids value))))
    deleted))

(defmethod rag-protocol:query-store ((store sparse-store) query &key top-k filter)
  (let ((q (%query-sparse store query))
        (hits '()))
    (maphash (lambda (id chunk)
               (declare (ignore id))
               (when (or (null filter) (funcall filter chunk))
                 (let ((score (rag-protocol:sparse-dot
                               q (or (rag-protocol:rag-chunk-sparse chunk) '()))))
                   (when (plusp score)
                     (push (rag-protocol:make-rag-hit :chunk chunk :score score)
                           hits)))))
             (sparse-store-docs store))
    (rag-protocol:rerank (rag-protocol:make-identity-reranker)
                         query hits :top-k (or top-k 5))))
