# svn-hook-test

Docker image running a local SVN server for testing hook scripts.

## Overview

- Debian bookworm base with `subversion`, `apache2` + `libapache2-mod-svn`, and `php-cli`.
- `svnlook` is installed at `/usr/bin/svnlook` (part of the `subversion` package).
- `php` is symlinked to `/usr/local/bin/php`.
- On container start, `entrypoint.sh` runs `create-repo.sh`, which:
  - Creates a repo at `/svn/repo` with `svnadmin create` (only if it doesn't already exist — persists across restarts via the `svn-data` volume).
  - Copies the hook scripts from `hooks/` into the repo's `hooks/` directory.
  - Imports a standard `trunk/`, `branches/`, `tags/` layout as the initial commit.
  - Sets `anon-access = write` in `svnserve.conf` for easy local testing (no auth required).
- `svnserve` is then started in the foreground on port 15705.

### Hook scripts (`hooks/`)

The `hooks/` directory holds basic versions of the 9 standard SVN hooks:

`start-commit`, `pre-commit`, `post-commit`, `pre-revprop-change`, `post-revprop-change`, `pre-lock`, `post-lock`, `pre-unlock`, `post-unlock`

All are plain `/bin/sh` scripts that assign the hook's positional args to named variables and `exit 0`. The exception is `pre-revprop-change`, which allows `svn:log` modifications and denies every other revprop change, matching SVN's default-deny behavior. `pre-commit`, `post-commit`, `post-revprop-change`, and `post-lock`/`post-unlock` also set `SVNLOOK=/usr/bin/svnlook` for convenience.

The directory's contents are gitignored (only `.gitignore` and `.gitkeep` are tracked), so a fresh checkout has no hook files. Run `./scaffold-scripts.sh` to (re)create them — see below.

At build time `Dockerfile` copies `hooks/` into the image; on first repo creation `create-repo.sh` copies them into `/svn/repo/hooks/`, marks them executable, and removes the `*.tmpl` files SVN generates. Edit the scripts under `hooks/` to add the logic you're testing, then rebuild the image (or `docker cp` the file into a running container's `/svn/repo/hooks/` for quick iteration).

### Scaffolding the hooks (`scaffold-scripts.sh`)

`./scaffold-scripts.sh` writes the basic versions described above into `hooks/`:

```sh
./scaffold-scripts.sh                       # write any hooks that don't exist yet
./scaffold-scripts.sh --override            # overwrite all hooks with the basic versions
./scaffold-scripts.sh --hook=pre-commit     # only scaffold one hook (repeatable)
./scaffold-scripts.sh --override --hook=pre-commit
./scaffold-scripts.sh --help                # usage and valid hook names
```

Without `--override`, existing hook files are left untouched and reported as skipped. Created files are made executable. Run this before `docker compose up --build` on a fresh checkout, otherwise the image ships with no hooks.

## Starting the server

```sh
docker compose up -d --build
```

This builds the image, starts the container, and exposes the SVN server on `localhost:15705`. Repo data persists in the `svn-data` named volume across restarts.

To stop:

```sh
docker compose down
```

To wipe the repo and start fresh:

```sh
docker compose down -v
```

## Using the repo

Checkout:

```sh
svn co svn://localhost:15705/repo
```

Trigger hooks by committing, locking, etc. as normal:

```sh
svn mkdir repo/trunk/foo -m "test"
svn commit
```

## Mirroring WordPress develop.svn

`mirror-wp-develop.sh` runs on your local machine (not in the container) and turns the repo into an `svnsync` mirror of `https://develop.svn.wordpress.org`. It requires a local `svn`/`svnsync` client (`brew install subversion` on macOS) and a running container (`docker compose up -d`).

It wipes whatever is currently in `/svn/repo`, so run it after the server is up but before you've committed anything you want to keep:

```sh
./mirror-wp-develop.sh
```

Full history is large and this can take a long time. It's safe to Ctrl-C and re-run later — svnsync tracks the last-synced revision and resumes where it left off.

The script temporarily replaces `pre-revprop-change` with an allow-all version (svnsync needs to set `svn:sync-*` / `svn:author` / `svn:date` revprops) and restores the real hook from `hooks/pre-revprop-change` once the sync finishes. Since the mirror comes with its own history/layout, the synthetic trunk/branches/tags skeleton from initial repo creation is discarded when this runs.

## Debugging inside the container

```sh
docker compose exec svn sh
```

From there:

- Hooks live at `/svn/repo/hooks/`
- `svnlook` at `/usr/bin/svnlook`, e.g. `svnlook log /svn/repo`
- `php` at `/usr/local/bin/php`
- Container logs (including anything hooks print to stderr) via `docker compose logs -f svn`

## Without docker compose

```sh
docker build -t svn-hook-test .
docker run -d --name svn-hook-test -p 15705:15705 svn-hook-test
```

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Aaron Jorbin.
