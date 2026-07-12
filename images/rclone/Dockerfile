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
