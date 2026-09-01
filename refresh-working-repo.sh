#!/bin/sh
# Runs INSIDE the container (invoked by `make refresh`).
#
# Wipes the working repo and replaces it with a hotcopy of the mirror repo,
# then cleans up the svnsync bookkeeping so the result is a plain repo:
#   - drops the svn:sync-* revprops on r0
#   - assigns a fresh UUID (so clients don't conflate it with the mirror)
#   - reinstalls the working hook set from /hooks
set -e

REPO_PATH="${REPO_PATH:-/svn/repo}"
MIRROR_PATH="${MIRROR_PATH:-/svn/mirror}"

[ -d "$MIRROR_PATH" ] || { echo "Mirror repo $MIRROR_PATH not found." >&2; exit 1; }

YOUNGEST=$(svnlook youngest "$MIRROR_PATH" 2>/dev/null || echo 0)
if [ "$YOUNGEST" -eq 0 ]; then
    echo "Mirror repo is empty (youngest rev 0). Run 'make sync' first." >&2
    exit 1
fi

echo "==> Wiping working repo $REPO_PATH"
rm -rf "$REPO_PATH"

echo "==> Hotcopying $MIRROR_PATH -> $REPO_PATH (youngest rev $YOUNGEST)"
svnadmin hotcopy "$MIRROR_PATH" "$REPO_PATH"

echo "==> Stripping svnsync bookkeeping from r0"
# pre-revprop-change carried over from the mirror is allow-all, so these succeed.
for prop in svn:sync-from-url svn:sync-from-uuid svn:sync-last-merged-rev svn:sync-lock svn:sync-currently-copying; do
    svn propdel --revprop -r0 "$prop" "file://$REPO_PATH" 2>/dev/null || true
done

echo "==> Assigning a fresh UUID"
svnadmin setuuid "$REPO_PATH"

echo "==> Reinstalling working hooks"
rm -f "$REPO_PATH"/hooks/*
cp /hooks/* "$REPO_PATH/hooks/" 2>/dev/null || true
chmod +x "$REPO_PATH"/hooks/* 2>/dev/null || true
rm -f "$REPO_PATH"/hooks/*.tmpl

cat > "$REPO_PATH/conf/svnserve.conf" <<'EOF'
[general]
anon-access = write
auth-access = write
EOF

echo "==> Done. svn://localhost:15705/repo now holds a clean copy of the mirror."
