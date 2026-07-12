#!/bin/sh
# Entry point for the swale-built `curl-jq` image backing the http-request task.
# It assembles a single curl invocation from the task's INPUT_* environment
# variables, writes the response body to a workspace file, and emits the HTTP
# status and body path as declared task outputs. jq is bundled in the image for
# downstream JSON post-processing.
set -e

url="$INPUT_URL"
method="${INPUT_METHOD:-GET}"
retry="${INPUT_RETRY:-3}"
retry_connrefused="${INPUT_RETRY_ON_CONNREFUSED:-true}"
response_path="${INPUT_RESPONSE_PATH:-/mnt/workspace/response.json}"

if [ -z "$url" ]; then
  echo "http-request: INPUT_URL is required" >&2
  exit 1
fi

mkdir -p "$(dirname "$response_path")"

# Build curl's argv in the positional parameters ($@) so every value stays a
# single, fully-quoted token. This is the POSIX-shell equivalent of an argument
# array -- there is no string concatenation and no eval, so header values, bodies
# and URLs cannot break out of their token or inject extra flags.
set -- curl --silent --show-error \
  --request "$method" \
  --retry "$retry" \
  --output "$response_path" \
  --write-out '%{http_code}'

if [ "$retry_connrefused" = "true" ]; then
  set -- "$@" --retry-connrefused
fi

# INPUT_HEADERS is newline-separated "Key: Value" lines -> one repeated --header
# per non-empty line. Reading from a file redirect (not a pipe) keeps the loop in
# this shell, so the appends to $@ survive. `read -r` treats backslashes literally.
if [ -n "$INPUT_HEADERS" ]; then
  headers_file="$(mktemp)"
  printf '%s\n' "$INPUT_HEADERS" > "$headers_file"
  while IFS= read -r header; do
    [ -n "$header" ] || continue
    set -- "$@" --header "$header"
  done < "$headers_file"
  rm -f "$headers_file"
fi

# Request body: a file (--data-binary @path) takes precedence over an inline
# value. --data-raw keeps a literal body from being interpreted as an @file
# reference by curl.
if [ -n "$INPUT_BODY_FILE" ]; then
  set -- "$@" --data-binary "@$INPUT_BODY_FILE"
elif [ -n "$INPUT_BODY" ]; then
  set -- "$@" --data-raw "$INPUT_BODY"
fi

set -- "$@" "$url"

# curl writes the response body to $response_path (via --output) and prints only
# the HTTP status code (via --write-out). A transport-level failure exits non-zero
# here and, under `set -e`, fails the task; an HTTP error status is captured
# normally since --fail is intentionally not used.
status="$("$@")"

if [ -n "$WORKFLOW_TASK_OUTPUT" ]; then
  printf 'status=%s\n' "$status" >> "$WORKFLOW_TASK_OUTPUT"
  printf 'body_file=%s\n' "$response_path" >> "$WORKFLOW_TASK_OUTPUT"
fi

if [ -n "$INPUT_EXPECTED_STATUS" ] && [ "$INPUT_EXPECTED_STATUS" != "$status" ]; then
  printf 'http-request: expected HTTP %s but got %s\n' "$INPUT_EXPECTED_STATUS" "$status" >&2
  exit 1
fi
