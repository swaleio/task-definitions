#!/usr/bin/env bash
set -e

# Start the Ollama server in the background. The image bakes
# OLLAMA_HOST=0.0.0.0:11434 so the API is reachable at the runner pod's
# address (${{tasks.<id>.ip-address}}:11434); the server reads it from the
# environment.
ollama serve &
server_pid=$!

# Forward termination to the server so the pod shuts down cleanly when the
# workflow tears the runner down via terminate_on.
trap 'kill -TERM "$server_pid" 2>/dev/null' TERM INT

# Wait until the API answers before pulling; `ollama list` only succeeds once
# the server is accepting requests.
ready=""
for _ in $(seq 1 120); do
  if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "ollama server exited before becoming ready" >&2
    exit 1
  fi
  if ollama list >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ -z "$ready" ]; then
  echo "timed out waiting for the ollama server to answer" >&2
  exit 1
fi

# Pull the requested model (INPUT_MODEL carries the required `model` input).
# Multi-gigabyte pulls take minutes; consumers poll readiness against the API
# (see the ollama-serve task docs for the pull-time caveat). Pulled layers land
# under the home directory and live exactly as long as the runner pod.
if [ -n "$INPUT_MODEL" ]; then
  ollama pull "$INPUT_MODEL"
fi

# Stay in the foreground for the runner's lifetime; the workflow terminates
# the pod once the tasks listed in terminate_on complete.
wait "$server_pid"
