#!/bin/sh
# Sync the dedicated mirror repo (svn://localhost:15705/mirror) with
# https://develop.svn.wordpress.org via svnsync.
#
# This only touches the MIRROR repo. The working repo people check out
# (svn://localhost:15705/repo) is left alone — run `make refresh` to copy
# the mirror into it.
#
# The first run initializes the svnsync link. Re-running just resumes the
# sync, so it's safe to Ctrl-C a long sync and re-run later.
#
# Usage (via Makefile):
#   make sync
#   STEAL_LOCK=1 make sync   # after an unclean kill left a stale sync lock
#
# Or directly:
#   ./mirror-wp-develop.sh
set -e

SERVICE="${SERVICE:-svn}"
MIRROR_PATH_IN_CONTAINER="${MIRROR_PATH:-/svn/mirror}"
SOURCE_URL="https://develop.svn.wordpress.org"
TARGET_URL="svn://localhost:15705/mirror"

command -v svnsync >/dev/null 2>&1 || { echo "svnsync not found locally. Install subversion (e.g. 'brew install subversion')." >&2; exit 1; }

docker compose exec -T "$SERVICE" test -d "$MIRROR_PATH_IN_CONTAINER" \
    || { echo "Mirror repo $MIRROR_PATH_IN_CONTAINER not found in '$SERVICE'. Is the container up ('make up')?" >&2; exit 1; }

ALREADY_INIT=$(docker compose exec -T "$SERVICE" sh -c "svnlook propget --revprop -r0 '$MIRROR_PATH_IN_CONTAINER' svn:sync-from-url 2>/dev/null" || true)

if [ -z "$ALREADY_INIT" ]; then
    echo "==> Initializing svnsync: $TARGET_URL <- $SOURCE_URL"
    svnsync init "$TARGET_URL" "$SOURCE_URL"
else
    echo "==> Mirror already initialized (source: $ALREADY_INIT). Resuming."
fi

echo "==> Syncing revision history (full history is large; safe to Ctrl-C and re-run)"
if [ -n "$STEAL_LOCK" ]; then
    svnsync sync --steal-lock "$TARGET_URL"
else
    svnsync sync "$TARGET_URL"
fi

echo "==> Done. $TARGET_URL now mirrors $SOURCE_URL"
