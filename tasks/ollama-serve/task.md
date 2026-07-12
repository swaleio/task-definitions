---
name: Ollama serve
description: Runs an Ollama server as a long-lived runner — pulls the requested model and serves the Ollama API on port 11434 to other tasks in the run until the workflow terminates it.
inputs:
  model:
    description: The model to pull before the server is considered ready, e.g. llama3.2:3b. Any model the configured Ollama registry serves.
    required: true
exec:
  # docker.io/swaleio/ollama:1-0-0
  image: docker.io/swaleio/ollama@sha256:0000000000000000000000000000000000000000000000000000000000000000
  args: []
---

# Ollama serve

Starts an [Ollama](https://ollama.com) server as a **long-lived runner**, pulls
`model`, and serves the Ollama API on port `11434` to the other tasks in the
run until the workflow terminates it. Both Ollama's native API
(`/api/generate`, `/api/chat`, `/api/tags`, …) and its OpenAI-compatible
endpoints (`/v1/chat/completions`, …) are available. The image's wrapper
entrypoint reads the `model` input (`INPUT_MODEL`), so `args` is empty.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `model` | yes | — | The model to pull before the server is considered ready, e.g. `llama3.2:3b`. |

This task declares **no outputs**: runner tasks are long-lived pods without an
output-tracking sidecar, so results flow over HTTP rather than through
`$WORKFLOW_TASK_OUTPUT`.

## Compute

**GPU recommended.** Ollama falls back to CPU inference when no GPU is
present, so the task will not crash on a CPU-only compute type, but generation
is orders of magnitude slower and only tolerable for the smallest models — a
GPU compute type makes it usable. Rough VRAM guidance for Ollama's default
4-bit quantizations: ~3 GB for a 3B model, ~6–8 GB for a 7–8B model, 40 GB+ for
70B-class models; a model that does not fit in VRAM spills to CPU and slows
down. The workflow selects the compute type via `compute_type`, not this
definition.

## Runner semantics

- The runner stays up until the workflow terminates it: list its consumer
  task(s) in the runner's `terminate_on` — once they complete, the platform
  tears the runner down.
- Consumers reach the server at `${{tasks.<id>.ip-address}}:11434` and **must
  list the runner in their own `start_on`**.
- The address exists as soon as the pod starts — **before** the server inside
  answers — so consumers must poll for readiness (next section).
- The pulled model lives on container-local disk inside the runner pod; nothing
  persists after termination.

## Readiness

Poll the API with `swaleio/http-request` — `retry_on_connrefused` defaults to
`true`, so a `GET` against `/api/tags` with `expected_status: "200"` retries
until the port opens and succeeds once the server answers (see the example
below).

**Pull-time caveat.** The wrapper starts the server, waits for the API to
answer, and only then pulls `model` — so `/api/tags` can return `200` while a
multi-gigabyte pull is still in flight. A `200` proves the server is up; the
model appears in the `/api/tags` response body only once its pull completes,
and a generate request for a model that has not finished pulling fails with
`404` (which the probe's retries do not cover). For small models the window is
seconds and the `/api/tags` probe is enough. For large models, gate strictly by
probing the pull itself: `POST /api/pull` with body
`'{"model":"<model>","stream":false}'` and `expected_status: "200"` returns
only once the model is fully present (the server coalesces concurrent pulls of
the same model, so this waits on the wrapper's in-flight download rather than
redownloading).

## Example

```yaml
tasks:
  llm:
    name: Ollama server
    uses: swaleio/ollama-serve@1-0-0
    # Pick a GPU compute type available to your project.
    compute_type: gpu-a100
    terminate_on:
      - generate
    args:
      model: llama3.2:3b

  ready:
    name: Wait for Ollama
    uses: swaleio/http-request@1-0-0
    start_on:
      - llm
    args:
      url: http://${{tasks.llm.ip-address}}:11434/api/tags
      expected_status: "200"
      retry: "30"
      response_path: /mnt/workspace/ollama-tags.json

  generate:
    name: Generate
    uses: swaleio/http-request@1-0-0
    start_on:
      - llm
      - ready
    args:
      url: http://${{tasks.llm.ip-address}}:11434/api/generate
      method: POST
      headers: |
        Content-Type: application/json
      body: '{"model":"llama3.2:3b","prompt":"Why is the sky blue? Answer in one sentence.","stream":false}'
      expected_status: "200"
      response_path: /mnt/workspace/ollama-answer.json
```

The runner is terminated once `generate` completes. The generated answer is
available to later tasks at `/mnt/workspace/ollama-answer.json` (also exposed
as `${{tasks.generate.outputs.body_file}}`).
