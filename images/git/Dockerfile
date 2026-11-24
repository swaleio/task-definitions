FROM alpine/git:2.54.0@sha256:6a1fdb962814ca11508ca8d1bab94375b5b7ac4e4a9a40981c29fc32c02f095d

RUN apk add --no-cache git-lfs openssh-client ca-certificates \
 && git lfs install --system \
 && adduser -D -u 1000 swale

COPY entrypoint.sh /opt/git/entrypoint.sh
RUN chmod +x /opt/git/entrypoint.sh

# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN git --version | cut -d' ' -f3 > /usr/share/swale-image-version
USER swale
WORKDIR /mnt/workspace
ENTRYPOINT ["/opt/git/entrypoint.sh"]

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="Git"
LABEL org.opencontainers.image.description="Git with LFS and non-interactive token auth for Swale workflows. Backs the git-clone task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/git/README.md"
LABEL org.opencontainers.image.licenses="GPL-2.0-only"
