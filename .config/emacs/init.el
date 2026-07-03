;;; init.el --- Emacs initialization -*- lexical-binding: t; -*-

(make-directory (file-name-directory custom-file) t)
(load custom-file 'noerror 'nomessage)

(org-babel-load-file (expand-file-name "config.org" user-emacs-directory))
