FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        subversion \
        apache2 \
        libapache2-mod-svn \
        php-cli \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# svnlook ships at /usr/bin/svnlook via the subversion package already;
# symlink defensively in case the package layout ever changes.
RUN [ -x /usr/bin/svnlook ] || ln -s "$(command -v svnlook)" /usr/bin/svnlook

# php-cli installs to /usr/bin/php; expose it at /usr/local/bin/php too.
RUN ln -sf "$(command -v php)" /usr/local/bin/php

ENV REPO_PATH=/svn/repo
ENV MIRROR_PATH=/svn/mirror

RUN mkdir -p /svn
COPY hooks/ /hooks/
COPY create-repo.sh /usr/local/bin/create-repo.sh
COPY refresh-working-repo.sh /usr/local/bin/refresh-working-repo.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/create-repo.sh /usr/local/bin/refresh-working-repo.sh /usr/local/bin/entrypoint.sh \
    && find /hooks -type f -exec chmod +x {} +

EXPOSE 15705

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
