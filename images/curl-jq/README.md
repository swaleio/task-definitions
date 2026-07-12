# curl-jq

A small Alpine-based image bundling **curl**, **jq**, and CA certificates, with an
entry point that performs a single HTTP request and reports its outcome the way
the Swale container contract expects. It is the swale-built image behind Swale's
**`http-request`** task and is not intended to be run standalone.

The entry point assembles the curl invocation from `INPUT_*` environment
variables (injected by the platform from task inputs), writes the response body
to a file on the shared `/mnt/workspace` volume, and appends the HTTP status and
body path to `$WORKFLOW_TASK_OUTPUT`. Arguments are built as a quoted argument
vector -- never via string concatenation or `eval` -- so header values, request
bodies, and URLs are always passed as opaque tokens.

`jq` is included so downstream tasks (or a wrapping script) can parse the JSON
response the request leaves in the workspace.

## Inputs it reads

| Environment variable | Required | Default | Purpose |
|----------------------|----------|---------|---------|
| `INPUT_URL` | yes | — | The request URL. |
| `INPUT_METHOD` | no | `GET` | HTTP method (`--request`). |
| `INPUT_HEADERS` | no | — | Newline-separated `Key: Value` lines; each non-empty line becomes a repeated `--header`. |
| `INPUT_BODY` | no | — | Inline request body (sent with `--data-raw`). |
| `INPUT_BODY_FILE` | no | — | Path to a body file (sent with `--data-binary @<path>`); takes precedence over `INPUT_BODY`. |
| `INPUT_RETRY` | no | `3` | Retry count passed to curl `--retry`. |
| `INPUT_RETRY_ON_CONNREFUSED` | no | `true` | When `true`, adds `--retry-connrefused`. |
| `INPUT_RESPONSE_PATH` | no | `/mnt/workspace/response.json` | Where the response body is written. |
| `INPUT_EXPECTED_STATUS` | no | — | If set and the actual status differs, the task exits non-zero. |

## Outputs it emits

Appended to `$WORKFLOW_TASK_OUTPUT` as `key=value` lines:

| Output | Description |
|--------|-------------|
| `status` | The HTTP status code returned by the request. |
| `body_file` | The workspace path of the written response body. |

## Behavior notes

- A transport-level failure (DNS, connection, TLS) exits non-zero and fails the
  task; retries are governed by `INPUT_RETRY` / `INPUT_RETRY_ON_CONNREFUSED`.
- An HTTP error status (4xx/5xx) is captured and emitted normally -- curl is not
  run with `--fail`. Use `INPUT_EXPECTED_STATUS` to turn an unexpected status
  into a task failure.
- Runs as a non-root user (uid 1000) with `WORKDIR /mnt/workspace`, per the Swale
  container contract.
