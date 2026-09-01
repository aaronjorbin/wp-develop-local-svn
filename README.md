# svn-hook-test

Docker image running a local SVN server for testing hook scripts.

## Quick start (Makefile)

The `Makefile` is the intended way to interact with this repo:

```sh
make start     # up + sync + refresh: container running with the working repo ready
make up        # build (if needed) and start the container
make sync      # svnsync the mirror repo with develop.svn.wordpress.org (resumable)
make refresh   # wipe the working repo, replace it with a clean copy of the mirror
make fresh     # sync then refresh, in one step
make down      # stop the container (repo data persists in the volume)
make clean     # stop the container and delete all repo data
make shell     # shell into the container
make logs      # follow container logs
make help      # list all targets
```

### Two repos

The container serves two repositories on `localhost:15705`:

- **`svn://localhost:15705/mirror`** — an `svnsync` mirror of
  `https://develop.svn.wordpress.org`. Only `make sync` writes to it. Don't
  check it out or commit to it directly.
- **`svn://localhost:15705/repo`** — the working repo. Check this out and test
  hooks against it. `make refresh` throws it away and rebuilds it from the
  mirror (`svnadmin hotcopy`, then the svnsync revprops are stripped, a fresh
  UUID is assigned, and the hooks from `hooks/` are reinstalled).

Typical loop: `make up` once, `make sync` (long the first time, incremental
after), then `make refresh` whenever you want the working repo to match the
mirror again. `make fresh` does the last two together.

## Overview

- Debian bookworm base with `subversion`, `apache2` + `libapache2-mod-svn`, and `php-cli`.
- `svnlook` is installed at `/usr/bin/svnlook` (part of the `subversion` package).
- `php` is symlinked to `/usr/local/bin/php`.
- On container start, `entrypoint.sh` runs `create-repo.sh`, which (only when they don't already exist — both persist across restarts via the `svn-data` volume):
  - Creates the working repo at `/svn/repo`, copies the hooks from `hooks/` into it, imports a standard `trunk/`, `branches/`, `tags/` layout as the initial commit, and sets `anon-access = write`.
  - Creates the mirror repo at `/svn/mirror` with `anon-access = write` and an allow-all `pre-revprop-change` hook (svnsync needs to write revprops).
- `svnserve` is then started in the foreground on port 15705, serving both repos (`-r /svn`).

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

Without `--override`, existing hook files are left untouched and reported as skipped. Created files are made executable. Run this before `make up` on a fresh checkout, otherwise the image ships with no hooks.

## Starting the server

```sh
make up
```

This builds the image, starts the container, and exposes the SVN server on `localhost:15705`. Repo data (both repos) persists in the `svn-data` named volume across restarts.

`make down` stops the container; `make clean` (`docker compose down -v`) also deletes all repo data.

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

`make sync` (which runs `mirror-wp-develop.sh` on your local machine, not in the container) keeps the **mirror** repo in sync with `https://develop.svn.wordpress.org` via `svnsync`. It needs a local `svn`/`svnsync` client (`brew install subversion` on macOS) and a running container (`make up`).

```sh
make sync                    # first run inits the svnsync link, then syncs
STEAL_LOCK=1 make sync       # after an unclean kill left a stale sync lock
```

Full history is large and the first sync can take a long time. It's safe to Ctrl-C and re-run — svnsync tracks the last-synced revision and resumes. `make sync` never touches the working repo.

To get the synced content into the working repo:

```sh
make refresh    # wipe /svn/repo, hotcopy /svn/mirror into it, strip svnsync
                # revprops, assign a fresh UUID, reinstall hooks from hooks/
make fresh      # make sync + make refresh
```

`make refresh` throws away anything you committed to the working repo, by design.

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
