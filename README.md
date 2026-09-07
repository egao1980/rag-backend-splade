# rag-backend-splade

Sparse term-weight store for [`rag-protocol`](https://github.com/egao1980/rag-protocol) **0.1.2+** (`encode-sparse` / `rag-chunk-sparse`).

Default encoder is **`log(1+tf)`** on `analyze` tokens — SPLADE-shaped, not neural SPLADE-v3. Pass `:encode-fn` (text → alist of `(term . weight)`) for a real model. We do not ship BERT weights.

```lisp
(asdf:load-system "rag-backend-splade")

(let ((store (rag-backend-splade:make-sparse-store)))
  (stack-rag:upsert store
                    (stack-rag:make-rag-chunk :id "a" :text "cat cat mat"))
  (stack-rag:query-store store "cat mat" :top-k 5))

;; Neural hook
(rag-backend-splade:make-sparse-store
 :encode-fn (lambda (text) (your-splade-model text)))
```

Score is inner product (`sparse-dot`). Zero-score docs are omitted.

Part of [cl-stack](https://github.com/egao1980/cl-stack).

## License

MIT — see [LICENSE](LICENSE).
