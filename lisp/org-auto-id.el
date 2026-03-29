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
This is kebob case, with no quotes, spaces, or punctuation marks."
  (replace-regexp-in-string
   "\"\\|)\\|(\\|,\\|?" ""
   (downcase (replace-regexp-in-string " " "-" title))
   )
  )

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
  "When saving an `org-mode' buffer, add CUSTOM_IDs to all headlines.

See `org-auto-id/buffer-custom-id-populate' for details and
customization options."
  (interactive)
  (add-hook 'before-save-hook #'org-auto-id/save-auto-id)
  )

(provide 'org-auto-id)

;;; org-auto-id.el ends here
