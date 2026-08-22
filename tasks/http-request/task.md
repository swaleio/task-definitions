---
name: HTTP request
description: Makes an HTTP request with curl, writing the response body to a file and emitting the status.
inputs:
  url:
    description: The request URL. The public internet is reachable; RFC 1918 and cloud metadata endpoints are blocked.
    required: true
  method:
    description: HTTP method (GET, POST, PUT, PATCH, DELETE, HEAD, ...).
    default: GET
  headers:
    description: 'Request headers as newline-separated "Key: Value" lines. The wrapper splits on newlines and passes each as a header; blank lines are ignored.'
    default: ""
  body:
    description: Request body sent verbatim. Ignored when body_file is set.
    default: ""
  body_file:
    description: Workspace path whose file contents are sent as the request body. Takes precedence over body.
    default: ""
  retry:
    description: Number of times curl retries transient failures (transient HTTP 5xx and connection errors), with backoff.
    default: "3"
  retry_on_connrefused:
    description: When true, also retry on connection-refused — use it to poll a runner that is reachable but not yet accepting connections.
    default: "true"
  expected_status:
    description: If set, the task fails unless the final response status code equals this value. Empty means accept any status.
    default: ""
  response_path:
    description: Path where the response body is written. A bare relative path lands in the container's working directory; pass an absolute workspace path (e.g. ${{env.WORKFLOW_STORAGE}}/response.json) to share the body with downstream tasks. Use a distinct path per task since the workspace is shared.
    default: response.json
outputs:
  status:
    description: The HTTP status code of the final response.
  body_file:
    description: Path of the written response body (equals response_path).
exec:
  # docker.io/swaleio/curl-jq:1-0-0
  image: docker.io/swaleio/curl-jq@sha256:16049754d520fe45f3b67b93cfca36398661bbc2b5911b0cdd7bfb9d5eb91d3f
  args: []
---

# HTTP request

Makes an HTTP request and captures the result for downstream tasks: the response
body is written to a workspace file and the status code is emitted as an output.
The image's entrypoint is the request wrapper, so there are no `args` — **every
setting is supplied through inputs** (each is also injected as an `INPUT_*`
environment variable the wrapper reads).

Use it to call APIs, submit jobs, download small JSON/text payloads into the
workspace, and to poll a not-yet-ready runner until it starts answering.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `url` | yes | — | The request URL (public internet only; private ranges are blocked). |
| `method` | no | `GET` | HTTP method. |
| `headers` | no | — | Newline-separated `Key: Value` header lines; the wrapper splits them. |
| `body` | no | — | Request body sent verbatim. Ignored when `body_file` is set. |
| `body_file` | no | — | Workspace path whose contents are sent as the body; wins over `body`. |
| `retry` | no | `3` | Retries for transient 5xx and connection errors, with backoff. |
| `retry_on_connrefused` | no | `true` | Also retry connection-refused — for polling a runner that isn't up yet. |
| `expected_status` | no | any | If set, the task fails unless the response code matches this value. |
| `response_path` | no | `response.json` | Where the response body is written; a relative path lands in the working directory — pass an absolute workspace path to share it downstream. |

## Outputs

| Output | Description |
|--------|-------------|
| `status` | The HTTP status code of the final response. |
| `body_file` | Path of the written response body (equals `response_path`). |

## Compute

**CPU.** HTTP I/O only — no GPU is needed, and scheduling it on a GPU compute type wastes money.

## Example

```yaml
name: HTTP request example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      submit:
        name: Submit job
        uses: swaleio/http-request@1-0-0
        args:
          url: https://api.example.com/v1/jobs
          method: POST
          headers: |
            Authorization: Bearer ${{secrets.api_token}}
            Content-Type: application/json
          body: '{"name":"nightly","priority":"high"}'
          expected_status: "201"
          response_path: ${{env.WORKFLOW_STORAGE}}/job.json
```

The response body is available to later tasks at
`${{tasks.submit.outputs.body_file}}` (here `${{env.WORKFLOW_STORAGE}}/job.json`), and the
status code as `${{tasks.submit.outputs.status}}`.

## Polling a runner

To wait for a long-running runner task to become ready, point `url` at its
health endpoint and keep `retry` and `retry_on_connrefused` at their defaults —
curl retries connection-refused until the server accepts connections, so the
task succeeds once the runner is up. List the runner in the polling task's
`start_on`, and read the runner address as `${{tasks.<runner-id>.ip-address}}`.

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
