# Base: rclone/rclone:1 (pin the digest; tag kept for humans)
FROM rclone/rclone@sha256:c61954aaa32328a5486715dd063a81c7879f5195ad3505cd362deddd509dc4a1

# The base image's ENTRYPOINT is the `rclone` binary itself. Override it with a
# thin wrapper that maps task inputs to rclone's remote-config env vars before
# running `rclone copy`. The base is Alpine-based, so /bin/sh is available, and
# it already ships a non-root `rclone` user (UID 1009) plus ca-certificates.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER rclone
WORKDIR /mnt/workspace
ENTRYPOINT ["/entrypoint.sh"]

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="rclone"
LABEL org.opencontainers.image.description="rclone with credential mapping for Swale workflows. Backs the rclone-copy task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/rclone/README.md"
LABEL org.opencontainers.image.licenses="MIT"
