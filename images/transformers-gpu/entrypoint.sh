#!/bin/sh
set -e

# Authenticate against the Hugging Face Hub when a token is supplied (pass a
# secret). Fixed tasks on this image declare an optional `token` input, which
# the platform injects as INPUT_TOKEN; it is never interpolated into argv.
if [ -n "$INPUT_TOKEN" ]; then
  export HF_TOKEN="$INPUT_TOKEN"
fi

# The Hub cache stays at the image default (under the user's home) unless the
# caller relocates it. Set INPUT_HF_HOME to, for example, a path on the mounted
# workspace to persist downloaded models across tasks in a run.
if [ -n "$INPUT_HF_HOME" ]; then
  export HF_HOME="$INPUT_HF_HOME"
fi

# The task definition's exec.args are the full command line (for example
# `trl sft --config <path>` or `bash -lc <script>`); run it as-is.
exec "$@"
