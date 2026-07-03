#!/bin/sh

case "$1" in
  toggle)
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    ;;
  *)
    info=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
    if echo "$info" | grep -q MUTED; then
      echo " "
    else
      vol=$(echo "$info" | awk '{print int($2*100)}')
      echo " $vol%"
    fi
    ;;
esac
