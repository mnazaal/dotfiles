#!/usr/bin/env bash
# pass obfs stores pass entries under obfuscated filenames.
#
# It keeps an encrypted mapping from human-readable names to random IDs so the
# pass store can be pushed to a public Git repo without leaking service names.
#
# Usage:
#   pass obfs show NAME           Show entry by real name
#   pass obfs insert NAME [OPTS]  Insert new entry with obfuscated filename
#   pass obfs generate NAME [LEN] Generate password with obfuscated filename
#   pass obfs edit NAME           Edit entry by real name
#   pass obfs ls                  List all real names
#   pass obfs rm NAME             Remove entry
#   pass obfs migrate NAME        Migrate an existing plain-named entry
#   pass obfs help                Show this help

set -euo pipefail

MAP_FILE="$PREFIX/.name-map.gpg"

_gpg_id() {
	cat "$PREFIX/.gpg-id"
}

_decrypt_map() {
	[[ -f "$MAP_FILE" ]] || return 0
	$GPG -d --quiet --yes --batch --for-your-eyes-only --no-tty $GPG_OPTS "$MAP_FILE" || {
		echo "Error: failed to decrypt mapping file" >&2
		exit 1
	}
}

_save_map() {
	local content="$1"
	local gpg_id tmp_file
	gpg_id="$(_gpg_id)"
	tmp_file="$(mktemp "$PREFIX/.name-map.XXXXXX")"
	trap 'rm -f "$tmp_file"' EXIT

	if [[ -n "$content" ]]; then
		echo "$content" | $GPG -e -r "$gpg_id" --quiet --yes --batch -o "$tmp_file" || {
			rm -f "$tmp_file"
			echo "Error: failed to encrypt mapping file" >&2
			exit 1
		}
	else
		echo "" | $GPG -e -r "$gpg_id" --quiet --yes --batch -o "$tmp_file" || {
			rm -f "$tmp_file"
			echo "Error: failed to encrypt mapping file" >&2
			exit 1
		}
	fi

	chmod 0600 "$tmp_file"
	mv -f "$tmp_file" "$MAP_FILE"
	trap - EXIT
}

_lookup() {
	local name="$1"
	_decrypt_map | while IFS=$'\t' read -r n h; do
		[[ "$n" == "$name" ]] && echo "$h" && return
	done
}

_add_mapping() {
	local name="$1" hash="$2"
	local map
	map="$(_decrypt_map)"
	if [[ -n "$map" ]]; then
		map="${map}"$'\n'"${name}	${hash}"
	else
		map="${name}	${hash}"
	fi
	_save_map "$map"
}

_remove_mapping() {
	local name="$1"
	local map
	map="$(_decrypt_map | while IFS=$'\t' read -r n h; do
		[[ "$n" != "$name" ]] && printf '%s\t%s\n' "$n" "$h"
	done)"
	_save_map "$map"
}

_gen_id() {
	od -An -tx1 -N16 /dev/urandom | tr -d ' \n'
}

_validate_name() {
	local name="$1"
	if [[ -z "$name" ]]; then
		echo "Error: entry name cannot be empty" >&2
		exit 1
	fi
	if [[ "$name" =~ [[:cntrl:]] ]] || [[ "$name" == *$'\t'* ]]; then
		echo "Error: entry name cannot contain tabs or control characters" >&2
		exit 1
	fi
	if [[ "$name" == *"/"* ]] || [[ "$name" == *".."* ]]; then
		echo "Error: entry name cannot contain path separators" >&2
		exit 1
	fi
	if [[ "$name" != "${name#"${name%%[![:space:]]*}"}" ]] || [[ "$name" != "${name%"${name##*[![:space:]]}"}" ]]; then
		echo "Error: entry name cannot have leading or trailing whitespace" >&2
		exit 1
	fi
}

_require_map() {
	if [[ ! -f "$MAP_FILE" ]]; then
		echo "Mapping not initialized. Run: pass obfs insert NAME" >&2
		exit 1
	fi
}

case "${1:-}" in
show)
	[[ -z "${2:-}" ]] && echo "Usage: pass obfs show NAME" >&2 && exit 1
	_validate_name "$2"
	_require_map
	hash="$(_lookup "$2")"
	[[ -z "$hash" ]] && echo "Error: '$2' not found in mapping" >&2 && exit 1
	pass show "$hash"
	;;
insert)
	[[ -z "${2:-}" ]] && echo "Usage: pass obfs insert NAME" >&2 && exit 1
	_validate_name "$2"
	name="$2"
	existing="$(_lookup "$name")"
	if [[ -n "$existing" ]]; then
		echo "Entry '$name' already exists" >&2
		exit 1
	fi
	hash="$(_gen_id)"
	shift 2
	pass insert "$hash" "$@" || exit 1
	_add_mapping "$name" "$hash"
	echo "Mapped '$name' -> '$hash'"
	;;
generate)
	[[ -z "${2:-}" ]] && echo "Usage: pass obfs generate NAME [LEN]" >&2 && exit 1
	_validate_name "$2"
	name="$2"
	existing="$(_lookup "$name")"
	if [[ -n "$existing" ]]; then
		shift 2
		pass generate "$existing" "$@"
	else
		hash="$(_gen_id)"
		shift 2
		pass generate "$hash" "$@" || exit 1
		_add_mapping "$name" "$hash"
		echo "Mapped '$name' -> '$hash'"
	fi
	;;
edit)
	[[ -z "${2:-}" ]] && echo "Usage: pass obfs edit NAME" >&2 && exit 1
	_validate_name "$2"
	_require_map
	hash="$(_lookup "$2")"
	[[ -z "$hash" ]] && echo "Error: '$2' not found in mapping" >&2 && exit 1
	pass edit "$hash"
	;;
ls | list)
	_require_map
	_decrypt_map | while IFS=$'\t' read -r name hash; do
		[[ -n "$name" ]] && echo "$name"
	done
	;;
rm | remove)
	[[ -z "${2:-}" ]] && echo "Usage: pass obfs rm NAME" >&2 && exit 1
	_validate_name "$2"
	_require_map
	name="$2"
	hash="$(_lookup "$name")"
	[[ -z "$hash" ]] && echo "Error: '$name' not found in mapping" >&2 && exit 1
	pass rm "$hash" || exit 1
	_remove_mapping "$name"
	echo "Removed '$name'"
	;;
migrate)
	[[ -z "${2:-}" ]] && echo "Usage: pass obfs migrate NAME" >&2 && exit 1
	_validate_name "$2"
	name="$2"
	existing="$(_lookup "$name")"
	if [[ -n "$existing" ]]; then
		echo "Entry '$name' is already obfuscated" >&2
		exit 1
	fi
	if [[ ! -f "$PREFIX/${name}.gpg" ]]; then
		echo "Error: no existing pass entry '$name'" >&2
		exit 1
	fi
	hash="$(_gen_id)"
	# Add the mapping first so an interruption does not lose the association.
	_add_mapping "$name" "$hash"
	mv "$PREFIX/${name}.gpg" "$PREFIX/${hash}.gpg"
	chmod 0600 "$PREFIX/${hash}.gpg"
	# Remove any empty parent directories left behind.
	parent="$(dirname "$PREFIX/${name}.gpg")"
	while [[ "$parent" != "$PREFIX" ]] && [[ -d "$parent" ]] && [ -z "$(ls -A "$parent")" ]; do
		rmdir "$parent"
		parent="$(dirname "$parent")"
	done
	echo "Migrated '$name' -> '$hash'"
	;;
help | --help | -h)
	cat <<-EOF
		Usage:
		  pass obfs show NAME           Show entry
		  pass obfs insert NAME [OPTS]  Insert new entry
		  pass obfs generate NAME [LEN] Generate password
		  pass obfs edit NAME           Edit entry
		  pass obfs ls                  List all real names
		  pass obfs rm NAME             Remove entry
		  pass obfs migrate NAME        Migrate existing plain entry
	EOF
	;;
*)
	[[ -n "${1:-}" ]] && echo "Unknown command '$1'." >&2
	echo "Try 'pass obfs help'" >&2
	exit 1
	;;
esac
