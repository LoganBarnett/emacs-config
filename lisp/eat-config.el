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
  "Disable `eat-blink-mode' to avoid whole-frame flicker in TTY Emacs.

`eat-blink-mode' runs a timer that toggles a face remapping each
tick to animate blink-attribute text and the very-visible cursor.
Face remapping dirties the entire window, and TTY Emacs has no
off-screen/double buffer -- unlike GUI redisplay, which blits an
off-screen pixmap atomically (the X11 double-buffer work landed
after the 2016 emacs-devel RFC).  In TTY mode each tick therefore
visibly repaints cells one at a time, producing a frame-wide
flash in time with the cursor blink.  Setting non-blinking
`eat-default-cursor-type'/`eat-very-visible-cursor-type' is not
sufficient -- the timer is the driver, not the cursor shape.

The structural fix would be for Emacs's TTY backend to wrap
redraws in BSU/ESU sequences (DEC private mode 2026,
\"synchronized output\").  Ghostty and most modern terminals
buffer output between those sequences and flush the update
atomically, eliminating tearing.  As of Emacs 31.1 master the
NEWS file mentions no synchronized-output support, and a search
of debbugs/emacs-devel did not surface an active patch.  If/when
that support lands, this workaround can likely be removed.

References:
- DEC mode 2026 spec (Christian Parpart):
  https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036
- emacs-devel 2016 RFC, flicker-free double-buffered Emacs (X11):
  https://lists.gnu.org/archive/html/emacs-devel/2016-10/msg00626.html
- bug#13727 (long-standing TTY redraw flicker):
  https://lists.gnu.org/archive/html/bug-gnu-emacs/2013-02/msg00816.html
- bug#57434 (more recent macOS TTY flicker report):
  https://lists.gnu.org/archive/html/bug-gnu-emacs/2022-09/msg00010.html
- Eat manual on `eat-blink-mode' and blinking text/cursor:
  https://elpa.nongnu.org/nongnu-devel/doc/eat.html"
  (eat-blink-mode -1))

(use-package eat
  :init
  ;; If you have trouble with Tramp, see about changing this.  We may need to
  ;; advise the `eat' function to use an `eat' specific variable..
  (setq explicit-shell-file-name "zsh")
  :hook
  (eat-mode . eat-config--disable-blink)
  )

(provide 'eat-config)
;;; eat-config.el ends here
