;;; compile-all.el --- Byte-compile all .el files during Nix build -*- lexical-binding: t; -*-
;;
;; Called via: emacs --batch --script compile-all.el file1.el file2.el ...
;; Files to compile are passed as command-line arguments (command-line-args-left).
;; Each file is compiled independently; errors are logged but non-fatal so that
;; files which cannot be byte-compiled still load as interpreted .el at runtime.

;; The files under compilation require each other, so their directory must be
;; on `load-path', and it must happen here: `--script' silently discards `-L'
;; flags (Emacs 30.2), so the command line cannot provide it.
(add-to-list 'load-path default-directory)

;; Dependency packages (packageRequires in emacs-package.nix) arrive as
;; elpa-style package directories via EMACSLOADPATH, and only package
;; activation puts each package's own subdirectory on `load-path'.
(require 'package)
(package-initialize)

(let ((files command-line-args-left))
  (setq command-line-args-left nil)
  (dolist (f files)
    (condition-case err
      (byte-compile-file f)
      (error (message "[build] %s will load as interpreted .el" f)))))
