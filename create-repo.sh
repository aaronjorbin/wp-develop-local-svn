#!/bin/sh
set -e

REPO_PATH="${REPO_PATH:-/svn/repo}"

if [ ! -d "$REPO_PATH" ]; then
    echo "Creating repo at $REPO_PATH"
    svnadmin create "$REPO_PATH"

    cp /hooks/* "$REPO_PATH/hooks/"
    chmod +x "$REPO_PATH"/hooks/*
    rm -f "$REPO_PATH"/hooks/*.tmpl

    # Anonymous read/write for local hook testing convenience.
    cat > "$REPO_PATH/conf/svnserve.conf" <<'EOF'
[general]
anon-access = write
auth-access = write
EOF

    mkdir -p /tmp/skel/trunk /tmp/skel/branches /tmp/skel/tags
    svn import /tmp/skel "file://$REPO_PATH" -m "Initial repository layout: trunk, branches, tags"
    rm -rf /tmp/skel
fi
