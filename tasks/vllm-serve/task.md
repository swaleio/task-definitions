---
name: vLLM serve
description: Serves a model through vLLM's OpenAI-compatible API server as a long-lived runner task.
inputs:
  model:
    description: Model to serve — a Hugging Face Hub repo id (e.g. meta-llama/Llama-3.1-8B-Instruct) or a full local directory path inside the container (e.g. a directory produced by swaleio/hf-download). A repo id is downloaded from the Hub at startup; a local path skips the download.
    required: true
  port:
    description: TCP port the API server listens on. Defaults to 8000; pass a different value to serve elsewhere, and point every consumer URL at the same port.
    default: "8000"
  token:
    description: Hugging Face access token for gated or private Hub models (pass a secret). Omit for public models or local model directories.
    default: ""
exec:
  # docker.io/vllm/vllm-openai:v0.25.0-cu129-ubuntu2404
  image: docker.io/vllm/vllm-openai@sha256:45fb56697a60265776fde7aed64f09b1368987d1d1cfdd1f6692a493548fa5ee
  env:
    HF_TOKEN: ${{inputs.token}}
  args:
    - "--model"
    - ${{inputs.model}}
    - "--port"
    - ${{inputs.port}}
---

# vLLM serve

Starts vLLM's OpenAI-compatible API server (`/v1/chat/completions`,
`/v1/completions`, `/v1/models`) on the vendor `vllm/vllm-openai` image, used
as-is: the image's entrypoint **is** the server, so `exec.args` are server
flags only. `model` accepts either a Hugging Face repo id (downloaded from the
Hub when the server starts) or a full local directory path — point it at a
directory fetched by `swaleio/hf-download` to skip the Hub download entirely.

This is a **runner** task: it serves requests indefinitely and never exits on
its own. Its lifetime is bounded by its own `terminate_on` list — the platform
terminates the runner when the tasks listed there complete. A workflow that
starts this task without wiring `terminate_on` never finishes.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `model` | yes | — | Hub repo id (e.g. `meta-llama/Llama-3.1-8B-Instruct`) or a full local model directory path (e.g. `/mnt/workspace/llama` from `swaleio/hf-download`). A local path skips the Hub download. |
| `port` | no | `8000` | Port the server listens on. Consumers combine it with the runner's ip-address, so every consumer URL must use the same port. |
| `token` | no | — | HF access token for gated/private Hub models (pass a secret); delivered to the server as `HF_TOKEN` via the definition's `exec.env`. Unneeded for public models or local directories. |

## Outputs

None. Runner tasks are long-lived pods terminated via `terminate_on` and get no
output-tracking sidecar, so this task declares no outputs. Consumers read the
server's responses over HTTP instead.

## Compute

**GPU required.** Rough VRAM guidance for bf16/fp16 weights plus KV cache:
7–8B models want a 24 GB-class GPU, 13B-class models want 40 GB, and 70B-class
models want 80 GB-class hardware (or multiple GPUs). The workflow selects the
compute type via `compute_type`; on a CPU compute type the task does not fail
at submission — it fails at runtime with CUDA errors when vLLM finds no GPU.

## Runner lifecycle and consumers

- **Termination**: the runner's own `terminate_on` lists its consumers. When
  every task in that list completes, the platform terminates the runner. List
  the last task(s) that talk to the server.
- **Address**: consumers reach the server at `${{tasks.<id>.ip-address}}` on
  the server's port — `8000` unless the step passed `port`. Every consumer URL
  must use that same port.
- **Ordering**: every consumer MUST list the runner in its own `start_on` —
  the address only exists once the runner task has started.
- **Readiness**: the address is available at pod start, which is *before* the
  server is ready — vLLM still has to download/load weights and warm up, which
  can take minutes for large models. Consumers must poll readiness first:
  `GET /health` returns `200` once the server is ready. `swaleio/http-request`
  does this out of the box — its `retry_on_connrefused` input defaults to
  `true`, so it retries until the server accepts connections.

## Gated models

Pass a Hub access token through the `token` input — the definition's `exec.env`
delivers it to the server as `HF_TOKEN` (an omitted token resolves to an empty
value, which the Hugging Face stack treats as no token). Alternatively, fetch
the gated model with `swaleio/hf-download` and pass the local directory as
`model` — then the server never touches the Hub at all.

## Example

Download weights, serve them, wait for readiness, run one OpenAI-compatible
chat completion, and let the completion's finish terminate the server. The
`serve` step leaves `port` unset, so the server listens on the default `8000` —
the port every consumer URL below targets. Note that when `model` is a local
directory, the served model name defaults to that path — the consumer's request
body uses it as the `model` field.

```yaml
name: vLLM serve example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      weights:
        name: Fetch weights
        uses: swaleio/hf-download@1-0-0
        args:
          repo: meta-llama/Llama-3.1-8B-Instruct
          include: "*.safetensors,*.json,tokenizer.*"
          dest: /mnt/workspace/llama
          token: ${{secrets.hf_token}}

      serve:
        name: Serve model
        uses: swaleio/vllm-serve@1-0-0
        compute_type: gpu   # illustrative — pick a GPU compute type available to your project
        start_on: [weights]
        terminate_on: [generate]   # the runner is terminated when its consumers complete
        args:
          model: ${{tasks.weights.outputs.path}}

      wait_ready:
        name: Wait for server
        uses: swaleio/http-request@1-0-0
        start_on: [serve]
        args:
          url: http://${{tasks.serve.ip-address}}:8000/health
          expected_status: "200"

      generate:
        name: Chat completion
        uses: swaleio/http-request@1-0-0
        start_on: [wait_ready]
        args:
          url: http://${{tasks.serve.ip-address}}:8000/v1/chat/completions
          method: POST
          headers: |
            Content-Type: application/json
          body: '{"model":"/mnt/workspace/llama","messages":[{"role":"user","content":"Say hello."}]}'
          expected_status: "200"
          response_path: /mnt/workspace/completion.json
```

The `serve` runner's `terminate_on: [generate]` ends the server — and with it
the workflow — once `generate` completes.

Later tasks read the completion at `/mnt/workspace/completion.json` (or via
`${{tasks.generate.outputs.body_file}}`).

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
