#!/bin/sh
set -e

# This task configures a single rclone remote named "remote". rclone reads a
# backend's settings from RCLONE_CONFIG_<REMOTE>_<OPTION> environment variables,
# so every value below targets the "REMOTE" config section. INPUT_* variables
# are injected by the platform from the task's inputs.

# Backend type for the remote (s3, b2, azureblob, ...). Defaults to s3.
RCLONE_CONFIG_REMOTE_TYPE="${INPUT_REMOTE_TYPE:-s3}"
export RCLONE_CONFIG_REMOTE_TYPE

# Pass through recognized credential inputs, but only when the caller set them,
# so an unset input never overrides a backend's own default. No eval is used:
# each mapping is an explicit, fixed name pair, and every read is guarded with
# ${VAR:-} so an unset variable is simply empty rather than an error.
if [ -n "${INPUT_ACCESS_KEY_ID:-}" ]; then
  RCLONE_CONFIG_REMOTE_ACCESS_KEY_ID="$INPUT_ACCESS_KEY_ID"
  export RCLONE_CONFIG_REMOTE_ACCESS_KEY_ID
fi
if [ -n "${INPUT_SECRET_ACCESS_KEY:-}" ]; then
  RCLONE_CONFIG_REMOTE_SECRET_ACCESS_KEY="$INPUT_SECRET_ACCESS_KEY"
  export RCLONE_CONFIG_REMOTE_SECRET_ACCESS_KEY
fi
if [ -n "${INPUT_ACCOUNT:-}" ]; then
  RCLONE_CONFIG_REMOTE_ACCOUNT="$INPUT_ACCOUNT"
  export RCLONE_CONFIG_REMOTE_ACCOUNT
fi
if [ -n "${INPUT_KEY:-}" ]; then
  RCLONE_CONFIG_REMOTE_KEY="$INPUT_KEY"
  export RCLONE_CONFIG_REMOTE_KEY
fi
if [ -n "${INPUT_TOKEN:-}" ]; then
  RCLONE_CONFIG_REMOTE_TOKEN="$INPUT_TOKEN"
  export RCLONE_CONFIG_REMOTE_TOKEN
fi
if [ -n "${INPUT_ENDPOINT:-}" ]; then
  RCLONE_CONFIG_REMOTE_ENDPOINT="$INPUT_ENDPOINT"
  export RCLONE_CONFIG_REMOTE_ENDPOINT
fi

# Copy source -> dest. Both use rclone's "remote:path" form (e.g.
# "remote:my-bucket/data"); use a local path such as /mnt/workspace/out on one
# side to move data in or out of the shared workspace. INPUT_FLAGS is optional
# extra rclone flags and is intentionally left unquoted so multiple
# space-separated flags become separate arguments; ${VAR:-} keeps an unset
# value empty instead of erroring.
exec rclone copy "$INPUT_SOURCE" "$INPUT_DEST" ${INPUT_FLAGS:-}
