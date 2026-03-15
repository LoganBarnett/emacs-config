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

;; Configures a complete visual-line editing experience for prose modes
;; (currently markdown).  The stack:
;;
;;   visual-line-mode         -- word-wrap at screen/column boundary
;;   evil-respect-visual-line-mode -- makes ALL evil motions/operators work on
;;                              visual lines (set in evil.el before evil loads)
;;   visual-fill-column-mode  -- wraps at a fixed column width instead of the
;;                              window edge, so resizing a frame doesn't shift
;;                              the wrap point
;;   adaptive-wrap-prefix-mode -- indents continuation lines to align with the
;;                              first non-whitespace character of the logical
;;                              line, e.g. list item continuations stay under
;;                              the text rather than the bullet
;;
;; text-mode-hook (parent of markdown-mode) runs config/disable-visual-line-mode
;; first.  The markdown-mode-hook below runs after and re-enables it.

;;; Code:

;; Wrap at fill-column (80) rather than the window edge.
(use-package visual-fill-column
  :hook (visual-line-mode . visual-fill-column-mode)
  :custom
  (visual-fill-column-width 80))

;; Indent continuation lines to align with the logical line's first
;; non-whitespace character.
(use-package adaptive-wrap
  :hook (visual-line-mode . adaptive-wrap-prefix-mode))

;; Raise so-long-mode's trigger threshold.  The default (250) is aggressive
;; enough to fire on ordinary prose paragraphs, which would undo visual-line-mode
;; in the very buffers we care about.  1000 characters still catches truly
;; pathological lines (minified JS, base64 blobs) while leaving normal prose
;; alone.
(setq so-long-threshold 1000)

;; Enable the full visual-line stack for markdown buffers.  auto-fill-mode is
;; removed: it inserts hard newlines as you type, which is the exact thing we
;; are trying to avoid having to do ourselves.  display-line-numbers-mode is
;; added so that relative line numbers reflect visual line distance and agree
;; with motion counts (display-line-numbers-type is already 'visual in
;; prog-mode-config; markdown inherits that setting here).
(add-hook 'markdown-mode-hook #'visual-line-mode)
(add-hook 'markdown-mode-hook (lambda () (auto-fill-mode -1)))
(add-hook 'markdown-mode-hook #'display-line-numbers-mode)

(provide 'visual-line-config)
;;; visual-line-config.el ends here
