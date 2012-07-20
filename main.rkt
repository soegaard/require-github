#lang racket

;;;
;;; TODO: Currently only the latest version of a particular branch 
;;;       can be downloaded automatically.

(module download-github racket
  (require net/url
           (planet dherman/zip:2:1/unzip))
  
  (provide download-github)
  
  (define (github-zip-saveas-filename user repo branch)
    (format "~a-~a-~a.zip" user repo branch))
  
  (define (github-zip-url user repo #:branch [branch "master"])
    ; github offers the latest version of a repository as a zip-download
    ; TODO: Handle specific commit ids.
    (string->url (format "https://github.com/~a/~a/zipball/~a" user repo branch)))
  
  (define (download-github 
           user repo 
           #:branch    [branch "master"] 
           #:commit-id [commit-id #f]
           #:exists    [exists-mode 'replace])
    (define url (github-zip-url user repo #:branch branch))
    (define zip-filename (github-zip-saveas-filename user repo branch))
    (unless (directory-exists? "tmp")
      (make-directory "tmp"))
    (unless (directory-exists? "repos")
      (make-directory "repos"))
    (define tmp-path (build-path (current-directory) "tmp"))
    ; make sure tmp/ is empty
    (when (directory-exists? tmp-path)
      (delete-directory/files "tmp"))    
    (unless (directory-exists? tmp-path)
      (make-directory "tmp"))
    (parameterize ([current-directory tmp-path])
      ; download repository as zip-file
      (with-output-to-file zip-filename
        (λ () (copy-port (get-pure-port url #:redirections 1)
                         (current-output-port)))
        #:exists exists-mode)
      (unless (file-exists? zip-filename)
        (error 'download-github "Unable to download ~a from GitHub." zip-filename))
      ; unzip it
      (with-input-from-file zip-filename
        (λ () (unzip)))
      ; find directory holding repository
      (define repo-dir
        (let ()
          (define non-zip-files
            (filter (λ (n) (not (equal? (filename-extension n) #"zip")))
                    (directory-list #:build? #f)))
          (when (empty? non-zip-files)
            (error 'download-github
                   (format "After unpacking ~a no directory was found." zip-filename)))
          (first non-zip-files)))
      ; move it to cached repositories
      (define cached-repo-dir (build-path ".." "repos" repo-dir))
      (when (directory-exists? cached-repo-dir)
        (delete-directory/files cached-repo-dir))
      (copy-directory/files repo-dir cached-repo-dir)
      (delete-directory/files repo-dir)
      ; return the new directory
      (values repo-dir cached-repo-dir))))
  
(module require-github racket
  (require (for-syntax (submod ".." download-github))
           racket/require-syntax)
  (provide github)
  
  (define-require-syntax github
    (λ (stx)
      (syntax-case stx ()
        [(_ user repo branch commit-id path)
         (let ()
           (let-values 
               ([(user repo branch commit-id path)
                 (apply values (map syntax->datum (list #'user #'repo #'branch #'commit-id #'path)))])
             (define dir-str (format "repos/~a-~a-~a" user repo commit-id))
             (define filename-str (format "~a/~a" dir-str path))
             (unless (directory-exists? (build-path (current-directory) dir-str))
               (displayln (format "Downloading from GitHub." ))
               (download-github user repo #:branch branch #:commit-id commit-id)
               (displayln "Done."))
             (datum->syntax stx `(file ,filename-str))))]))))

(module* test racket
  (require (submod ".." require-github))
  (require (github soegaard this-and-that master faf74b7 "split-between.rkt"))
  (displayln "Running tests in the test submodule.")
  (split-between (λ (x y) (not (= x y))) '(1 1 2 3 3 4 5 5)))

;(require rackunit)
;(check-equal? (url->string
;               (github-zip-url 'soegaard 'this-and-that))
;              "https://github.com/soegaard/this-and-that/zipball/master")
;(check-equal? (github-zip-saveas-filename 'soegaard 'this-and-that 'master)
;             "soegaard-this-and-that-master.zip")

;(download-github 'soegaard 'this-and-that)
