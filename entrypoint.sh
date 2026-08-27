#!/bin/sh
set -e

/usr/local/bin/create-repo.sh

exec svnserve -d --foreground -r /svn --listen-port 15705
