;;; tangle-group.el --- Tangle a group of org files during Nix build -*- lexical-binding: t; -*-
;;
;; Called via: emacs --batch --script tangle-group.el file1.org file2.org ...
;; Files to tangle are passed as command-line arguments (command-line-args-left).
;; Each file is tangled independently; errors are logged but non-fatal.
;;
;; Two-pass strategy:
;;
;; Pass 1 (nil target): only :tangle yes blocks are included, preserving the
;; author's intent for files that have explicit :tangle yes blocks.
;;
;; Pass 2 (explicit target, if pass 1 produced no output): tangle the bare
;; (no-:tangle-keyword) blocks into target-el.  This handles files whose
;; single main/stitch block has no :tangle keyword -- the historical pattern
;; before the Nix build enforced explicit tangling.  Blocks with :tangle no
;; are always excluded by org-babel regardless of the target argument.
;;
;; If both passes produce no output, a minimal stub .el is written so that
;; init-org-file can always find a .el in the Nix store and only errors on
;; genuine build failures (not on intentionally empty org files).

(require 'org)
(setq org-confirm-babel-evaluate nil)
(let ((files command-line-args-left))
  (setq command-line-args-left nil)
  (dolist (f files)
    (message "[build] Tangling %s" f)
    (let* ((abs-f (expand-file-name f))
           (base (file-name-sans-extension abs-f))
           (target-el (concat base ".el")))
      ;; Pass 1: only :tangle yes blocks (nil target).
      (condition-case err
          (org-babel-tangle-file abs-f nil "emacs-lisp")
        (error (message "[build] Error in pass-1 tangle of %s: %s" f err)))
      ;; Pass 2: if no .el produced yet, include bare blocks via explicit target.
      (unless (file-exists-p target-el)
        (message "[build] No :tangle yes blocks in %s, trying bare blocks" f)
        (condition-case err
            (org-babel-tangle-file abs-f target-el "emacs-lisp")
          (error (message "[build] Error in pass-2 tangle of %s: %s" f err))))
      ;; If still no .el, write a minimal stub so init-org-file does not error.
      (unless (file-exists-p target-el)
        (message "[build] No tangle output for %s, writing stub" f)
        (with-temp-file target-el
          (insert (format ";;; %s.el --- no tangle blocks  -*- lexical-binding: t; -*-\n"
                          (file-name-nondirectory base))))))))
