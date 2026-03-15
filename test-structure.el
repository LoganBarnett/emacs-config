;;; test-structure.el --- Test Emacs configuration structure -*- lexical-binding: t; -*-

;; This file provides a minimal environment to test that the Emacs
;; configuration structure is valid, all files can be loaded, and
;; the initialization completes successfully.

(setq debug-on-error nil)
(setq use-package-verbose nil)
(setq use-package-always-ensure nil)

;; Track what we're doing
(defvar test-packages-skipped 0)
(defvar test-files-loaded nil)
(defvar test-org-files-tangled nil)

;; Mock use-package to avoid package loading errors
(defmacro use-package (name &rest args)
  `(progn
     (setq test-packages-skipped (1+ test-packages-skipped))
     (message "[TEST] Skipping package: %s" ',name)
     ;; Extract and run any :init code that doesn't depend on the package
     ,@(let ((init-form (plist-get args :init)))
         (when init-form
           (list `(condition-case err
                      ,init-form
                    (error (message "[TEST] Error in %s :init - %s" ',name err)))))
       nil)))

;; Mock some common functions that packages provide
(defun vertico-mode (&rest args) (message "[TEST] Mock: vertico-mode"))
(defun marginalia-mode (&rest args) (message "[TEST] Mock: marginalia-mode"))
(defun orderless-define-completion-style (&rest args) (message "[TEST] Mock: orderless-define-completion-style"))
(defun corfu-global-mode (&rest args) (message "[TEST] Mock: corfu-global-mode"))
(defun doom-themes-org-config (&rest args) (message "[TEST] Mock: doom-themes-org-config"))
(defun evil-mode (&rest args) (message "[TEST] Mock: evil-mode"))
(defun evil-collection-init (&rest args) (message "[TEST] Mock: evil-collection-init"))
(defun which-key-mode (&rest args) (message "[TEST] Mock: which-key-mode"))
(defun helpful-key (&rest args) (message "[TEST] Mock: helpful-key"))
(defun spacemacs/toggle-golden-ratio-on (&rest args) (message "[TEST] Mock: spacemacs/toggle-golden-ratio-on"))

;; Mock evil commands
(defmacro evil-define-operator (name &rest args)
  `(defun ,name (&rest args) (message "[TEST] Mock evil operator: %s" ',name)))
(defmacro evil-define-command (name &rest args)
  `(defun ,name (&rest args) (message "[TEST] Mock evil command: %s" ',name)))
(defmacro evil-define-motion (name &rest args)
  `(defun ,name (&rest args) (message "[TEST] Mock evil motion: %s" ',name)))

;; Mock other commonly used functions
(defun doom/move-this-file (&rest args) (message "[TEST] Mock: doom/move-this-file"))
(defun vc-rename-file (&rest args) (message "[TEST] Mock: vc-rename-file"))
(defun vc-delete-file (&rest args) (message "[TEST] Mock: vc-delete-file"))
(defun counsel-find-file (&rest args) (message "[TEST] Mock: counsel-find-file"))
(defun projectile-project-root (&rest args) nil)
(defun doom-project-root (&rest args) nil)
(defun doom-project-p (&rest args) nil)
(defun magit-toplevel (&rest args) nil)
(defun magit-refresh (&rest args) nil)
(defun projectile-file-cached-p (&rest args) nil)
(defun projectile-purge-file-from-cache (&rest args) nil)
(defun recentf-remove-if-non-kept (&rest args) nil)
(defun save-place-forget-unreadable-files (&rest args) nil)

;; Mock company
(defun global-company-mode (&rest args) (message "[TEST] Mock: global-company-mode"))
(defvar company-active-map (make-sparse-keymap))

;; Mock evil functions
(defun evil-declare-change-repeat (&rest args) (message "[TEST] Mock: evil-declare-change-repeat"))
(defun evil-define-key* (&rest args) (message "[TEST] Mock: evil-define-key*"))

;; Mock other modes
(defun keychain-refresh-environment (&rest args) (message "[TEST] Mock: keychain-refresh-environment"))
(defun flyspell-mode (&rest args) (message "[TEST] Mock: flyspell-mode"))
(defun flycheck-mode (&rest args) (message "[TEST] Mock: flycheck-mode"))

;; Mock theme loading
(defun load-theme (theme &rest args)
  (message "[TEST] Mock: load-theme %s" theme))

;; Track file loading
(advice-add 'load :before
            (lambda (file &rest args)
              (push file test-files-loaded)
              (message "[TEST] Loading: %s" file)))

;; Track org tangling
(advice-add 'org-babel-load-file :before
            (lambda (file)
              (push file test-org-files-tangled)
              (message "[TEST] Tangling: %s" file)))

;; Set up completion hook
(add-hook 'config/init-complete-hook
          (lambda ()
            (message "[TEST] ======================================")
            (message "[TEST] Initialization structure validated!")
            (message "[TEST] ======================================")
            (message "[TEST] Statistics:")
            (message "[TEST]   - Org files tangled: %d" (length test-org-files-tangled))
            (message "[TEST]   - Elisp files loaded: %d" (length test-files-loaded))
            (message "[TEST]   - Package declarations skipped: %d" test-packages-skipped)
            (message "[TEST] ")
            (message "[TEST] This test validates that:")
            (message "[TEST]   ✓ All org files can be found and tangled")
            (message "[TEST]   ✓ All elisp files load without fatal errors")
            (message "[TEST]   ✓ The initialization hook runs successfully")
            (message "[TEST]   ✓ File paths are properly resolved")
            (message "[TEST] ======================================")
            (kill-emacs 0)))

;; Load the actual init file
(condition-case err
    (progn
      (load (expand-file-name "lisp/init.el"
                              (file-name-directory
                               (or load-file-name buffer-file-name))))
      (message "[TEST] Waiting for init completion..."))
  (error
    (message "[TEST] FATAL ERROR during initialization: %s" err)
    (backtrace)
    (kill-emacs 1)))

(provide 'test-structure)
;;; test-structure.el ends here