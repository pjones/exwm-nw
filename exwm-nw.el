;;; exwm-nw.el --- Named workspaces for EXWM. -*- lexical-binding: t -*-

;; Copyright (C) 2018 Peter Jones <pjones@devalot.com>

;; Author: Peter Jones <pjones@devalot.com>
;; Homepage: https://github.com/pjones/exwm-nw
;; Package-Requires: ((emacs "24.4") (exwm "0.18"))
;; Version: 0.1.0
;;
;; This file is not part of GNU Emacs.

;;; Commentary:
;;
;; FIXME:

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

(defvar exwm-nw-prev-workspace-index-map exwm-workspace-index-map
  "Used to restore the previous value of `exwm-workspace-index-map'.")

(defvar exwm-nw-workspace-ring nil
  "Ring of workspaces.")

(defvar exwm-nw--previous-workspace nil
  "Remember the previous workspace.")


;; Internal Functions
(defun exwm-nw-set-name-prompt (workspace)
  "Prompt for the new name of WORKSPACE."
  (read-string "Workspace Name: " (exwm-nw-get workspace)))

(defun exwm-nw-get (frame-or-index)
  "Return the name of the workspace identified by FRAME-OR-INDEX."
  (let ((ws (exwm-workspace--workspace-from-frame-or-index frame-or-index)))
    (frame-parameter ws 'exwm-nw-name)))

(defun exwm-nw-format (index)
  "Format the name of the workspace at INDEX."
  (let ((name (exwm-nw-get index)))
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
     exwm-nw-workspace-ring
     exwm-nw--previous-workspace)))

(defun exwm-nw--goto-workspace (workspace)
  "Go to WORKSPACE doing the right thing with the minibuffer."
  (if (minibuffer-window-active-p (selected-window))
      (let ((pos (exwm-workspace--position workspace)))
        (when pos
          (goto-history-element (+ 1 pos))
          (exit-minibuffer)))
    (exwm-workspace-switch workspace)))


;; Public functions:

;;;###autoload
(defun exwm-nw-set (frame-or-index &optional name)
  "Set workspace name for FRAME-OR-INDEX to NAME.

You probably want to bind this function to a key in
`exwm-nw-mode-map'."
  (interactive (list exwm-workspace--current nil))
  (let* ((ws (exwm-workspace--workspace-from-frame-or-index frame-or-index))
         (name (or name (exwm-nw-set-name-prompt ws))))
    (when (and ws name)
      (set-frame-parameter ws 'exwm-nw-name name)
      (setq exwm-workspace--switch-history-outdated t))))

;;;###autoload
(defun exwm-nw-goto-previous ()
  "Switch to the previous workspace.

You may want to bind this function to a key in `exwm-nw-mode-map'
and in `exwm-workspace--switch-map'."
  (interactive)
  (let ((ws (ring-ref exwm-nw-workspace-ring 0)))
    (when ws (exwm-nw--goto-workspace ws))))

;;;###autoload
(define-minor-mode exwm-nw-mode
  "Global minor mode that helps manage workspaces in EXWM.

Some of its features are:

  - Assign a name to a workspace (`exwm-nw-set')
  - Keep a history of workspaces in a ring
  - Jump to the previous workspace (`exwm-nw-goto-previous')

By default this minor mode does not have any keybindings in order
to avoid clobbering any bindings you may already have.  Here are
some recommendations:


    (define-key exwm-nw-mode-map (kbd \"s-n\") 'exwm-nw-set)
    (define-key exwm-nw-mode-map (kbd \"s-l\") 'exwm-nw-goto-previous)
    (define-key exwm-workspace--switch-map (kbd \"C-l\") 'exwm-nw-goto-previous)

Enjoy!"
  :group  'exwm-nw
  :keymap 'exwm-nw-mode-map
  :global t
  (if exwm-nw-mode
      (progn
        (setq exwm-nw-prev-workspace-index-map exwm-workspace-index-map
              exwm-workspace-index-map #'exwm-nw-format
              exwm-nw-workspace-ring (make-ring exwm-nw-workspace-ring-size))
        (add-hook 'exwm-workspace-switch-hook #'exwm-nw--workspace-switch-hook)
        (advice-add 'exwm-workspace-switch :before #'exwm-nw--remember-current-workspace))
    (setq exwm-workspace-index-map exwm-nw-prev-workspace-index-map)
    (remove-hook 'exwm-workspace-switch-hook #'exwm-nw--workspace-switch-hook)
    (advice-remove 'exwm-workspace-switch #'exwm-nw--remember-current-workspace)))

(provide 'exwm-nw)
;;; exwm-nw.el ends here