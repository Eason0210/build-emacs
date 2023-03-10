;;; emacs-git-version.el --- record git commit of Emacs -*- lexical-binding: t -*-

;; Author: Eason Huang <aqua0210@gmail.com>
;; Keywords: emacs
;; Created: 2023-01-10
;; Last changed: 2023-01-10 21:38:00

;; This file is NOT part of GNU Emacs.

;;; Commentary:
;;


;;; Code:

(defconst emacs-version-git-commit "@@GIT_COMMIT@@"
  "String giving the git sha1 from which this Emacs was built.

SHA1 of git commit that was used to compile this version of Emacs.
The source used to compile Emacs are taken from Savannah's git
repository at `https://git.savannah.gnu.org/git/emacs.git' or
`git://git.savannah.gnu.org/emacs.git'.

You can also access the Emacs source repository from the website:
`https://git.savannah.gnu.org/cgit/emacs.git'.

See both `https://emacswiki.org/emacs/EmacsFromGit' and
`https://savannah.gnu.org/projects/emacs' for further information.")

(provide 'emacs-git-version)

;;; emacs-git-version.el ends here
