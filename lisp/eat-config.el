;;; eat-config.el --- Configure eat.                 -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Logan Barnett

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

;;

;;; Code:

(defun eat-config--disable-blink ()
  "Disable `eat-blink-mode' to reduce eat-driven periodic redraws.

`eat-blink-mode' runs a timer that toggles a face remapping each
tick to animate blink-attribute text.  Face remapping dirties
the entire window every tick, which on slower redisplay paths
(notably TTY frames, which have no off-screen buffer to absorb
the change) produces visible frame-wide flicker.  On the macOS
NS port this contributes to flicker as well, though the dominant
driver of \"all of Emacs flashes ~2 Hz\" is eat's separate
cursor-animation timer (see `eat-very-visible-cursor-type' and
`eat-default-cursor-type', whose BLINKING-FREQUENCY field drives
a per-buffer timer independent of `blink-cursor-mode' and of
this mode).  Both are pinned to nil-blink in the `use-package'
form below; this hook handles the text-attribute side.

References:
- bug#13727 (long-standing TTY redraw flicker):
  https://lists.gnu.org/archive/html/bug-gnu-emacs/2013-02/msg00816.html
- bug#57434 (macOS TTY flicker report):
  https://lists.gnu.org/archive/html/bug-gnu-emacs/2022-09/msg00010.html
- Eat manual on `eat-blink-mode' and blinking text/cursor:
  https://elpa.nongnu.org/nongnu-devel/doc/eat.html"
  (eat-blink-mode -1))

(use-package eat
  :init
  ;; If you have trouble with Tramp, see about changing this.  We may need to
  ;; advise the `eat' function to use an `eat' specific variable..
  (setq explicit-shell-file-name "zsh")
  :custom
  ;; Pin BLINKING-FREQUENCY (second element) to nil on every cursor-type
  ;; variant eat exposes.  The internal `eat--cursor-blink-mode' activates
  ;; whenever the *currently applied* cursor type has a non-nil blink
  ;; frequency, and drives a per-buffer timer that mutates `cursor-type'
  ;; at that frequency.  On the macOS NS port the resulting redraw
  ;; cascades into a whole-frame repaint -- visible as ~2 Hz flicker
  ;; matching the default frequency of `2'.  Independent of
  ;; `blink-cursor-mode' and of `eat-blink-mode' (which animates the
  ;; *text* blink attribute, not the cursor).
  ;;
  ;; Which variant eat selects depends on the DECSCUSR escape sequence
  ;; the shell sends -- code 1/2 picks block, 3/4 underline, 5/6 bar;
  ;; the odd codes request blink, which routes to the very-visible
  ;; variant.  Override all four very-visible variants so no shell-side
  ;; sequence can route us back into a blinking spec.  The non-very-visible
  ;; bar/hbar variants already default to nil-blink.
  (eat-default-cursor-type (list (default-value 'cursor-type) nil nil))
  (eat-very-visible-cursor-type (list (default-value 'cursor-type) nil nil))
  (eat-very-visible-vertical-bar-cursor-type '(bar nil nil))
  (eat-very-visible-horizontal-bar-cursor-type '(hbar nil nil))
  :hook
  (eat-mode . eat-config--disable-blink)
  )

(provide 'eat-config)
;;; eat-config.el ends here
