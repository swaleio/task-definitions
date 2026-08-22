# Base: alpine/git:latest (digest-pinned; tag kept for humans)
FROM alpine/git@sha256:697cb1c85aefc5724febaec2202a974e0d66f6abb6be91a9a86d0c8757af692a

RUN apk add --no-cache git-lfs openssh-client ca-certificates \
 && git lfs install --system \
 && adduser -D -u 1000 swale

COPY entrypoint.sh /opt/git/entrypoint.sh
RUN chmod +x /opt/git/entrypoint.sh

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
LABEL org.opencontainers.image.licenses="MIT"
