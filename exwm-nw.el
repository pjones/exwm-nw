;;; exwm-nw.el --- Named workspaces for EXWM. -*- lexical-binding: t -*-

;; Copyright (C) 2018-2019 Peter Jones <pjones@devalot.com>

;; Author: Peter Jones <pjones@devalot.com>
;; Homepage: https://github.com/pjones/exwm-nw
;; Package-Requires: ((emacs "25.1") (exwm "0.18"))
;; Version: 0.2.0
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;;
;; Assign names to EXWM worspaces and jump to workspaces using their
;; names.  See the documentation for `exwm-nw-mode'.

;;; License:
;;
;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; "Software"), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
;; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
;; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
;; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; Code:
(require 'ring)
(require 'map)
(require 'exwm)


;; Customize interface:
(defgroup exwm-nw nil
  "A minor mode and functions for naming and managing EXWM
workspaces."
  :version "25.3"
  :group 'applications)

(defcustom exwm-nw-workspace-ring-size 5
  "Number of workspaces to keep in the history ring."
  :group 'exwm-nw
  :type 'integer)


;; Internal variables:
(defvar exwm-nw-mode-map (make-sparse-keymap)
  "Key map for the `exwm-nw' minor mode.")

(defvar exwm-nw--prev-workspace-index-map exwm-workspace-index-map
  "Used to restore the previous value of `exwm-workspace-index-map'.")

(defvar exwm-nw--workspace-ring nil
  "Ring of workspaces.")

(defvar exwm-nw--previous-workspace nil
  "Remember the previous workspace.")


;; Internal Functions
(defun exwm-nw--set-name-prompt (workspace)
  "Prompt for the new name of WORKSPACE."
  (read-string "Workspace name: " (exwm-nw-get-name workspace)))

(defun exwm-nw--format (index)
  "Format the name of the workspace at INDEX."
  (let ((name (exwm-nw-get-name index)))
    (if name (format "%s:%s" index name)
      (number-to-string index))))

(defun exwm-nw--remember-current-workspace (&rest _args)
  "Record the current workspace before it becomes the previous."
  (setq exwm-nw--previous-workspace exwm-workspace--current))

(defun exwm-nw--workspace-switch-hook ()
  "Respond to EXWM switching workspaces."
  (when (and exwm-nw--previous-workspace
             (not (equal exwm-nw--previous-workspace
                         exwm-workspace--current)))
    (ring-remove+insert+extend
     exwm-nw--workspace-ring
     exwm-nw--previous-workspace)))

(defun exwm-nw--goto-workspace (workspace)
  "Go to WORKSPACE doing the right thing with the minibuffer."
  (if (minibuffer-window-active-p (selected-window))
      (let ((pos (exwm-workspace--position workspace)))
        (when pos
          (goto-history-element (+ 1 pos))
          (exit-minibuffer)))
    (exwm-workspace-switch workspace)))

(defun exwm-nw--workspace-alist (keep-current)
  "Return an alist of workspace names and their indexes.

When KEEP-CURRENT is non-nil then the current workspace will be
included in the returned alist.

The alist is ordered so that recently visited workspaces come first."
  (let ((current exwm-workspace--current) names)
    (dolist (w (append (ring-elements exwm-nw--workspace-ring)
                       exwm-workspace--list))
      (if (and (exwm-workspace--workspace-p w)
               (or keep-current (not (eq w current))))
          (let* ((pos (exwm-workspace--position w))
                 (name (exwm-nw--format pos)))
            (if (and name (not (assoc name names)))
                (setq names (append names (list (cons name pos))))))))
    names))

(defun exwm-nw--current ()
  "Return the currently selected or active workspace."
  (if (minibuffer-window-active-p (selected-window))
      (exwm-workspace--workspace-from-frame-or-index (1- minibuffer-history-position))
    exwm-workspace--current))

(defun exwm-nw--move (workspace offset)
  "Move WORKSPACE by OFFSET spaces."
  (let ((pos (+ (exwm-workspace--position workspace) offset))
        (switching (minibuffer-window-active-p (selected-window))))
    (exwm-workspace-move workspace pos)
    (when (and switching (not (minibuffer-window-active-p (selected-window))))
      (call-interactively 'exwm-workspace-switch))))

;; Public functions:
;;;###autoload
(defun exwm-nw-get-name (&optional frame-or-index)
  "Return the name of the workspace identified by FRAME-OR-INDEX.
If FRAME-OR-INDEX is not given or nil then return the name of the
current workspace."
  (let* ((frame (or frame-or-index exwm-workspace--current))
         (ws (exwm-workspace--workspace-from-frame-or-index frame))
         (name (frame-parameter ws 'exwm-nw-name)))
    (and name (substring-no-properties name))))

;;;###autoload
(defun exwm-nw-set-name (frame-or-index &optional name)
  "Set workspace name for FRAME-OR-INDEX to NAME.

You probably want to bind this function to a key in
`exwm-nw-mode-map' and/or `exwm-workspace--switch-map'."
  (interactive (list (exwm-nw--current) nil))
  (let* ((ws (exwm-workspace--workspace-from-frame-or-index frame-or-index))
         (name (or name (exwm-nw--set-name-prompt ws))))
    (when (and ws name)
      (set-frame-parameter ws 'exwm-nw-name name)
      (setq exwm-workspace--switch-history-outdated t)
      (when (minibuffer-window-active-p (selected-window))
        (exwm-workspace--update-switch-history)
        (goto-history-element minibuffer-history-position)))))

;;;###autoload
(defun exwm-nw-goto-previous ()
  "Switch to the previous workspace.

You may want to bind this function to a key in `exwm-nw-mode-map'
and in `exwm-workspace--switch-map'."
  (interactive)
  (let ((ws (ring-ref exwm-nw--workspace-ring 0)))
    (when ws (exwm-nw--goto-workspace ws))))

;;;###autoload
(defun exwm-nw-find-workspace (allow-create)
  "Pick a workspace from a completion list and go there.

When ALLOW-CREATE is non-nil, allow creating new workspaces."
  (interactive "P")
  (let* ((names (exwm-nw--workspace-alist nil))
         (must-match (if allow-create 'confirm t))
         (result (completing-read "Workspace: " names nil must-match))
         (selected (cdr (assoc result names))))
    (if selected (exwm-nw--goto-workspace
                  (exwm-workspace--workspace-from-frame-or-index selected))
      (when allow-create
        (if (minibuffer-window-active-p (selected-window))
            (let ((exwm-workspace--prompt-add-allowed t))
              (exwm-workspace--prompt-add)
              (let* ((n (1- (exwm-workspace--count)))
                     (ws (exwm-workspace--workspace-from-frame-or-index n)))
                (exwm-nw-set-name ws result)
                (exwm-nw--goto-workspace ws)))
          (exwm-nw-set-name (make-frame) result))))))

;;;###autoload
(defun exwm-nw-move-left (workspace)
  "Move WORKSPACE one position to the left."
  (interactive (list (exwm-nw--current)))
  (exwm-nw--move workspace -1))

;;;###autoload
(defun exwm-nw-move-right (workspace)
  "Move WORKSPACE one position to the right."
  (interactive (list (exwm-nw--current)))
  (exwm-nw--move workspace 1))

;;;###autoload
(define-minor-mode exwm-nw-mode
  "Global minor mode that helps manage workspaces in EXWM.

Some of its features are:

  - Keep a history of workspaces in a ring
  - Assign a name to a workspace (`exwm-nw-set-name')
  - Jump to the previous workspace (`exwm-nw-goto-previous')
  - Jump to a workspace by name (`exwm-nw-find-workspace')

By default this minor mode does not have any keybindings in order
to avoid clobbering any bindings you may already have.  Here are
some recommendations:

    (define-key exwm-nw-mode-map (kbd \"s-n\") 'exwm-nw-set-name)
    (define-key exwm-nw-mode-map (kbd \"s-l\") 'exwm-nw-goto-previous)
    (define-key exwm-workspace--switch-map (kbd \"C-u\") 'universal-argument)
    (define-key exwm-workspace--switch-map (kbd \"C-s\") 'exwm-nw-find-workspace)
    (define-key exwm-workspace--switch-map (kbd \"C-l\") 'exwm-nw-goto-previous)
    (define-key exwm-workspace--switch-map (kbd \"C-c C-n\") 'exwm-nw-set-name)

Enjoy!"
  :group  'exwm-nw
  :require 'exwm-nw
  :keymap 'exwm-nw-mode-map
  :global t
  (if exwm-nw-mode
      (progn
        (setq exwm-nw--prev-workspace-index-map exwm-workspace-index-map
              exwm-workspace-index-map #'exwm-nw--format
              exwm-nw--workspace-ring (make-ring exwm-nw-workspace-ring-size))
        (add-hook 'exwm-workspace-switch-hook #'exwm-nw--workspace-switch-hook)
        (advice-add 'exwm-workspace-switch :before #'exwm-nw--remember-current-workspace))
    (setq exwm-workspace-index-map exwm-nw--prev-workspace-index-map)
    (remove-hook 'exwm-workspace-switch-hook #'exwm-nw--workspace-switch-hook)
    (advice-remove 'exwm-workspace-switch #'exwm-nw--remember-current-workspace)))

(provide 'exwm-nw)
;;; exwm-nw.el ends here
