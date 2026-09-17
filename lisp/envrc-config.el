;;; envrc-config.el --- Configure envrc.  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Logan Barnett

;; Author: Logan Barnett <logustus@gmail.com>
;; Keywords: processes, tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Apply a project's direnv environment (`exec-path', `process-environment')
;; per buffer so LSP, compile, and eshell see the Nix devShell declared by the
;; project's .envrc.
;;
;; One would typically reach for direnv-mode, but it re-runs direnv
;; synchronously from `post-command-hook' every time the current buffer's
;; directory changes, which turns a nix-direnv flake re-evaluation into a
;; multi-second freeze on every Magit commit.  envrc runs direnv once per
;; environment directory per session and caches the result.

;;; Code:

;; doom-keybinds.el defines the `map!' macro used in :config below.  Load the
;; dependency chain at compile time so the macro is available during
;; byte-compilation (same pattern as lisp/lsp.el).
(eval-when-compile
  (require 'doom-constants)
  (require 'doom-lib)
  (require 'doom-use-package)
  (require 'doom-keybinds)
  ;; Give the byte-compiler the real definitions so the `envrc-async' custom
  ;; and the lsp-* calls below are checked and arity-checked rather than
  ;; asserted.  Both packages sit in the compile environment via
  ;; packageRequires in emacs-package.nix.
  (require 'envrc)
  (require 'lsp-mode))

(require 'cl-lib)
(require 'use-package)

;; The eval-when-compile require above makes envrc visible only to the
;; compiler, which therefore warns that these function-quoted references
;; "might not be defined at runtime".  `declare-function' is the compiler's
;; verifiable assertion (see `check-declare-file') that the runtime provides
;; them; the use-package form below requires envrc at load time.
(declare-function envrc-allow "envrc" ())
(declare-function envrc-deny "envrc" ())
(declare-function envrc-global-mode "envrc" (&optional arg))
(declare-function envrc-reload "envrc" ())
(declare-function envrc-show-log "envrc" ())
;; Same for lsp-mode, which lisp/lsp.el requires at load time.
(declare-function lsp-workspace-restart "lsp-mode" (workspace))
(declare-function lsp-workspaces "lsp-mode" ())

(defvar config--envrc-lsp-pending-buffers nil
  "Buffers whose direnv environment changed under a running LSP session.")

(defvar config--envrc-lsp-restart-timer nil
  "Idle timer that coalesces the LSP restarts queued by envrc.")

(defun config--envrc-lsp-restart-pending ()
  "Restart LSP once per workspace for the buffers envrc queued."
  (let ((buffers config--envrc-lsp-pending-buffers)
        (workspaces nil))
    (setq config--envrc-lsp-pending-buffers nil
          config--envrc-lsp-restart-timer nil)
    (dolist (buf buffers)
      (when (and (buffer-live-p buf) (buffer-local-value 'lsp-mode buf))
        (with-current-buffer buf
          (dolist (ws (lsp-workspaces))
            (cl-pushnew ws workspaces)))))
    (dolist (ws workspaces)
      (lsp-workspace-restart ws))))

(defun config--envrc-lsp-queue-restart (orig buf result)
  "Queue an LSP restart for BUF if RESULT alters its running LSP environment.

Around advice for `envrc--apply', which is called through ORIG.  It runs
for every buffer, including the cached result applied to each newly opened
buffer, where LSP has not started yet and picks up the environment on its
own.  Only a buffer whose LSP session predates this environment (direnv
finishing in the background, or an explicit `envrc-reload') needs a
restart, and only when the environment actually changed.  Restarts go
through an idle timer because a reload applies to every buffer of the
environment in a burst."
  (let* ((live (buffer-live-p buf))
         (lsp-was-on (and live
                          (boundp 'lsp-mode)
                          (buffer-local-value 'lsp-mode buf)))
         (before (and live (buffer-local-value 'process-environment buf))))
    (funcall orig buf result)
    (when (and (consp result)
               lsp-was-on
               (buffer-live-p buf)
               (not (equal before
                           (buffer-local-value 'process-environment buf))))
      (cl-pushnew buf config--envrc-lsp-pending-buffers)
      (when config--envrc-lsp-restart-timer
        (cancel-timer config--envrc-lsp-restart-timer))
      (setq config--envrc-lsp-restart-timer
            (run-with-idle-timer 1 nil #'config--envrc-lsp-restart-pending)))))

(use-package envrc
  :custom
  ;; Block at most this long for direnv, then let it finish in the background
  ;; and apply the result when it arrives.  A warm nix-direnv cache answers
  ;; well within this, so mode hooks normally see the environment
  ;; synchronously, while a flake re-evaluation no longer freezes Emacs.
  (envrc-async 2)
  :config
  ;; envrc has no post-apply hook, so hang the LSP restart off its internal
  ;; apply function.  Guard the name so an envrc upgrade that renames it only
  ;; costs the automatic restart.
  (if (fboundp 'envrc--apply)
      (advice-add 'envrc--apply :around #'config--envrc-lsp-queue-restart)
    (message
     "envrc-config: envrc--apply not found; automatic LSP restart is off"))
  ;; Every globalized minor mode prepends itself to
  ;; `after-change-major-mode-hook', so envrc must be enabled after all the
  ;; others for envrc-mode to run first and let them find executables in the
  ;; buffer's environment.  `config/init-complete-hook' runs at the end of
  ;; `batteries-init', after every global mode this config turns on, and it
  ;; also fires in the batch test harness, unlike `after-init-hook'.
  (add-hook 'config/init-complete-hook #'envrc-global-mode)
  (map!
   :leader
   (:prefix ("p" . "project")
    (:prefix ("e" . "envrc")
     :desc "Reload direnv environment" "r" #'envrc-reload
     :desc "direnv allow" "a" #'envrc-allow
     :desc "direnv deny" "d" #'envrc-deny
     :desc "Show direnv log" "l" #'envrc-show-log
     )
    )
   )
  )

(provide 'envrc-config)
;;; envrc-config.el ends here
