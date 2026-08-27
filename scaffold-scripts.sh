#!/bin/sh
# scaffold-scripts.sh
#
# Writes basic versions of each standard SVN hook into the hooks/ directory.
# These are the same no-op / default-deny scripts documented in the README.
#
# Usage:
#   ./scaffold-scripts.sh [--override] [--hook=NAME]
#
# Options:
#   --override      Overwrite hook files that already exist. Without this,
#                   existing files are left untouched and reported as skipped.
#   --hook=NAME     Only scaffold the named hook (e.g. --hook=pre-commit).
#                   May be repeated to scaffold several specific hooks.
#   --help, -h      Show this help and exit.
#
# Valid hook names:
#   start-commit, pre-commit, post-commit, pre-revprop-change,
#   post-revprop-change, pre-lock, post-lock, pre-unlock, post-unlock

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HOOKS_DIR="$SCRIPT_DIR/hooks"

ALL_HOOKS="start-commit pre-commit post-commit pre-revprop-change post-revprop-change pre-lock post-lock pre-unlock post-unlock"

OVERRIDE=0
SELECTED=""

usage() {
	sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
}

is_valid_hook() {
	for h in $ALL_HOOKS; do
		[ "$h" = "$1" ] && return 0
	done
	return 1
}

for arg in "$@"; do
	case "$arg" in
		--override)
			OVERRIDE=1
			;;
		--hook=*)
			name=${arg#--hook=}
			if ! is_valid_hook "$name"; then
				echo "Unknown hook: $name" >&2
				echo "Valid hooks: $ALL_HOOKS" >&2
				exit 1
			fi
			SELECTED="$SELECTED $name"
			;;
		--help|-h)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $arg" >&2
			echo "Try '$0 --help' for usage." >&2
			exit 1
			;;
	esac
done

[ -n "$SELECTED" ] || SELECTED="$ALL_HOOKS"

mkdir -p "$HOOKS_DIR"

hook_body() {
	case "$1" in
		start-commit)
			cat <<'EOF'
#!/bin/sh
# start-commit REPOS-PATH USER CAPABILITIES TXN-NAME
REPOS="$1"
USER="$2"
CAPABILITIES="$3"
TXN_NAME="$4"

exit 0
EOF
			;;
		pre-commit)
			cat <<'EOF'
#!/bin/sh
# pre-commit REPOS-PATH TXN-NAME
REPOS="$1"
TXN="$2"

SVNLOOK=/usr/bin/svnlook

exit 0
EOF
			;;
		post-commit)
			cat <<'EOF'
#!/bin/sh
# post-commit REPOS-PATH REV TXN-NAME
REPOS="$1"
REV="$2"
TXN="$3"

SVNLOOK=/usr/bin/svnlook

exit 0
EOF
			;;
		pre-revprop-change)
			cat <<'EOF'
#!/bin/sh
# pre-revprop-change REPOS-PATH REV USER PROPNAME ACTION
REPOS="$1"
REV="$2"
USER="$3"
PROPNAME="$4"
ACTION="$5"

# Allow svn:log edits by default for testing; deny everything else.
if [ "$PROPNAME" = "svn:log" ] && [ "$ACTION" = "M" ]; then
    exit 0
fi

echo "Changing revision property '$PROPNAME' is not allowed." >&2
exit 1
EOF
			;;
		post-revprop-change)
			cat <<'EOF'
#!/bin/sh
# post-revprop-change REPOS-PATH REV USER PROPNAME ACTION
REPOS="$1"
REV="$2"
USER="$3"
PROPNAME="$4"
ACTION="$5"

SVNLOOK=/usr/bin/svnlook

exit 0
EOF
			;;
		pre-lock)
			cat <<'EOF'
#!/bin/sh
# pre-lock REPOS-PATH PATH USER COMMENT STEAL-LOCK
REPOS="$1"
PATH_="$2"
USER="$3"
COMMENT="$4"
STEAL="$5"

exit 0
EOF
			;;
		post-lock)
			cat <<'EOF'
#!/bin/sh
# post-lock REPOS-PATH USER
REPOS="$1"
USER="$2"

SVNLOOK=/usr/bin/svnlook

exit 0
EOF
			;;
		pre-unlock)
			cat <<'EOF'
#!/bin/sh
# pre-unlock REPOS-PATH PATH USER TOKEN BREAK-UNLOCK
REPOS="$1"
PATH_="$2"
USER="$3"
TOKEN="$4"
BREAK="$5"

exit 0
EOF
			;;
		post-unlock)
			cat <<'EOF'
#!/bin/sh
# post-unlock REPOS-PATH USER
REPOS="$1"
USER="$2"

SVNLOOK=/usr/bin/svnlook

exit 0
EOF
			;;
	esac
}

for hook in $SELECTED; do
	target="$HOOKS_DIR/$hook"
	if [ -e "$target" ] && [ "$OVERRIDE" -ne 1 ]; then
		echo "skip    $hook (exists; use --override)"
		continue
	fi
	hook_body "$hook" > "$target"
	chmod +x "$target"
	echo "write   $hook"
done
