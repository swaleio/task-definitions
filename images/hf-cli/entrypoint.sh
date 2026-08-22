#!/bin/sh
set -e

# The command (download / upload) and its base arguments come from the task
# definition's exec.args. The optional flags below are appended from task
# inputs (INPUT_* env vars injected by the platform).
cmd="$1"

# The Hub cache defaults to the home directory, which is per-task and discarded
# with it. A caller that wants blobs reused by later tasks in the run points
# cache_dir at the shared workspace instead. Set only when non-empty: an empty
# HF_HOME breaks path resolution.
if [ -n "$INPUT_CACHE_DIR" ]; then
  export HF_HOME="$INPUT_CACHE_DIR"
fi

# For downloads, restrict to matching files. INPUT_INCLUDE is a comma-separated
# list of glob patterns, each appended as its own --include flag. Disable
# pathname expansion (set -f) so a pattern like *.safetensors is passed through
# literally rather than expanded against the workspace.
if [ "$cmd" = "download" ] && [ -n "$INPUT_INCLUDE" ]; then
  set -f
  oldifs=$IFS
  IFS=,
  for glob in $INPUT_INCLUDE; do
    set -- "$@" --include "$glob"
  done
  IFS=$oldifs
  set +f
fi

# Pin a specific branch, tag, or commit when requested.
if [ -n "$INPUT_REVISION" ]; then
  set -- "$@" --revision "$INPUT_REVISION"
fi

# For uploads, an optional destination path inside the repository is a trailing
# positional argument (hf upload <repo> <local_path> [path_in_repo]).
if [ "$cmd" = "upload" ] && [ -n "$INPUT_PATH_IN_REPO" ]; then
  set -- "$@" "$INPUT_PATH_IN_REPO"
fi

# Run the Hugging Face CLI. With `set -e`, a non-zero exit stops the script
# before the output below is emitted.
hf "$@"

# After a successful download, publish the destination path so downstream tasks
# can read the fetched files. INPUT_DEST is the full local path the caller chose
# via the `dest` input (a required input), so emit it verbatim.
if [ "$cmd" = "download" ] && [ -n "$WORKFLOW_TASK_OUTPUT" ]; then
  printf 'path=%s\n' "$INPUT_DEST" >> "$WORKFLOW_TASK_OUTPUT"
fi
