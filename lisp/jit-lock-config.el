;;; jit-lock-config.el --- Background fontification  -*- lexical-binding: t; -*-

;;; Commentary:

;; Turn on jit-lock's stealth fontification so a buffer is fontified before it
;; is paged through.

;;; Code:

;; Enable stealth fontification.
(setq jit-lock-stealth-time 2)

;; Make more aggressive than the default (0.5s) to take advantage of modern
;; multi-core hardware.
(setq jit-lock-stealth-nice 0.1)

(provide 'jit-lock-config)
;;; jit-lock-config.el ends here
