;;; test-lsp.el --- LSP setup assertions  -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by test-lsp.sh.  Unlike test-keybindings.el, this file loads the
;; init itself, because one probe must be in place BEFORE the init runs: the
;; moment lsp-protocol first loads is when lsp-mode reads LSP_USE_PLISTS and
;; fixes the plist-vs-hash-table representation for the whole session.  Only a
;; hook installed ahead of that load can say what the env var held at that
;; instant and which file dragged lsp-protocol in.
;;
;; "The LSP optimizations are in effect" means, concretely:
;;
;;   1. lsp-protocol saw LSP_USE_PLISTS when it loaded, so `lsp-use-plists'
;;      is non-nil at runtime.
;;   2. The Nix build compiled lsp-mode with the same flag, so the
;;      lsp-interface constructors produce plists ...
;;   3. ... and the runtime accessors (`lsp-get') agree with them.  A mismatch
;;      is the failure mode emacs-package.nix warns about: every lsp-get on a
;;      server response throws wrong-type-argument, workspaces never leave
;;      `starting', and Rust buffers crawl.
;;   4. emacs-lsp-booster wraps the resolved server command.  The advice only
;;      does so when `lsp-use-plists' is set, so this is the user-visible
;;      consequence of 1.
;;   5. The subprocess / GC tuning from init.el is in place.
;;   6. lsp.el itself loads from its byte-compiled form.  Loaded as source, its
;;      `eval-when-compile' requires run at load time and pull in lsp-protocol
;;      before anything has set the env var -- which is how 1 breaks.
;;   7. End to end: a server started through lsp-mode's own start-up path
;;      reaches `initialized', and was launched through the booster.
;;
;; The runner passes the init file and the stand-in server in via --eval
;; before loading this file.

;;; Code:

;; lsp-mode arrives with the init this file loads at run time, so it is not
;; present at byte-compile time.  Declare what the checks touch: the
;; `defvar's mark the customs `test-lsp--e2e' let-binds as special, so a
;; compiled `let' binds them dynamically rather than lexically (the file is
;; lexical-binding), and `declare-function' tells the compiler the functions
;; exist.  The struct-generated ones are declared file-only, as
;; `check-declare' cannot see through `cl-defstruct'.
(defvar lsp-session-file)
(defvar lsp-restart)
(defvar lsp-enable-suggest-server-download)
(declare-function lsp "lsp-mode" (&optional arg))
(declare-function lsp-get "lsp-protocol" (from key))
(declare-function lsp-register-client "lsp-mode" (client))
(declare-function lsp-resolve-final-command "lsp-mode"
                  (command &optional test?))
(declare-function lsp-stdio-connection "lsp-mode"
                  (command &optional test-command))
(declare-function lsp-workspace-folders-add "lsp-mode" (project-root))
(declare-function lsp-workspaces "lsp-mode" ())
(declare-function make-lsp-client "lsp-mode" t t)
(declare-function lsp--workspace-proc "lsp-mode" t t)
(declare-function lsp--workspace-status "lsp-mode" t t)

(defvar test-lsp--init-file nil
  "Absolute path of the Nix-installed init (default.el), set by test-lsp.sh.")

(defvar test-lsp--fake-server nil
  "Absolute path of test-lsp-server.sh, set by test-lsp.sh.")

(defvar test-lsp--failures '())
(defvar test-lsp--passes '())

(defun test-lsp--check (description condition &optional detail)
  "Record DESCRIPTION as passed when CONDITION is non-nil, else as failed.
DETAIL, when given, is printed under a failure to explain it."
  (if condition
      (push description test-lsp--passes)
    (push (if detail (format "%s\n    %s" description detail) description)
          test-lsp--failures)))

;;
;; ── Probe installed before the init runs ─────────────────────────────────────

(defvar test-lsp--protocol-load-record nil
  "What the first load of lsp-protocol looked like, or nil before it.
A plist of :file, :env (the env var's value at that instant) and :chain
\(the load/require frames that led there).")

(defun test-lsp--load-chain ()
  "Return the load/require frames on the current stack, outermost first."
  (let (chain)
    (mapbacktrace
     (lambda (_evald func args _flags)
       (when (memq func '(load load-library load-file require))
         (push (format "%s %S" func (car args)) chain))))
    chain))

(defun test-lsp--record-protocol-load (file)
  "Record the first load of lsp-protocol, if FILE is it.
Meant for `after-load-functions'; later loads are ignored."
  (when (and (null test-lsp--protocol-load-record)
             (string-match-p "/lsp-protocol\\.elc?\\'" file))
    (setq test-lsp--protocol-load-record
          (list :file file
                :env (getenv "LSP_USE_PLISTS")
                :chain (test-lsp--load-chain)))))

(add-hook 'after-load-functions #'test-lsp--record-protocol-load)

;;
;; ── Run the full init ────────────────────────────────────────────────────────

(unless (and test-lsp--init-file (file-exists-p test-lsp--init-file))
  (message "[LSP TEST] test-lsp--init-file is not set to an existing file: %S"
           test-lsp--init-file)
  (kill-emacs 2))

(load test-lsp--init-file)

;;
;; ── Checks ───────────────────────────────────────────────────────────────────

(let* ((rec test-lsp--protocol-load-record)
       (chain (mapconcat (lambda (s) (concat "      " s))
                         (plist-get rec :chain) "\n")))
  (test-lsp--check
   "lsp-protocol was loaded during init"
   rec)
  (test-lsp--check
   "LSP_USE_PLISTS was set when lsp-protocol first loaded"
   (equal (plist-get rec :env) "true")
   (format "env var was %S at that moment; it was loaded by:\n%s"
           (plist-get rec :env) chain)))

(test-lsp--check
 "lsp-use-plists is non-nil at runtime"
 (bound-and-true-p lsp-use-plists))

(let ((pos (and (fboundp 'lsp-make-position)
                (lsp-make-position :line 1 :character 2))))
  (test-lsp--check
   "lsp-mode was compiled with plists (lsp-make-position yields a plist)"
   (and pos (listp pos))
   (format "lsp-make-position returned %S" pos))
  (test-lsp--check
   "build and runtime agree on the representation (lsp-get reads it back)"
   (condition-case nil
       (equal 1 (lsp-get pos :line))
     (error nil))
   (condition-case err
       (format "lsp-get returned %S" (lsp-get pos :line))
     (error (format "lsp-get signalled %S" err)))))

(let ((cmd (condition-case err
               (lsp-resolve-final-command '("rust-analyzer"))
             (error (list (format "ERROR: %S" err))))))
  (test-lsp--check
   "lsp-resolve-final-command prepends emacs-lsp-booster"
   (and (boundp 'config/lsp-booster-executable)
        (equal (car cmd) config/lsp-booster-executable))
   (format "resolved command: %S" cmd)))

(test-lsp--check
 "json-parse-buffer carries the booster bytecode-reading advice"
 (and (fboundp 'json-parse-buffer)
      (advice-member-p 'config--lsp-booster-json-parse 'json-parse-buffer)))

(test-lsp--check
 "the injected emacs-lsp-booster binary runs (--help exits 0)"
 (and (boundp 'config/lsp-booster-executable)
      (file-executable-p config/lsp-booster-executable)
      (eq 0 (call-process config/lsp-booster-executable nil nil nil "--help")))
 (format "config/lsp-booster-executable = %S"
         (and (boundp 'config/lsp-booster-executable)
              config/lsp-booster-executable)))

(test-lsp--check
 "read-process-output-max is at least 1 MiB"
 (>= read-process-output-max (* 1024 1024))
 (format "read-process-output-max = %d" read-process-output-max))

(test-lsp--check
 "process-adaptive-read-buffering is off"
 (null process-adaptive-read-buffering))

(test-lsp--check
 "gc-cons-threshold is at least 100 MiB"
 (>= gc-cons-threshold (* 100 1024 1024))
 (format "gc-cons-threshold = %d" gc-cons-threshold))

(let ((entries (seq-filter (lambda (f)
                             (and (stringp f)
                                  (string-match-p "/lsp\\.elc?\\'" f)))
                           (mapcar #'car load-history))))
  (test-lsp--check
   "lsp.el is loaded from its byte-compiled form (lsp.elc), not as source"
   (and entries (seq-every-p (lambda (f) (string-suffix-p ".elc" f)) entries))
   (format "load-history has: %S" entries)))

;;
;; ── End to end: a server must reach `initialized' ────────────────────────────
;;
;; Everything above inspects configuration.  This drives lsp-mode's real
;; start-up path with a stand-in server (test-lsp-server.sh, which answers
;; `initialize' and nothing else): client registration, command resolution
;; (where the booster advice wraps the command), the process filter, and
;; JSON/bytecode parsing -- then waits for the workspace to leave `starting'.
;; Under the plist mismatch the initialize response is decoded into hash
;; tables that the plist-compiled accessors read as empty, the initialize
;; callback never runs, and the workspace sits in `starting' forever with nil
;; capabilities.  That is exactly the state a Rust buffer shows in the broken
;; session, so this failing is the user-visible bug itself, not a proxy.

(defun test-lsp--lsp-log-tail ()
  "Return the last part of *lsp-log*, indented for the report."
  (if (get-buffer "*lsp-log*")
      (with-current-buffer "*lsp-log*"
        (replace-regexp-in-string
         "^" "      "
         (buffer-substring-no-properties
          (max (point-min) (- (point-max) 1500)) (point-max))))
    "      (no *lsp-log* buffer)"))

(defun test-lsp--e2e ()
  "Start the stand-in server on a scratch file and wait for `initialized'.
Return a plist with :status (the workspace status, `no-workspace', or an
error form) and :command (the server's argv)."
  (let* ((root (file-name-as-directory (make-temp-file "test-lsp-e2e-" t)))
         (file (expand-file-name "scratch.txt" root))
         ;; Keep session state under the scratch root, and never prompt: a
         ;; dead server would otherwise ask whether to restart.
         (lsp-session-file (expand-file-name "lsp-session" root))
         (lsp-restart 'ignore)
         (lsp-enable-suggest-server-download nil)
         ;; An error in a process filter or hook must not abort the run
         ;; before the report prints; lsp-mode logs it instead, and the
         ;; workspace status then tells the story.
         (debug-on-error nil)
         (status 'not-started)
         (command nil))
    (with-temp-file file (insert "hello\n"))
    (lsp-register-client
     (make-lsp-client
      :new-connection (lsp-stdio-connection (list test-lsp--fake-server))
      :major-modes '(text-mode)
      :priority 100
      :server-id 'test-lsp-fake-server))
    ;; A known workspace folder, so `lsp' neither hunts for a project nor
    ;; asks whether to import one.
    (lsp-workspace-folders-add root)
    (with-current-buffer (find-file-noselect file)
      (text-mode)
      (condition-case err
          (progn
            (lsp)
            (let ((deadline (+ (float-time) 15))
                  (ws (car (lsp-workspaces))))
              (while (and ws
                          (< (float-time) deadline)
                          (eq (lsp--workspace-status ws) 'starting))
                (accept-process-output nil 0.2))
              (setq status (if ws (lsp--workspace-status ws) 'no-workspace)
                    command (and ws
                                 (process-live-p (lsp--workspace-proc ws))
                                 (process-command (lsp--workspace-proc ws))))
              (when (and ws (process-live-p (lsp--workspace-proc ws)))
                (delete-process (lsp--workspace-proc ws)))))
        (error (setq status err)))
      (set-buffer-modified-p nil)
      (kill-buffer))
    (delete-directory root t)
    (list :status status :command command)))

(let* ((e2e (test-lsp--e2e))
       (status (plist-get e2e :status))
       (command (plist-get e2e :command)))
  (test-lsp--check
   "a server started through lsp-mode reaches `initialized' (end to end)"
   (eq status 'initialized)
   (format (concat "workspace status after waiting: %S\n"
                   "    server argv: %S\n"
                   "    *lsp-log* tail:\n%s")
           status command (test-lsp--lsp-log-tail)))
  (test-lsp--check
   "that server was launched through emacs-lsp-booster"
   (and (boundp 'config/lsp-booster-executable)
        (equal (car command) config/lsp-booster-executable))
   (format "server argv: %S" command)))

;;
;; ── Report ───────────────────────────────────────────────────────────────────

(message "")
(message "[LSP TEST] ================================================")
(dolist (p (reverse test-lsp--passes))
  (message "[LSP TEST] PASS: %s" p))
(dolist (f (reverse test-lsp--failures))
  (message "[LSP TEST] FAIL: %s" f))
(message "[LSP TEST] ================================================")
(message "[LSP TEST] %d passed, %d failed"
         (length test-lsp--passes) (length test-lsp--failures))
(kill-emacs (if test-lsp--failures 1 0))

(provide 'test-lsp)
;;; test-lsp.el ends here
