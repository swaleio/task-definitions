---
name: vLLM batch inference
description: Runs offline batch inference with vLLM over an OpenAI-batch-format JSONL request file.
inputs:
  input_file:
    description: Absolute path inside the container of the OpenAI-batch-format JSONL request file. Point it at the mounted workspace (e.g. ${{env.WORKFLOW_STORAGE}}/batch/requests.jsonl) where an earlier task wrote it, or any other container-local path.
    required: true
  output_file:
    description: Absolute path inside the container. Point it at the mounted workspace (e.g. ${{env.WORKFLOW_STORAGE}}/batch/results.jsonl) to share the results with later tasks, or any other container-local path.
    required: true
  model:
    description: The model to load — a Hugging Face repo id (e.g. Qwen/Qwen2.5-7B-Instruct) or the full path of a local model directory such as one fetched by hf-download.
    required: true
  token:
    description: Hugging Face access token for gated or private models (pass a secret). Omit for public models and local model directories.
    default: ""
exec:
  # docker.io/swaleio/vllm-tools:1-0-0
  image: docker.io/swaleio/vllm-tools@sha256:2dc0808f422bf107d13af4b0e4d03150e13e08f30762a19aeb919fa1ad687afc
  env:
    HF_TOKEN: ${{inputs.token}}
  args:
    - vllm
    - run-batch
    - "-i"
    - ${{inputs.input_file}}
    - "-o"
    - ${{inputs.output_file}}
    - "--model"
    - ${{inputs.model}}
---

# vLLM batch inference

Runs `vllm run-batch`: offline, high-throughput inference without standing up a
server. `input_file` is a JSONL file in the OpenAI batch format — one request
per line:

```json
{"custom_id": "req-1", "method": "POST", "url": "/v1/chat/completions", "body": {"model": "${{env.WORKFLOW_STORAGE}}/qwen", "messages": [{"role": "user", "content": "Hello!"}]}}
```

Each request's `body.model` must match the `model` value the engine was started
with. Results are written to `output_file` as one JSONL line per request,
tagged with the same `custom_id` (output order is not guaranteed).

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `input_file` | yes | — | Absolute path of the OpenAI-batch-format JSONL request file — typically a workspace path (e.g. `${{env.WORKFLOW_STORAGE}}/batch/requests.jsonl`) an earlier task wrote. |
| `output_file` | yes | — | Absolute path the results JSONL is written to. Point it at the mounted workspace (e.g. `${{env.WORKFLOW_STORAGE}}/batch/results.jsonl`) to share it with later tasks. |
| `model` | yes | — | Hugging Face repo id, or the full path of a local model directory. |
| `token` | no | — | HF access token for gated/private models (pass a secret). |

## Outputs

None. The results land at `output_file` — pass a workspace path so downstream
tasks can read them; the task emits no output keys.

## Compute

**GPU required.** The GPU's VRAM must fit the model: roughly 2 GB per billion
parameters for bf16 weights, plus headroom for the KV cache (vLLM preallocates
most of the remaining VRAM), so a 7–8B model wants a 24 GB+ GPU. This task's
fixed command line keeps vLLM's default engine settings (no tensor
parallelism), so size the compute type so that one GPU fits the model. The
workflow selects the compute type via `compute_type`; on a CPU compute type
the task fails at runtime with CUDA errors.

## Reusing downloaded weights

`model` accepts the full path of a local model directory. Point it at the
output of an `hf-download` task (e.g. `${{tasks.<id>.outputs.path}}`) to avoid
re-downloading multi-gigabyte weights from the Hub on every run — the engine
loads straight from the workspace.

## Gated and private models

When `model` is a gated or private Hub repo id, pass a Hugging Face access
token via `token` (as a secret) — the definition's `exec.env` delivers it to
the engine as `HF_TOKEN` (an omitted token resolves to an empty value, which
the Hugging Face stack treats as no token).

## Example

```yaml
name: vLLM batch inference example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      weights:
        name: Fetch weights
        uses: swaleio/hf-download@1.0.0
        args:
          repo: Qwen/Qwen2.5-7B-Instruct
          include: "*.safetensors,*.json,tokenizer.*"
          dest: ${{env.WORKFLOW_STORAGE}}/qwen
      requests:
        name: Write batch requests
        uses: swaleio/bash@1.0.0
        args:
          script: |
            set -euo pipefail
            mkdir -p ${{env.WORKFLOW_STORAGE}}/batch
            cat > ${{env.WORKFLOW_STORAGE}}/batch/requests.jsonl <<'EOF'
            {"custom_id":"req-1","method":"POST","url":"/v1/chat/completions","body":{"model":"${{env.WORKFLOW_STORAGE}}/qwen","messages":[{"role":"user","content":"Summarize what vLLM does in one sentence."}]}}
            {"custom_id":"req-2","method":"POST","url":"/v1/chat/completions","body":{"model":"${{env.WORKFLOW_STORAGE}}/qwen","messages":[{"role":"user","content":"Name three uses of batch inference."}]}}
            EOF
      batch:
        name: Batch inference
        uses: swaleio/vllm-batch@1.0.0
        start_on:
          - weights
          - requests
        compute_type: gpu   # any GPU compute type whose VRAM fits the model
        args:
          model: ${{tasks.weights.outputs.path}}
          input_file: ${{env.WORKFLOW_STORAGE}}/batch/requests.jsonl
          output_file: ${{env.WORKFLOW_STORAGE}}/batch/results.jsonl
```

Each request's `body.model` matches the engine's `model` value — here the local
directory the `weights` task downloaded to, so nothing is re-fetched from the
Hub. Later tasks read the results at `${{env.WORKFLOW_STORAGE}}/batch/results.jsonl`.

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
