
(module gif mzscheme
  (require (lib "class.ss")
           (lib "file.ss")
           (lib "mred.ss" "mred")
           (lib "gifwrite.ss" "net")
           (lib "contract.ss")
           (lib "kw.ss")
           (lib "etc.ss"))

  (provide write-gif
           write-animated-gif)

  (define (force-bm bm) (if (procedure? bm) (bm) bm))

  (define (split-bytes b len offset)
    (if (= offset (bytes-length b))
        null
        (cons (subbytes b offset (+ offset len))
              (split-bytes b len (+ offset len)))))

  (define (write-gifs bms delay filename one-at-a-time?)
    (let* ([init (force-bm (car bms))]
           [w (send init get-width)]
           [h (send init get-height)])
      (let ([argb-thunks
             (map (lambda (bm)
                    (lambda ()
                      (let ([bm (force-bm bm)]
                            [argb (make-bytes (* w h 4) 255)])
                        (send bm get-argb-pixels 0 0 w h argb)
                        (let ([mask (send bm get-loaded-mask)])
                          (when mask
                            (send mask get-argb-pixels 0 0 w h argb #t)))
                        argb)))
                  (cons init (cdr bms)))])
        (if one-at-a-time?
            ;; Quantize individually, and stream the images through
            (call-with-output-file*
             filename
             (lambda (p)
               (let* ([gif (gif-start p w h 0 #f)])
                 (when delay
                   (gif-add-loop-control gif 0))
                 (for-each (lambda (argb-thunk)
                             (let-values ([(pixels colormap transparent)
                                           (quantize (argb-thunk))])
                               (when (or transparent delay)
                                 (gif-add-control gif 'any #f (or delay 0) transparent))
                               (gif-add-image gif 0 0 w h #f colormap pixels)))
                           argb-thunks)
                 (gif-end gif))))
            ;; Build images and quantize all at once:
            (let-values ([(pixels colormap transparent)
                          (quantize (apply bytes-append (map (lambda (t) (t)) argb-thunks)))])
              (call-with-output-file*
               filename
               (lambda (p)
                 (let* ([gif (gif-start p w h 0 colormap)])
                   (when delay
                     (gif-add-loop-control gif 0))
                   (for-each (lambda (pixels)
                               (when (or transparent delay)
                                 (gif-add-control gif 'any #f (or delay 0) transparent))
                               (gif-add-image gif 0 0 w h #f #f pixels))
                             (split-bytes pixels (* w h) 0))
                   (gif-end gif)))))))))

  (define (write-gif bm filename)
    (write-gifs (list bm) #f filename #f))

  (define/kw (write-animated-gif bms delay filename #:key [one-at-a-time? #f])
    (write-gifs bms delay filename one-at-a-time?))

  )