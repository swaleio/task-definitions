#!/bin/sh
set -e

# Authenticate against the Hugging Face Hub when a token is supplied (pass a
# secret). vllm and lm_eval both read HF_TOKEN when fetching gated or private
# repos.
if [ -n "$INPUT_TOKEN" ]; then
  export HF_TOKEN="$INPUT_TOKEN"
fi

# The Hub cache stays at the image default (under the user's home) unless the
# caller relocates it. Set INPUT_HF_HOME to, for example, a path on the mounted
# workspace to persist downloaded blobs across tasks in a run.
if [ -n "$INPUT_HF_HOME" ]; then
  export HF_HOME="$INPUT_HF_HOME"
fi

# The base image's API-server ENTRYPOINT is reset in the Dockerfile, so the
# task definition's exec.args arrive here as the full command line. Run it
# as-is.
exec "$@"
