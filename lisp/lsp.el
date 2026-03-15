
;;; Code:

;; doom-keybinds.el defines the `map!' macro used in :config below.
;; Load the dependency chain at compile time so the macro is available
;; during byte/native compilation (without this, dotted-pair prefix
;; specs like ("c" . "code") cause a native-compiler error).
(eval-when-compile
  (require 'doom-constants)
  (require 'doom-lib)
  ;; doom-keybinds.el uses (use-package! which-key ...) at the top level,
  ;; which requires doom-use-package to be loaded first (defines use-package!).
  (require 'doom-use-package)
  (require 'doom-keybinds))

(require 'use-package)

(use-package lsp-mode
  :init
  :config
  ;; Ensure that direnv is used to find rust-analyzer.
  (setq lsp-rust-analyzer-server-command '("direnv" "exec" "." "rust-analyzer"))
  ;; Show us more complete and helpful information under the cursor.
  (setq lsp-ui-doc-enable nil)
  (setq lsp-ui-doc-show-with-cursor nil)
  (setq lsp-eldoc-render-all t)          ;; show all info, not truncated
  (setq lsp-idle-delay 0.2)              ;; faster response
  (setq lsp-eldoc-enable-hover t)        ;; enable hover in minibuffer
  (map!
   :mode lsp-mode
   :localleader
   (:prefix
    ("c" . "code")
    :desc "lsp-action" "a" #'lsp-execute-code-action
    )
   )
  )
(provide 'lsp)
;;; lsp.el ends here
