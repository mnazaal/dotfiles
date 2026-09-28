# Interactive login bash (ssh to a cluster) reads only this file; keep one
# copy of the zsh-exec and ~/.localenv logic, in .bashrc. Non-interactive login
# shells (#!/bin/bash -l batch jobs) are left as they were.
case $- in
*i*) [ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc" ;;
esac
