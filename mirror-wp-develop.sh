#!/bin/sh
# Run this from your local machine (needs a local `svn`/`svnsync` client and
# `docker compose` access to this project). It turns the repo inside the
# running container into an svnsync mirror of
# https://develop.svn.wordpress.org.
#
# The first run wipes the current repo and initializes the mirror. Re-running
# this script does NOT wipe again — it just resumes/continues the sync,
# so it's safe to Ctrl-C a long sync and re-run later.
#
# Usage:
#   ./mirror-wp-develop.sh
#   STEAL_LOCK=1 ./mirror-wp-develop.sh   # after an unclean kill left a stale sync lock
set -e

SERVICE="${SERVICE:-svn}"
REPO_PATH_IN_CONTAINER="${REPO_PATH:-/svn/repo}"
SOURCE_URL="https://develop.svn.wordpress.org"
TARGET_URL="svn://localhost:15705/repo"

command -v svnsync >/dev/null 2>&1 || { echo "svnsync not found locally. Install subversion (e.g. 'brew install subversion')." >&2; exit 1; }

ALREADY_MIRROR=$(docker compose exec -T "$SERVICE" sh -c "svnlook propget --revprop -r0 '$REPO_PATH_IN_CONTAINER' svn:sync-from-url 2>/dev/null" || true)

if [ -z "$ALREADY_MIRROR" ]; then
    echo "==> No existing mirror found. Resetting repo inside the '$SERVICE' container"
    docker compose exec -T "$SERVICE" sh -c "
        set -e
        rm -rf '$REPO_PATH_IN_CONTAINER'
        svnadmin create '$REPO_PATH_IN_CONTAINER'
        cp /hooks/* '$REPO_PATH_IN_CONTAINER/hooks/'
        chmod +x '$REPO_PATH_IN_CONTAINER'/hooks/*
        rm -f '$REPO_PATH_IN_CONTAINER'/hooks/*.tmpl
        cat > '$REPO_PATH_IN_CONTAINER/conf/svnserve.conf' <<'EOF'
[general]
anon-access = write
auth-access = write
EOF
    "
else
    echo "==> Existing mirror found (source: $ALREADY_MIRROR). Resuming sync."
fi

echo "==> Temporarily allowing revprop changes (required by svnsync)"
docker compose exec -T "$SERVICE" sh -c "cat > '$REPO_PATH_IN_CONTAINER/hooks/pre-revprop-change' <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x '$REPO_PATH_IN_CONTAINER/hooks/pre-revprop-change'"

if [ -z "$ALREADY_MIRROR" ]; then
    echo "==> Initializing sync from $SOURCE_URL"
    svnsync init "$TARGET_URL" "$SOURCE_URL"
fi

echo "==> Syncing revision history (this can take a while for the full history)"
if [ -n "$STEAL_LOCK" ]; then
    svnsync sync --steal-lock "$TARGET_URL"
else
    svnsync sync "$TARGET_URL"
fi

echo "==> Restoring the test pre-revprop-change hook"
docker compose cp hooks/pre-revprop-change "$SERVICE":"$REPO_PATH_IN_CONTAINER/hooks/pre-revprop-change"
docker compose exec -T "$SERVICE" chmod +x "$REPO_PATH_IN_CONTAINER/hooks/pre-revprop-change"

echo "==> Done. $TARGET_URL now mirrors $SOURCE_URL"
