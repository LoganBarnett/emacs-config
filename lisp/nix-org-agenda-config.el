;;; nix-org-agenda-config.el --- Agenda files declared by Nix.  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Logan Barnett

;; Author: Logan Barnett <logustus@gmail.com>
;; Keywords: calendar, outlines

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

;; Nix owns `org-agenda-files'.  The home module nix/home-modules/org-agenda.nix
;; writes the host's declaration to
;; ~/.config/emacs/nix-org-agenda.json as three lists: org-agenda-directories
;; to walk recursively for .org files, org-agenda-excludes as regexps against
;; each absolute path, and org-agenda-files to add as they are.  The result
;; replaces `org-agenda-files' at startup.
;;
;; A broken or absent declaration must not take down init.  Each failure
;; degrades to an empty contribution plus a warning, and `org-agenda-files'
;; is left alone when there is no declaration to apply.

;;; Code:

(require 'org)

(defvar config--nix-org-agenda-file "~/.config/emacs/nix-org-agenda.json"
  "Path that Nix writes the agenda declaration to.")

(defun config--nix-org-agenda-warn (format-string &rest args)
  "Warn about the Nix agenda declaration.
FORMAT-STRING and ARGS are as for `format'."
  (display-warning 'nix-org-agenda (apply #'format format-string args)))

(defun config--nix-org-agenda-declaration ()
  "Return the Nix agenda declaration as an alist.
Return nil, after a warning, when the file is absent or cannot be
parsed."
  (let ((file (expand-file-name config--nix-org-agenda-file)))
    (if (not (file-exists-p file))
        (progn
          (config--nix-org-agenda-warn
           "%s not found.  `org-agenda-files' is unchanged." file)
          nil)
      ;; A malformed file must not take down init.  The warning carries the
      ;; parse error, and the agenda keeps the files Emacs already knows.
      (condition-case err
          (with-temp-buffer
            (insert-file-contents file)
            (json-parse-buffer :object-type 'alist :array-type 'list))
        (error
         (config--nix-org-agenda-warn
          "%s could not be read: %s" file (error-message-string err))
         nil)))))

(defun config--nix-org-agenda-strings (declaration key)
  "Return the list of strings under KEY in DECLARATION.
A missing key, or a value that is not a list of strings, yields nil
after a warning."
  (let ((entry (assq key declaration)))
    (cond
     ((null entry)
      (config--nix-org-agenda-warn
       "%s has no %s key." config--nix-org-agenda-file key)
      nil)
     ((not (and (listp (cdr entry)) (seq-every-p #'stringp (cdr entry))))
      (config--nix-org-agenda-warn
       "%s: %s is not a list of strings." config--nix-org-agenda-file key)
      nil)
     (t (cdr entry)))))

(defun config--nix-org-agenda-present (paths predicate)
  "Return the expanded PATHS that satisfy PREDICATE, warning about the rest.
Org prompts at startup over a missing agenda file, so a declared path
that does not exist yet is skipped rather than passed on."
  (let ((expanded (mapcar #'expand-file-name paths)))
    (seq-do (lambda (path)
              (config--nix-org-agenda-warn
               "%s is declared in %s but does not exist.  Skipping it."
               path config--nix-org-agenda-file))
            (seq-remove predicate expanded))
    (seq-filter predicate expanded)))

(defun config--nix-org-agenda-walk (directories excludes)
  "Return the .org files under DIRECTORIES whose paths match no EXCLUDES.
EXCLUDES are regexps tested against each absolute path."
  (seq-remove
   (lambda (path)
     (seq-some (lambda (exclude) (string-match-p exclude path)) excludes))
   (seq-mapcat (lambda (directory)
                 (directory-files-recursively directory "\\.org\\'"))
               directories)))

(defun config--nix-org-agenda-register ()
  "Replace `org-agenda-files' with what the Nix declaration yields."
  (when-let* ((declaration (config--nix-org-agenda-declaration)))
    (let ((directories
           (config--nix-org-agenda-present
            (config--nix-org-agenda-strings declaration
                                            'org-agenda-directories)
            #'file-directory-p))
          (excludes
           (config--nix-org-agenda-strings declaration 'org-agenda-excludes))
          (files
           (config--nix-org-agenda-present
            (config--nix-org-agenda-strings declaration 'org-agenda-files)
            #'file-exists-p)))
      (setq org-agenda-files
            (seq-uniq (append (config--nix-org-agenda-walk directories excludes)
                              files)))
      ;; Declared files are regenerated out from under Emacs.  Without this,
      ;; `find-file-noselect' asks "Reread from disk?" on every agenda build
      ;; after a regeneration.
      (setq revert-without-query
            (append (mapcar (lambda (file)
                              (concat "\\`" (regexp-quote file) "\\'"))
                            files)
                    revert-without-query)))))

(config--nix-org-agenda-register)

(provide 'nix-org-agenda-config)
;;; nix-org-agenda-config.el ends here
