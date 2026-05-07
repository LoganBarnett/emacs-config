;;; config-completion.el --- All of my completion configuration.  -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Logan Barnett

;; Author: Logan Barnett <logan@scandium>
;; Keywords:

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

;; Completion in Emacs splits into two surfaces that this file configures
;; together as one coherent stack:
;;
;;   1. *Minibuffer* completion (`M-x', `C-x b', `find-file', anything
;;      `completing-read'-y) -- driven by vertico, with marginalia for
;;      annotations, consult for richer commands, embark for actions
;;      on candidates, and orderless for the matching style.
;;
;;   2. *In-buffer* popup (typing in a normal buffer) -- driven by
;;      corfu, with cape for additional capf sources (file paths,
;;      dabbrev, keywords) and yasnippet-capf for surfacing snippet
;;      candidates in the popup.
;;
;; vertico and corfu are *complementary*, not mutually exclusive: they
;; cover different surfaces and never compete.  Both honor
;; `completion-styles' (orderless), so fuzzy/initialism matching like
;; "gui" -> "get_user_id" works in both the minibuffer and the popup.
;;
;; Yasnippet expansion has two paths, both preserved:
;;
;;   - Direct `trigger<TAB>' expansion: handled by `yas-minor-mode-map'
;;     before `completion-at-point' is consulted.  No popup involved.
;;   - Snippet candidates inside the corfu popup: provided by
;;     yasnippet-capf as a regular capf.  Selecting a snippet candidate
;;     triggers expansion via yasnippet.
;;
;; LSP completions flow through `completion-at-point-functions' via
;; `lsp-completion-at-point' (registered automatically by
;; `lsp-completion-mode' when lsp-mode attaches to a buffer).  No
;; separate corfu/company-LSP backend is required.
;;
;; Future enhancements that are deliberately out of scope here:
;;   - corfu-popupinfo: docstring panel beside the popup.
;;   - corfu-history-mode: MRU sorting of candidates.
;;   - corfu-terminal: TTY popup support (we run GUI Emacs).
;;   - cape-capf-super to merge LSP + snippets into a single sorted
;;     candidate list (the layered capfs below are simpler to reason
;;     about; revisit if the per-source ordering becomes a problem).

;;; Code:

;; Enable vertico
(use-package vertico
  ;; :custom
  ;; (vertico-scroll-margin 0) ;; Different scroll margin
  ;; (vertico-count 20) ;; Show more candidates
  ;; (vertico-resize t) ;; Grow and shrink the Vertico minibuffer
  ;; (vertico-cycle t) ;; Enable cycling for `vertico-next/previous'
  :config
  ;; Use :config (not :init) so vertico is loaded before vertico-mode is called.
  ;; In the Nix emacsWithPackagesFromUsePackage setup, package autoloads are not
  ;; pre-registered, so calling vertico-mode in :init (before (require 'vertico))
  ;; would fail with void-function.
  (vertico-mode)
  )

;; Persist history over Emacs restarts. Vertico sorts by history position.
(use-package savehist
  :init
  (savehist-mode))

;; A few more useful configurations...
(use-package emacs
  :custom
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  ;; Hide commands in M-x which do not work in the current mode.  Vertico
  ;; commands are hidden in normal buffers. This setting is useful beyond
  ;; Vertico.
  (read-extended-command-predicate #'command-completion-default-include-p)
  :init
  ;; Add prompt indicator to `completing-read-multiple'.
  ;; We display [CRM<separator>], e.g., [CRM,] if the separator is a comma.
  (defun crm-indicator (args)
    (cons (format "[CRM%s] %s"
                  (replace-regexp-in-string
                   "\\`\\[.*?]\\*\\|\\[.*?]\\*\\'" ""
                   crm-separator)
                  (car args))
          (cdr args)))
  (advice-add #'completing-read-multiple :filter-args #'crm-indicator)

  ;; Do not allow the cursor in the minibuffer prompt
  (setq minibuffer-prompt-properties
        '(read-only t cursor-intangible t face minibuffer-prompt))
  (add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)
  (setq-default
    read-file-name-completion-ignore-case t
    read-buffer-completion-ignore-case t
    completion-ignore-case t
    )
  )

(use-package orderless
  :custom
  ;; Configure a custom style dispatcher (see the Consult wiki)
  ;; (orderless-style-dispatchers '(+orderless-consult-dispatch orderless-affix-dispatch))
  ;; (orderless-component-separator #'orderless-escapable-split-on-space)
  (completion-styles '(orderless basic))
  ;; (completion-styles '(basic substring partial-completion flex))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package corfu
  :custom
  ;; Auto-show the popup as you type (vs. on-demand via TAB only).
  (corfu-auto t)
  ;; Delay before the popup appears.  Corfu's default of 0.2s is much
  ;; snappier than company's old 1s; tune up if it feels noisy.
  (corfu-auto-delay 0.2)
  ;; Mirror the old `company-minimum-prefix-length' so we don't pop
  ;; immediately on every keystroke.
  (corfu-auto-prefix 2)
  ;; Wrap around when navigating candidates with C-n / C-p.
  (corfu-cycle t)
  ;; Quit on a separator (e.g. SPC) when no candidate matches; allows
  ;; orderless multi-word patterns without the popup steamrolling them.
  (corfu-quit-no-match (quote separator))
  ;; Don't preview the highlighted candidate inline -- noisy with
  ;; orderless matching.
  (corfu-preview-current nil)
  ;; Keep corfu out of the minibuffer.  Vertico already owns that surface,
  ;; and `evil-ex-setup' makes `completion-at-point-functions' buffer-local
  ;; -- which is exactly the trigger `corfu--minibuffer-on' watches for.
  ;; If corfu activates there, it overrides `completion-in-region-function'
  ;; buffer-locally and bypasses `consult-completion-in-region', so `:e re'
  ;; (with multiple candidates) silently commits the first one instead of
  ;; popping a vertico prompt.
  (global-corfu-minibuffer nil)
  :config
  ;; Use :config (not :init) so corfu is loaded before global-corfu-mode
  ;; is called.  In the Nix emacsWithPackagesFromUsePackage setup,
  ;; package autoloads are not pre-registered, so calling
  ;; global-corfu-mode in :init (before (require 'corfu)) would fail
  ;; with void-function.  Same pattern as vertico/marginalia above.
  (global-corfu-mode))

(use-package cape
  :init
  ;; Register cape's general-purpose capfs on the global
  ;; `completion-at-point-functions'.  Order matters -- earlier capfs
  ;; win when their prefix matches.  cape-file is at the front so
  ;; paths like ./foo or ~/bar always trigger file completion
  ;; regardless of major-mode capfs.
  (add-hook (quote completion-at-point-functions) (function cape-file))
  (add-hook (quote completion-at-point-functions) (function cape-dabbrev))
  (add-hook (quote completion-at-point-functions) (function cape-keyword)))

(use-package yasnippet-capf
  :after (cape yasnippet)
  :init
  ;; Surface snippet trigger candidates in the corfu popup.  Direct
  ;; trigger<TAB> expansion still runs through `yas-minor-mode-map' and
  ;; bypasses corfu entirely; this hook only affects the popup.
  (add-hook (quote completion-at-point-functions) (function yasnippet-capf)))

;; A few more useful configurations...
(use-package emacs
  :custom
  ;; TAB cycle if there are only few candidates
  ;; (completion-cycle-threshold 3)

  ;; Enable indentation+completion using the TAB key.
  ;; `completion-at-point' is often bound to M-TAB.
  (tab-always-indent 'complete)

  ;; Emacs 30 and newer: Disable Ispell completion function.
  ;; Try `cape-dict' as an alternative.
  (text-mode-ispell-word-completion nil)

  ;; Hide commands in M-x which do not apply to the current mode.  Corfu
  ;; commands are hidden, since they are not used via M-x. This setting is
  ;; useful beyond Corfu.
  (read-extended-command-predicate #'command-completion-default-include-p))

(use-package nerd-icons-corfu
  :after corfu
  :init
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)
  )

;; Enable rich annotations using the Marginalia package
(use-package marginalia
  ;; Bind `marginalia-cycle' locally in the minibuffer.  To make the binding
  ;; available in the *Completions* buffer, add it to the
  ;; `completion-list-mode-map'.
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))

  ;; Use :config so marginalia is loaded before marginalia-mode is called.
  ;; The marginalia README suggests :init, relying on autoloads, but in the
  ;; Nix emacsWithPackagesFromUsePackage setup autoloads are not pre-registered.
  :config
  (marginalia-mode))

(use-package consult
  :init
  (setq completion-in-region-function 'consult-completion-in-region)
  )

(use-package embark
  :ensure t
  :bind
  (("C-." . embark-act)         ;; pick some comfortable binding
   ("M-." . embark-dwim)        ;; C-; reserved for flyspell-correct
   ("C-c C-e" . embark-export)
   ("C-c C-a" . emark-act)
   ("C-c C-d" . embark-dwim)
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'
  :init
  (setq-default
   ;; Optionally replace the key help with a completing-read interface.
   prefix-help-command #'embark-prefix-help-command
   ;; Prevent closing of the embark minibuffer.  This might need to be set
   ;; conditionally.  There is an example in the docs found in
   ;; https://github.com/oantolin/embark?tab=readme-ov-file#quitting-the-minibuffer-after-an-action
   ;; which could easily be adapted for doing this contextually (such as only
   ;; when searching files).
   ;; See also https://github.com/oantolin/embark/issues/713 which suggests that
   ;; there's a bug or perhaps the documentation about this is inconsistent.
   embark-quit-after-action '(
                              (consult-grep . nil)
                              (consult-ripgrep . nil)
                              (embark-consult-goto-grep . nil)
                              (t . nil)
                              )
   )

  )

;; Consult users will also want the embark-consult package.
(use-package embark-consult
  :ensure t ; only need to install it, embark loads it after consult if found.
  :hook
  (embark-collect-mode . consult-preview-at-point-mode)
  )

(with-eval-after-load 'evil
  ;; Use `eval' to prevent the native compiler from miscompiling the
  ;; evil-define-operator macro expansion.  The macro generates
  ;; (let ((func #'config/wgrep-mark-deletion-operator)) ...) and the native
  ;; compiler emits a VAR-REF (variable lookup) instead of SYMFUNCTION
  ;; (function lookup) for #'config/wgrep-mark-deletion-operator because the
  ;; name is unknown at compile time (defined via defalias, not defun).
  ;; Wrapping in eval defers expansion and execution to runtime where the
  ;; function is available.
  (eval
   '(evil-define-operator config/wgrep-mark-deletion-operator (beg end type)
      "Mark lines for deletion in wgrep, or use normal delete for single-line edits,
all between BEG, END, respecting evil's TYPE."
      :motion evil-line
      (interactive "<R>")
      (if (and (eq type 'inclusive)
               (= (line-number-at-pos beg) (line-number-at-pos end)))
          ;; Single-line motion, use normal delete
          (evil-delete beg end type ?_)
        ;; Multi-line motion, mark for wgrep deletion
        (save-excursion
          (goto-char beg)
          (let ((line-end (save-excursion (goto-char end) (line-number-at-pos))))
            (while (<= (line-number-at-pos) line-end)
              (wgrep-mark-deletion)
              (forward-line 1))))))
   t))

(use-package wgrep
  :config
  ;; Use evil-define-key instead of map! because map! is a Doom macro that
  ;; may not be available when config-completion.el is byte/native-compiled by
  ;; the Nix builder.  Calling a macro as a function at runtime gives
  ;; invalid-function.  evil-define-key is also a macro, so wrap in eval to
  ;; defer expansion to runtime where evil is loaded.
  (eval
   '(evil-define-key '(normal visual) wgrep-mode-map
      (kbd "d") #'config/wgrep-mark-deletion-operator)
   t)
  )

(provide 'config-completion)
;;; config-completion.el ends here
