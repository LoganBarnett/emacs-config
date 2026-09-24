;;; lint-elisp.el --- Lint Emacs Lisp files  -*- lexical-binding: t; -*-

;;; Commentary:

;; Called by lint-elisp.sh:
;;
;;   emacs --batch --no-init-file --load lint-elisp.el FILE...
;;
;; Each FILE is byte-compiled with the output discarded, so the compiler's
;; warnings print without leaving .elc files behind, and then run through
;; checkdoc for docstring and comment style.  Every finding is printed as
;; FILE:LINE: MESSAGE and counted; the exit status is 1 when there were any,
;; 2 when no files were given.
;;
;; Files are compiled in one session, in the order given, so a file's
;; `eval-when-compile' requires stay loaded for the files after it -- the
;; same behaviour as nix/compile-all.el, and the reason lint findings can
;; depend on which files were passed together.

;;; Code:

(require 'bytecomp)
(require 'checkdoc)

(defvar lint-elisp--findings 0
  "How many compiler warnings and checkdoc issues have been reported.")

(defvar lint-elisp--scratch-dir (make-temp-file "lint-elisp-" t)
  "Directory that receives the discarded byte-compiler output.")

(defun lint-elisp--compile-log-count ()
  "Return how many warnings and errors the byte-compiler has logged so far."
  (if (get-buffer byte-compile-log-buffer)
      (with-current-buffer byte-compile-log-buffer
        (save-excursion
          (goto-char (point-min))
          (let ((n 0))
            (while (re-search-forward ": \\(Warning\\|Error\\): " nil t)
              (setq n (1+ n)))
            n)))
    0))

(defun lint-elisp--byte-compile (file)
  "Byte-compile FILE into the scratch directory, counting what it logs.
In batch mode the compiler already prints each warning to stderr as it
finds it, so nothing is echoed here."
  (let ((byte-compile-dest-file-function
         (lambda (source)
           (expand-file-name (concat (file-name-nondirectory source) "c")
                             lint-elisp--scratch-dir)))
        (before (lint-elisp--compile-log-count)))
    (byte-compile-file file)
    (setq lint-elisp--findings
          (+ lint-elisp--findings
             (- (lint-elisp--compile-log-count) before)))))

(defun lint-elisp--checkdoc (file)
  "Run checkdoc over FILE, printing and counting each issue it reports."
  (let ((checkdoc-autofix-flag 'never)
        (checkdoc-diagnostic-buffer "*lint-elisp checkdoc*")
        (checkdoc-pending-errors nil))
    (with-current-buffer (find-file-noselect file)
      (checkdoc-current-buffer t))
    (when checkdoc-pending-errors
      (with-current-buffer checkdoc-diagnostic-buffer
        (goto-char (point-min))
        (while (re-search-forward "^\\(.+:[0-9]+: .*\\)$" nil t)
          (message "%s" (match-string 1))
          (setq lint-elisp--findings (1+ lint-elisp--findings)))
        ;; checkdoc leaves its buffer read-only once it has written to it.
        (let ((inhibit-read-only t))
          (erase-buffer))))))

(let ((files command-line-args-left))
  ;; Consume the file arguments so Emacs does not also visit them.
  (setq command-line-args-left nil)
  (unless files
    (message "lint-elisp.el: no files given")
    (kill-emacs 2))
  ;; The config's files require each other, so lisp/ must be on the load
  ;; path for their `eval-when-compile' requires to resolve.
  (add-to-list 'load-path
               (expand-file-name "lisp" (file-name-directory load-file-name)))
  (dolist (file files)
    (message "==== %s" file)
    ;; A file that throws (a top-level form the compiler cannot evaluate,
    ;; code checkdoc cannot parse) must not take the rest of the run with
    ;; it: report it as a finding and move on, as nix/compile-all.el does.
    (condition-case err
        (progn
          (lint-elisp--byte-compile (expand-file-name file))
          (lint-elisp--checkdoc (expand-file-name file)))
      (error
       (message "%s:0: Error: lint aborted for this file: %S" file err)
       (setq lint-elisp--findings (1+ lint-elisp--findings)))))
  (delete-directory lint-elisp--scratch-dir t)
  (message "lint-elisp: %d finding(s) in %d file(s)"
           lint-elisp--findings (length files))
  (kill-emacs (if (> lint-elisp--findings 0) 1 0)))

;;; lint-elisp.el ends here
