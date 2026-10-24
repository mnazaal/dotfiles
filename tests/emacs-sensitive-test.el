;;; emacs-sensitive-test.el --- exercise security settings from config.org -*- lexical-binding: t; -*-

(let* ((repo (expand-file-name ".." (file-name-directory load-file-name)))
       (config (expand-file-name ".config/emacs/config.org" repo))
       (start "(defvar sensitive-file-regexps"))
  ;; Evaluate the actual forms, without loading the unrelated package setup.
  (with-temp-buffer
    (insert-file-contents config)
    (goto-char (point-min))
    (unless (search-forward start nil t)
      (error "sensitive-file-regexps is missing"))
    (backward-char (length start))
    (eval (read (current-buffer)))
    (eval (read (current-buffer)))) ; backup-enable-predicate
  (dolist (name '(".env" ".env.local" "secret.gpg" ".npmrc"))
    (when (funcall backup-enable-predicate (concat "/home/test/" name))
      (error "Backup allowed for %s" name)))
  (unless (funcall backup-enable-predicate "/home/test/readme.txt")
    (error "Ordinary backup was disabled"))
  (with-temp-buffer
    (insert-file-contents config)
    (goto-char (point-min))
    (let ((hook-start "(add-hook 'find-file-hook"))
      (unless (search-forward hook-start nil t)
        (error "Sensitive autosave hook is missing"))
      (backward-char (length hook-start))
      (eval (read (current-buffer)))))
  (dolist (name '(".env" ".env.local" "secret.gpg" ".npmrc"))
    (with-temp-buffer
      (setq buffer-file-name (concat "/home/test/" name))
      (auto-save-mode 1)
      (run-hooks 'find-file-hook)
      (when buffer-auto-save-file-name
        (error "Autosave allowed for %s" name))))
  (with-temp-buffer
    (setq buffer-file-name "/home/test/readme.txt")
    (auto-save-mode 1)
    (run-hooks 'find-file-hook)
    (unless buffer-auto-save-file-name
      (error "Ordinary autosave was disabled")))
  (princ "emacs sensitive files: backup and autosave policy pass\n"))
