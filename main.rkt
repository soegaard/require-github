#lang racket

(module download-github racket
  (require net/url
           (planet dherman/zip:2:1/unzip)
           racket/runtime-path)
  (provide download-github
           clone-github
           the-repos-dir
           the-tmp-dir)
  
  (define-runtime-path the-repos-dir "repos")
  (define-runtime-path the-tmp-dir   "tmp")
  
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
    ; make sure repos/ exists
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
      (values repo-dir cached-repo-dir)))
  
  (define (clone user repo)
    (define url (format (format "http://github.com/~a/~a.git" user repo)))
    (system (string-append "git clone " url)))
  
  (define (checkout commit-id)
    (system (format "git checkout ~a" commit-id)))
  
  (define (clone-github 
           user repo 
           #:branch    [branch "master"] 
           #:commit-id [commit-id #f]
           #:exists    [exists-mode 'replace])
    ; make sure repos/ exists
    (unless (directory-exists? "repos")
      (make-directory "repos"))
    ; make sure tmp/ is empty
    (when (directory-exists? the-tmp-dir)
      (delete-directory/files "tmp"))    
    (unless (directory-exists? the-tmp-dir)
      (make-directory "tmp"))
    (let ([original-dir (current-directory)])
      (current-directory the-tmp-dir)
      ; clone repository using git clone
      (clone user repo)
      ; checkout the given commit-id
      (when (equal? "head" (format "~a" commit-id))
        (set! commit-id #f))
      (define repo-dir-in-tmp (build-path the-tmp-dir (format "~a" repo)))
      (when commit-id
        (current-directory repo-dir-in-tmp)
        (checkout commit-id))
      (unless commit-id
        (error "todo: find commit-id for head"))
      ; rename and move the repository to cached repos
      (define name (format "~a-~a-~a" user repo commit-id))
      
      (define repo-dir-in-repos (build-path the-repos-dir (format "~a" name)))
      (rename-file-or-directory repo-dir-in-tmp repo-dir-in-repos)
      (current-directory original-dir)
      (values name repo-dir-in-repos))))

(module require-github racket
  (require racket/require-syntax
           (for-syntax (submod ".." download-github)
                       (planet neil/json-parsing:2:0)
                       net/url))
  (provide github)
  
  (begin-for-syntax
    (define (get-commit-id-for-head user repo [branch "master"])
      (define url 
        (string->url
         (format "https://api.github.com/repos/~a/~a/git/refs/heads/~a"
                 user repo branch)))
      (cond
        [(json->sjson (get-pure-port url))
         => (λ (tree)
              (cond [(hash-ref tree 'object)
                     => (λ (obj) 
                          (cond [(hash-ref obj 'sha)
                                 => (λ (s) (substring s 0 7))]
                                [else #f]))]
                    [else #f]))]
        [else #f])))
  
  (define-require-syntax github
    (λ (stx)
      (syntax-case stx (head)
        [(_ user repo head path)
         (datum->syntax 
          stx (syntax->datum #'(github user repo master head path)))]
        [(_ user repo commit-id path)
         (datum->syntax 
          stx (syntax->datum #'(github user repo master commit-id path)))]
        [(_ user repo branch head path)
         (let-values 
             ([(user repo branch)
               (apply values (map syntax->datum (list #'user #'repo #'branch)))])
           (with-syntax 
               ([(user repo branch commit-id)
                 (list user repo branch 
                       (get-commit-id-for-head user repo branch))])
             (datum->syntax 
              stx (syntax->datum #'(github user repo branch commit-id path)))))]
        [(_ user repo branch commit-id path)
         (let-values 
             ([(user repo branch commit-id path)
               (apply values (map syntax->datum (list #'user #'repo #'branch #'commit-id #'path)))])
           (define dir-str (format "repos/~a-~a-~a" user repo commit-id))
           (define filename-str (format "~a/~a" dir-str path))
           (unless (directory-exists? (build-path (current-directory) dir-str))
             (displayln (format "Downloading from GitHub." ))
             (clone-github user repo #:branch branch #:commit-id commit-id)
             ;(download-github user repo #:branch branch #:commit-id commit-id)
             (displayln "Done."))
           (datum->syntax stx `(file ,filename-str)))]
        [else
         (raise-syntax-error 
          #f "Expected (github <user> <repo> <optional-branch> <commit-id or head> <path>)" stx)]))))

(module* test racket
  (require (submod ".." require-github))
  ; Explicit commit-id is fast. 
  ; (no http request necessary if the the repository is cached)
  (require (github soegaard this-and-that master faf74b7 "split-between.rkt"))
  ; the old version does not provide anything 
  ; (but it prints values when required)
  (require (github soegaard this-and-that master a9442d37a1db11b14c3f0a6bb91766baa811232f 
                   "split-between.rkt"))
  ; Using prefixes one can compare two versions for debugging purposes!
  
  (displayln "Running tests in the test submodule.")
  (split-between (λ (x y) (not (= x y))) '(1 1 2 3 3 4 5 5))
  ; Use head as commit-id to get the latest version.
  ; This is a bit slow, since a http request to GitHub is neccessary.
  ; This also shows that the branch defaults to "master".
  (require (github samth array.rkt head "main.rkt"))
  (build-array 10 values))

;(require rackunit)
;(check-equal? (url->string
;                 (github-zip-url 'soegaard 'this-and-that))
;                "https://github.com/soegaard/this-and-that/zipball/master")
;(check-equal? (github-zip-saveas-filename 'soegaard 'this-and-that 'master)
;                "soegaard-this-and-that-master.zip")
