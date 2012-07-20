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

Currently only the latest version can be downloaded automatically.

This module do not require the user to have the command line 
program "git" installed. The source is downloaded as a zip-file
and unpacked using dherman's unzip package from PLaneT.

