;;; compile-all.el --- Byte-compile all .el files during Nix build -*- lexical-binding: t; -*-
;;
;; Called via: emacs --batch -L . --script compile-all.el file1.el file2.el ...
;; Files to compile are passed as command-line arguments (command-line-args-left).
;; Each file is compiled independently; errors are logged but non-fatal so that
;; files which cannot be byte-compiled still load as interpreted .el at runtime.

(let ((files command-line-args-left))
  (setq command-line-args-left nil)
  (dolist (f files)
    (condition-case err
      (byte-compile-file f)
      (error (message "[build] %s will load as interpreted .el" f)))))
