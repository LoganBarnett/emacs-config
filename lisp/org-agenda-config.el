;;; org-agenda-config.el --- configure org-agenda  -*- lexical-binding: t; -*-

;;; Commentary:

;; `org-agenda-files' is not set here.  Nix declares it, and
;; nix-org-agenda-config.el applies the declaration.
;;
;; evil-collection has no org-agenda module, so evil-org's agenda bindings
;; fill that role.  Upstream spends single letters on rarely used actions, so
;; they become prefixes here.

;;; Code:

(require 'org-agenda)
(require 'evil)
(require 'evil-org-agenda)
;; `map!' expands to general calls.
(require 'general)

;; `map!' must be expanded at compile time, or the compiled file calls it as a
;; function and init dies with invalid-function.  evil must already be loaded
;; at that expansion, or `map!' drops every state-specific binding from the
;; compiled output.  The `require' of evil above runs at compile time too, so
;; it has to stay ahead of this form.
(eval-when-compile
  (require 'doom-keybinds))

;; Day view.  A numeric prefix to `org-agenda' still widens it.
(setq org-agenda-span 1)

;; Notes reference `diary-last-day-of-month' in diary sexps, so the name keeps
;; diary-lib's prefix.  Org timestamps cannot express the last day of a month.
;; `SCHEDULED: <%%(diary-last-day-of-month date)>' does.
(defun diary-last-day-of-month (date)
  "Return t if DATE is the last day of its month."
  (= (calendar-extract-day date)
     (calendar-last-day-of-month (calendar-extract-month date)
                                 (calendar-extract-year date))))

(map! :leader :desc "org-agenda" "o a" #'org-agenda)

(evil-org-agenda-set-keys)
;; The upstream bindings under d and a must be cleared before the prefixes
;; below are built.  general adds keys into an existing prefix map and signals
;; on a key bound to a command, so d would keep dd, dA and da, and a would
;; error.
(evil-define-key* 'motion org-agenda-mode-map "d" nil "a" nil)
(map! :map org-agenda-mode-map
      (:prefix ("d" . "date + schedule")
       :desc "schedule" :m "s" #'org-agenda-schedule
       :desc "deadline" :m "S" #'org-agenda-deadline
       :desc "date prompt" :m "d" #'org-agenda-date-prompt)
      (:prefix ("a" . "archive")
       :desc "archive" :m "A" #'org-agenda-archive-default
       :desc "toggle archive tag" :m "a" #'org-agenda-toggle-archive-tag
       :desc "kill" :m "d" #'org-agenda-kill)
      (:prefix ("r" . "refile")
       :desc "refile" :m "r" #'org-agenda-refile)
      (:prefix ("b" . "agenda buffer")
       :desc "refresh" :m "r" #'org-agenda-redo))

(provide 'org-agenda-config)
;;; org-agenda-config.el ends here
