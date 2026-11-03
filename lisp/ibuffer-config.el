;;; ibuffer-config.el --- configure ibuffer -*- lexical-binding: t; -*-
;;; Commentary:
;; Configuration for ibuffer.

;;; Code:
(require 'use-package)

;; `map!' below must be expanded at compile time, or the compiled file calls it
;; as a function and init dies with invalid-function.  `evil' must already be
;; loaded at that expansion, or `map!' drops the normal-state binding from the
;; compiled output.  Native compilation runs each file in a fresh Emacs, so
;; this file has to load evil itself.
(eval-when-compile
  (require 'evil)
  (require 'doom-keybinds))

(use-package ibuffer
  :config
  (with-eval-after-load 'general
    (map! :map ibuffer-mode-map
          :n "q" #'kill-current-buffer))
  )

(provide 'ibuffer-config)
;;; ibuffer-config.el ends here
