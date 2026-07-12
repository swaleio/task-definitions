#!/bin/sh
set -e

# Optional HTTPS token auth: derive the host from the repo URL and store a
# credential. INPUT_* env vars are injected by the platform from task inputs.
if [ -n "$INPUT_GIT_TOKEN" ]; then
  host=$(printf '%s' "$INPUT_REPOSITORY_URL" | sed -E 's#^https?://([^/]+)/.*#\1#')
  git config --global credential.helper store
  printf 'https://oauth2:%s@%s\n' "$INPUT_GIT_TOKEN" "$host" > "$HOME/.git-credentials"
fi
git config --global --add safe.directory '*'

# Run the requested git command (args come from the task definition's exec.args).
git "$@"

# Emit the declared `commit_sha` output after a clone, for downstream tasks.
if [ "$1" = "clone" ] && [ -n "$WORKFLOW_TASK_OUTPUT" ]; then
  dest="/mnt/workspace/${INPUT_DEST:-repo}"
  if [ -d "$dest/.git" ]; then
    printf 'commit_sha=%s\n' "$(git -C "$dest" rev-parse HEAD)" >> "$WORKFLOW_TASK_OUTPUT"
  fi
fi
