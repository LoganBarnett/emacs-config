;;; compile-org-sources.el --- Byte-compile org-tangled .el files -*- lexical-binding: t; -*-
;;
;; Like compile-all.el but pre-loads doom macros (map!, add-hook!, etc.)
;; before compilation so that org files using these macros compile correctly.
;;
;; Called via:
;;   EMACSLOADPATH=<lisp>:<general>/share/emacs/site-lisp: \
;;     emacs --batch --script compile-org-sources.el file1.el file2.el ...
;;
;; The EMACSLOADPATH must include the lisp/ source dir (for doom-lib.el and
;; doom-keybinds.el) and general's site-lisp dir (for general.el, which
;; doom-keybinds requires).  The trailing colon in EMACSLOADPATH preserves the
;; default Emacs load-path so built-in libraries remain available.
;;
;; If doom-keybinds cannot be loaded (e.g. missing deps), compilation proceeds
;; anyway -- files using map! will fall back to loading as interpreted .el at
;; runtime (via init-org-file's (load ... nil t) which prefers .elc but falls
;; back to .el when only .el is present).

;; Pre-load macros from external packages so they are available at compile time.
;; If a macro is NOT defined at compile time, the byte-compiler treats macro
;; calls as function calls, producing invalid bytecode that fails at runtime
;; with (invalid-function macro-name) or (void-variable arg-name).
;;
;; Load order matters:
;;   1. subr-x        - string-remove-suffix used by doom-lib macros
;;   2. doom-constants - doom--system-macos-p used by doom-keybinds
;;   3. doom-lib      - add-hook!, cmd!, etc. (macros used in doom-keybinds)
;;   4. doom-keybinds - map! (the primary keybinding macro)
;;   5. evil-macros   - evil-define-operator, evil-define-motion, etc.
;;
;; EMACSLOADPATH must include:
;;   - lisp/ source dir (for doom-*.el)
;;   - general's elpa versioned subdir (for general.el, required by doom-keybinds)
;;   - evil's elpa versioned subdir (for evil-macros.el and its deps)
;;
;; If any require fails, ignore-errors skips it; affected files will load as
;; interpreted .el at runtime (init-org-file's `load' prefers .elc over .el).
(ignore-errors (require 'subr-x))
(ignore-errors (require 'doom-constants))
(ignore-errors (require 'doom-lib))
(ignore-errors (require 'doom-keybinds))
(ignore-errors (require 'evil-macros))

;; on-doom / on-spacemacs are defined in lisp/init.el which is not a
;; loadable library (it's installed as default.el and removed from
;; emacs-config-lisp before compilation).  Define compile-time stubs so
;; org files that use these macros compile correctly:
;;
;;   (on-doom body...) expands to nil when doom-version is not bound.
;;   (on-spacemacs body...) expands to nil when spacemacs-version is not bound.
;;
;; Since doom-version / spacemacs-version are NOT bound at compile time (nor at
;; runtime in this config), the stubs produce the same expansion as the real
;; macros would: nil.  The compiled bytecode never executes the bodies.
(unless (macrop 'on-doom)
  (defmacro on-doom (&rest _) nil))
(unless (macrop 'on-spacemacs)
  (defmacro on-spacemacs (&rest _) nil))

(let ((files command-line-args-left))
  (setq command-line-args-left nil)
  (dolist (f files)
    (condition-case err
      (byte-compile-file f)
      (error (message "[build] %s will load as interpreted .el" f)))))
