#!/usr/bin/env bash
input=$(cat)
model=$(echo "$input" | jq -r '.model.id')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

left="<- for agents"
if [ -n "$used" ]; then
	right="${model} $(printf '%.0f' "$used")%"
else
	right="${model}"
fi

cols=$(tput cols 2>/dev/null || echo 80)
pad=$((cols - ${#left} - ${#right} - 1))
[ "$pad" -lt 1 ] && pad=1
printf "%s%*s%s" "$left" "$pad" "" "$right"
