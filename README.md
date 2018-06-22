Named Workspaces for EXWM
=========================

Global minor mode that helps manage workspaces in EXWM.

Some of its features are:

  - Keep a history of workspaces in a ring
  - Assign a name to a workspace (`exwm-nw-set`)
  - Jump to the previous workspace (`exwm-nw-goto-previous`)
  - Jump to a workspace by name (`exwm-nw-find-workspace`)

By default this minor mode does not have any keybindings in order
to avoid clobbering any bindings you may already have.  Here are
some recommendations:

    (define-key exwm-nw-mode-map (kbd "s-n") 'exwm-nw-set)
    (define-key exwm-nw-mode-map (kbd "s-l") 'exwm-nw-goto-previous)
    (define-key exwm-workspace--switch-map (kbd "C-u") 'universal-argument)
    (define-key exwm-workspace--switch-map (kbd "C-s") 'exwm-nw-find-workspace)
    (define-key exwm-workspace--switch-map (kbd "C-l") 'exwm-nw-goto-previous)
