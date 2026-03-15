;;; visual-line-config.el --- Visual line wrapping for prose modes.  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Logan Barnett

;; Author: Logan Barnett <logan@scandium>
;; Keywords: visual, line, wrapping

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

;; ## Philosophy: auto-fill-mode is the strong default
;;
;; Hard line wrapping at 80 columns (auto-fill-mode) is the strong preference
;; here.  The reasons:
;;
;;   Splits and small monitors: 80 columns fits comfortably in any split window
;;   arrangement, on any monitor, without horizontal scrolling.  Soft-wrapped
;;   files only look readable in a wide, unsplit window -- they penalise anyone
;;   who isn't on a large single-pane setup.
;;
;;   Vim/Evil motions: with hard wraps, j/k/^/$ operate on logical lines, which
;;   is exactly what the user types and intends.  No surprises.  With
;;   visual-line-mode you need evil-respect-visual-line-mode and still hit edge
;;   cases where counts and operators behave unexpectedly.
;;
;;   Reading research: studies on optimal line length for reading consistently
;;   find that 50-80 characters per line maximises comprehension and reading
;;   speed.  The W3C Web Accessibility Guidelines (WCAG 1.4.8) cap lines at 80
;;   characters for the same reason.  A good literature review:
;;   https://journals.uc.edu/index.php/vl/article/view/5765
;;   (Ling & van Schaik, "Optimal Line Length in Reading -- A Literature
;;   Review", Visible Language, 2005.)
;;
;;   Diffs: hard-wrapped text produces clean, line-oriented diffs.  Editing a
;;   single word in a soft-wrapped paragraph rewrites the entire paragraph as
;;   one long line in the diff, making review harder.  Hard wraps mean a one-
;;   word change produces a one-line diff.
;;
;; visual-line-mode is a grudging concession for files written by people who
;; do not wrap their lines.  When opening someone else's unwrapped prose it is
;; better to read it comfortably than to reformat it and generate noise in
;; their repo's history.  config/maybe-enable-visual-line-mode detects that
;; situation automatically.  config/toggle-wrap-mode (SPC t v) lets you flip
;; between the two modes without leaving either; you should always be in one
;; or the other in a text buffer.
;;
;; ## The visual-line-mode companion stack
;;
;; When visual-line-mode IS enabled the following modes activate with it to
;; make the experience as bearable as possible:
;;
;;   visual-fill-column-mode  -- wraps at a fixed column width instead of the
;;                              window edge, so resizing a frame doesn't shift
;;                              the wrap point
;;   adaptive-wrap-prefix-mode -- indents continuation lines to align with the
;;                              first non-whitespace character of the logical
;;                              line, e.g. list item continuations stay under
;;                              the text rather than the bullet
;;   visual-wrap-prefix-mode  -- displays a visible prefix on continuation
;;                              lines so it is obvious that a logical line
;;                              continues rather than ending
;;   evil-respect-visual-line-mode -- makes evil motions work on visual lines
;;                              (set in evil.el before evil loads)
;;
;; All companion modes are hooked to visual-line-mode so the stack comes on
;; and goes off as a unit.

;;; Code:

;; doom-keybinds.el defines the `map!' macro used below.  The eval-when-compile
;; block ensures the macro is available during byte/native compilation; dotted-
;; pair prefix specs like ("t" . "toggle") cause native-compiler errors without
;; this.
(eval-when-compile
  (require 'doom-constants)
  (require 'doom-lib)
  (require 'doom-use-package)
  (require 'doom-keybinds))

;; Wrap at fill-column (80) rather than the window edge.
(use-package visual-fill-column
  :hook (visual-line-mode . visual-fill-column-mode)
  :custom
  (visual-fill-column-width 80))

;; Indent continuation lines to align with the logical line's first
;; non-whitespace character.
(use-package adaptive-wrap
  :hook (visual-line-mode . adaptive-wrap-prefix-mode))

;; Show a visible prefix on continuation lines so it is clear a logical line
;; wraps rather than ends.  Built into Emacs 29+.
(add-hook 'visual-line-mode-hook #'visual-wrap-prefix-mode)

;; Raise so-long-mode's trigger threshold.  The default (250) is aggressive
;; enough to fire on ordinary prose paragraphs, which would undo visual-line-mode
;; in the very buffers we care about.  1000 characters still catches truly
;; pathological lines (minified JS, base64 blobs) while leaving normal prose
;; alone.
(setq so-long-threshold 1000)

;; In text-mode buffers, ensure auto-fill-mode is on by default.
;; fundamental-mode.org already adds config/disable-visual-line-mode to
;; text-mode-hook; no need to disable visual-line-mode here as well.
(add-hook 'text-mode-hook #'auto-fill-mode)

(defun config/maybe-enable-visual-line-mode ()
  "Switch to visual-line-mode if the buffer contains long prose lines.
Long lines in tables (rows starting with optional whitespace then |) and lines
containing URLs are excluded: those tend to be long for structural reasons
rather than because the file was written without hard wrapping."
  (when (config/has-long-prose-lines-p)
    (auto-fill-mode -1)
    (visual-line-mode 1)))

(defun config/has-long-prose-lines-p ()
  "Return non-nil if the buffer has any long lines that look like prose."
  (save-excursion
    (goto-char (point-min))
    (catch 'found
      (while (not (eobp))
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position) (line-end-position))))
          (when (and (not (string-match-p "^\\s-*|" line))
                     (not (string-match-p "https?://" line))
                     (> (length line) 80))
            (throw 'found t)))
        (forward-line 1)))))

;; Append (t) so this runs after fundamental-mode.org's
;; config/disable-visual-line-mode, which is prepended and thus runs earlier.
;; Without append, the disable hook would undo any visual-line-mode activation
;; done here.
(add-hook 'text-mode-hook #'config/maybe-enable-visual-line-mode t)

(defun config/toggle-wrap-mode ()
  "Toggle between visual-line-mode and auto-fill-mode.
The two modes are mutually exclusive: enabling one disables the other.
You should always be in one or the other in a text buffer."
  (interactive)
  (if visual-line-mode
      (progn (visual-line-mode -1) (auto-fill-mode 1))
    (progn (auto-fill-mode -1) (visual-line-mode 1))))

(map!
 :leader
 (:prefix ("t" . "toggle")
  :desc "wrap mode (visual-line/auto-fill)" "v" #'config/toggle-wrap-mode))

(provide 'visual-line-config)
;;; visual-line-config.el ends here
