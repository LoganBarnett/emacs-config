;;; org-auto-id --- Insert deterministic, human friendly IDs for Org headlines. -*- lexical-binding: t; -*-
;;
;;; Commentary:
;; Automatically insert CUSTOM_ID into org-mode headlines on save.  This makes
;; exporting headline links deterministic and human readable.  Otherwise
;; org-mode assigns a random ID that changes on every run.
;;
;; This can be enabled by adding `#+auto_id: t' to the headers of your org-mode
;; file.
;;
;;; Code:

(require 'org)
(require 'ucs-normalize)

(defmacro org-auto-id/without-undo (&rest body)
  "Execute BODY without recording undo information.

`org-auto-id' can potentially write a lot of changes to the buffer.  These
changes are mechanical and re-computed on every save, so recording them in the
undo history is not useful.  We temporarily set `buffer-undo-list' to t to
suppress all undo recording, then restore the original undo list.  This
preserves the user's undo history completely."
  (let ((saved-undo (make-symbol "saved-undo")))
    `(let ((,saved-undo buffer-undo-list))
       (setq buffer-undo-list t)
       (unwind-protect
           (progn ,@body)
         (setq buffer-undo-list ,saved-undo)))))

(defun org-auto-id/id-as-extra-kebab (hierarchy-list)
  "Convert HIERARCHY-LIST to kebab-case, with extra \"-\" between headings.

For example using the hierarchy foo -> bar -> baz qux with foo being at the top
of the hierarchy and baz qux being at the bottom.  The output would be:

\"foo--bar--baz-qux\""
  (org-auto-id/anchorize-headline-title (string-join hierarchy-list "--"))
  )

(defun org-auto-id/id-generate (id-fn title el)
  "Generate the CUSTOM_ID using ID-FN and TITLE from Org headline element EL."
  (funcall
   id-fn
   (org-auto-id/heading-hierarchy-list el (list title))
   )
  )

(defun org-auto-id/buffer-custom-id-populate ()
  "Add friendly and deterministic ids to the current buffer.

IDs for HTML anchors from exported `org-mode' buffers are not deterministic nor
human friendly.  By default sets the CUSTOM_ID to be a derivation of the
headline hierarchy.  The CUSTOM_ID is then used during the export process to set
the HTML anchor.  Set the buffer's AUTO_ID_FN to the symbol of a function in
order to customize the generated CUSTOM_ID value.  The function must accept an
org heading heading heirarchy from `org-auto-id/heading-hierarchy-list' and
return the string to be used for the CUSTOM_ID.

See `org-auto-id/id-as-extra-kebab' for the default AUTO_ID_FN.
The case of AUTO_ID_FN does not matter.

To override AUTO_ID_FN put this at the top of your buffer:

#+AUTO_ID_FN: my-fancy-auto-id-fn


If CUSTOM_ID is already set for a given heading then it will be overwritten."
  (interactive)
  (require 'org-id)
  (require 'org-element-ast)
  (setq-local org-id-link-to-org-use-id 'create-if-interactive-and-no-custom-id)
  (org-auto-id/without-undo
   (save-excursion
     (widen)
     (goto-char (point-min))
     (let ((format-to-id (or (intern-soft
                              (org-auto-id/get-org-keyword "AUTO_ID_FN"))
                             'org-auto-id/id-as-extra-kebab))
           (inhibit-modification-hooks t))
       (combine-after-change-calls
         (org-element-map
             (org-element-parse-buffer 'headline)
             'headline
           (lambda (el)
             (let ((id (org-element-property :raw-value el)))
               (outline-next-heading)
               (let ((custom-id (org-auto-id/id-generate format-to-id id el)))
                 (unless (string= custom-id (org-entry-get (point) "CUSTOM_ID"))
                   (org-entry-put (point) "CUSTOM_ID" custom-id)))))))))))

(defun org-auto-id/heading-hierarchy-list (child hierarchy)
  "Recurse from CHILD to build a parent-first HIERARCHY list of headline titles."
  (let* ((parent (org-element-property :parent child))
        (parent-title (org-element-property :raw-value parent)))
    (if (and parent parent-title)
        (org-auto-id/heading-hierarchy-list
           parent
           (push parent-title hierarchy)
           )
      hierarchy
      )
    )
  )

(defun org-auto-id/anchorize-headline-title (title)
  "Convert TITLE to an HTML anchor-worthy name.
This is kebab case: lowercase ASCII alphanumerics and dashes only.
Spaces become dashes.  Accented Latin characters lose their accents
via Unicode NFD decomposition (e.g. \"Résumé\" → \"resume\"), so the
ID stays human-readable instead of being stripped to nothing.  Every
remaining non-ASCII or punctuation character is removed.

This keeps the result safe to use in Markdown heading attribute syntax
\(`{#id}'), which Goldmark's parser rejects on apostrophes and other
punctuation."
  (replace-regexp-in-string
   "^-+\\|-+$" ""
   (replace-regexp-in-string
    "[^a-z0-9-]" ""
    (replace-regexp-in-string
     "[\u0300-\u036f]" ""
     (ucs-normalize-NFD-string
      (downcase (replace-regexp-in-string " " "-" title)))))))

(defun org-auto-id/get-org-keyword (keyword)
  "Get the value of KEYWORD from the org-mode buffer.
Uses `org-collect-keywords' to query org's own keyword handling.
KEYWORD should be uppercase.  Given this in the document:
#+FOO: bar
This code:
\(org-auto-id/get-org-keyword \"FOO\"\)
Will yield:
\"bar\""
  (cadr (assoc keyword (org-collect-keywords (list keyword)))))

(defun org-auto-id/save-auto-id ()
  "Save CUSTOM_IDs for Org headlines if AUTO_ID is non-nil."
  (when
    (and (eq major-mode 'org-mode)
         (eq buffer-read-only nil)
         (not (eq (org-auto-id/get-org-keyword "AUTO_ID") nil))
         )
    (message "Adding auto ids to org buffer \"%s\"" (buffer-name))
    (org-auto-id/buffer-custom-id-populate)
    )
  )

(defun org-auto-id/on-save-auto-id ()
  "Register `org-auto-id/save-auto-id' on `before-save-hook'.

The hook itself short-circuits in any buffer without `#+AUTO_ID: t',
so it is safe to register globally and opt in per file via the
keyword.  Use this when you want CUSTOM_IDs persisted into the
source (so `[[#anchor]]' cross-references resolve, and so IDs are
visible in git).  For the export-time, no-source-churn alternative,
see `org-auto-id-mode'."
  (interactive)
  (add-hook 'before-save-hook #'org-auto-id/save-auto-id))

(defun org-auto-id/headline-anchor (orig-fun &rest args)
  "Around-advice for `org-export-get-reference'.

Return a deterministic kebab-case anchor for headline elements that
have no `:CUSTOM_ID:' set.  Falls back to ORIG-FUN with ARGS for any
other element (links, footnotes, internal targets) so we don't
override Org's whole reference machinery.

Headlines with an explicit `:CUSTOM_ID:' fall through too — the
persist-on-save flow (`#+AUTO_ID: t') is the per-buffer escape
hatch when you need stable, hand-linkable anchors via
`[[#anchor]]'."
  (let ((datum (car args)))
    (if (and (eq (org-element-type datum) 'headline)
             (not (org-element-property :CUSTOM_ID datum)))
        (org-auto-id/id-as-extra-kebab
         (org-auto-id/heading-hierarchy-list
          datum (list (org-element-property :raw-value datum))))
      (apply orig-fun args))))

(define-minor-mode org-auto-id-mode
  "Toggle export-time deterministic anchor generation via advice.

When enabled, `org-export-get-reference' is wrapped so that
headlines without an explicit `:CUSTOM_ID:' get a deterministic
kebab-case anchor derived from heading text and hierarchy, instead
of Org's default random ID.  Other element types (links, footnotes,
internal targets) are unaffected.

The mode is global; the advice is a single piece of state.  No
source files are modified — IDs only exist during export.  This
trades off the ability to write `[[#anchor]]' cross-references in
the source (those need a real `:CUSTOM_ID:' to resolve).  For files
that need cross-references, add `#+AUTO_ID: t' to the buffer header
and persist IDs into the source via `org-auto-id/on-save-auto-id'.

To customize how IDs are generated, see
`org-auto-id/buffer-custom-id-populate' and the `#+AUTO_ID_FN'
keyword."
  :global t
  :group 'org
  (require 'ox)
  (if org-auto-id-mode
      (advice-add 'org-export-get-reference :around
                  #'org-auto-id/headline-anchor)
    (advice-remove 'org-export-get-reference
                   #'org-auto-id/headline-anchor)))

(provide 'org-auto-id)

;;; org-auto-id.el ends here
