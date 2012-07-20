require-github
==============

This module implements (require (github ...)) syntax.

Example:

The user "soegaard" has a repository "this-and-that" on GitHub:

   https://github.com/soegaard/this-and-that
   
The latest commit-id (read: version) is "faf74b7".
The file "split-between.rkt" provides a function split-between.
   
    > (require (github soegaard this-and-that master faf74b7 "split-between.rkt"))
    [Downloading from GitHub.]
    > (split-between (λ (x y) (not (= x y))) '(1 1 2 3 3 4 5 5))
    '((1 1) (2) (3 3) (4) (5 5))

The form automatically downloads the latest version of the repository
from GitHub. It is stored in a cache. The second time a given version
is required it is not downloaded again.

It is possible to use *head* as the commit-id in order to get
the latest version from GitHub. Using an explicit commit-id is faster 
though. When using *head* a http request to GitHub is needed to
establish the commit-id of the head.
