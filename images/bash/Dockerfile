FROM debian:13-slim@sha256:8aa5a7bf5a1955bddbe7d74fcdd0b91ab30e74362a8b73af672b0481b35b44a0

# Debian 13 slim as it is, plus the non-root `swale` user the container runs as.
# It exists so the bash task's version names the Bash it runs: the Debian tag
# names the distribution instead.
RUN useradd --create-home --uid 1000 swale

# No ENTRYPOINT: the bash task is a free-form script task, so its exec.args are
# the full command line (`bash -lc <script>`).

# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN bash -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"' > /usr/share/swale-image-version
USER swale
WORKDIR /mnt/workspace

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="Bash"
LABEL org.opencontainers.image.description="Bash on Debian 13 slim for Swale workflows. Backs the bash task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/bash/README.md"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"
