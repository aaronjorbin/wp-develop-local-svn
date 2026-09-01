#!/bin/sh
set -e

# Working repo: people check this out and test hook scripts against it.
REPO_PATH="${REPO_PATH:-/svn/repo}"
# Mirror repo: svnsync target for https://develop.svn.wordpress.org.
# Never checked out or committed to directly; `make refresh` hotcopies it
# into REPO_PATH.
MIRROR_PATH="${MIRROR_PATH:-/svn/mirror}"

svnserve_conf() {
    cat > "$1/conf/svnserve.conf" <<'EOF'
[general]
anon-access = write
auth-access = write
EOF
}

if [ ! -d "$REPO_PATH" ]; then
    echo "Creating working repo at $REPO_PATH"
    svnadmin create "$REPO_PATH"

    cp /hooks/* "$REPO_PATH/hooks/" 2>/dev/null || true
    chmod +x "$REPO_PATH"/hooks/* 2>/dev/null || true
    rm -f "$REPO_PATH"/hooks/*.tmpl

    svnserve_conf "$REPO_PATH"

    mkdir -p /tmp/skel/trunk /tmp/skel/branches /tmp/skel/tags
    svn import /tmp/skel "file://$REPO_PATH" -m "Initial repository layout: trunk, branches, tags"
    rm -rf /tmp/skel
fi

if [ ! -d "$MIRROR_PATH" ]; then
    echo "Creating mirror repo at $MIRROR_PATH"
    svnadmin create "$MIRROR_PATH"
    svnserve_conf "$MIRROR_PATH"

    # svnsync needs to write svn:sync-* / svn:author / svn:date revprops.
    cat > "$MIRROR_PATH/hooks/pre-revprop-change" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "$MIRROR_PATH/hooks/pre-revprop-change"
fi
