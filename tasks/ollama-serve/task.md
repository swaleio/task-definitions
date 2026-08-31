---
name: Ollama serve
description: Runs an Ollama server as a long-lived runner, pulling the requested model and serving its API.
inputs:
  model:
    description: The model to pull before the server is considered ready, e.g. llama3.2:3b. Any model the configured Ollama registry serves.
    required: true
  models_path:
    description: Directory holding the Ollama model store. Point it at the workspace to share one store across tasks; defaults to the per-task home directory, which is discarded with the runner.
    default: ""
exec:
  # docker.io/swaleio/ollama:1-0-0
  image: docker.io/swaleio/ollama@sha256:0507a51f591416d1504088b99f2450440634d4ca5ec2739195f98b5d7bf75807
  args: []
---

# Ollama serve

Starts an [Ollama](https://ollama.com) server as a **long-lived runner**, pulls
`model`, and serves the Ollama API on port `11434` to the other tasks in the
run until the workflow terminates it. Both Ollama's native API
(`/api/generate`, `/api/chat`, `/api/tags`, …) and its OpenAI-compatible
endpoints (`/v1/chat/completions`, …) are available. The image's wrapper
entrypoint reads the inputs from the environment, so `args` is empty.

By default the model store lives in the per-task home directory and dies with the
runner, so every run pulls `model` again. Point `models_path` at a workspace path
to share one store: an earlier task in the run — another `ollama-serve`, or
anything that writes Ollama's store layout — populates it, and this runner finds
the model already present and starts serving without the pull. Concurrent tasks
writing the same store path must not overlap.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `model` | yes | — | The model to pull before the server is considered ready, e.g. `llama3.2:3b`. |
| `models_path` | no | per-task home | Where the Ollama model store lives. Point it at a workspace path (e.g. `${{env.WORKFLOW_STORAGE}}/ollama`) to reuse a store an earlier task populated instead of re-pulling. |

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
- The pulled model lives in the runner pod's own home directory and is discarded
  with it, unless `models_path` puts the store on the shared workspace — in which
  case it outlives the runner and is available to the rest of the run.

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
name: Ollama serve example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      llm:
        name: Ollama server
        uses: swaleio/ollama-serve@1.0.0
        # Pick a GPU compute type available to your project.
        compute_type: gpu
        terminate_on:
          - generate
        args:
          model: llama3.2:3b

      ready:
        name: Wait for Ollama
        uses: swaleio/http-request@1.0.0
        start_on:
          - llm
        args:
          url: http://${{tasks.llm.ip-address}}:11434/api/tags
          expected_status: "200"
          retry: "30"
          response_path: ${{env.WORKFLOW_STORAGE}}/ollama-tags.json

      generate:
        name: Generate
        uses: swaleio/http-request@1.0.0
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
          response_path: ${{env.WORKFLOW_STORAGE}}/ollama-answer.json
```

The runner is terminated once `generate` completes. The generated answer is
available to later tasks at `${{env.WORKFLOW_STORAGE}}/ollama-answer.json` (also exposed
as `${{tasks.generate.outputs.body_file}}`).

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
