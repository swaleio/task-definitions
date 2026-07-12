---
name: LM evaluation harness
description: Evaluates a model on lm-evaluation-harness benchmarks (mmlu, gsm8k, ...) using the vLLM backend, writing the results JSON under a caller-chosen path.
inputs:
  model_dir:
    description: The model to evaluate — the full path of a local model directory such as one fetched by hf-download, or a Hugging Face repo id.
    required: true
  tasks:
    description: Comma-separated lm-eval task names to run, e.g. "mmlu,gsm8k". The list is passed as a single value, so commas are safe.
    required: true
  output_path:
    description: Absolute path inside the container under which lm-eval writes its results JSON. Point it at the mounted workspace (e.g. /mnt/workspace/eval) to share the results with later tasks, or any other container-local path.
    required: true
  token:
    description: Hugging Face access token for gated or private models (pass a secret). Omit for public models and local model directories.
    default: ""
exec:
  # docker.io/swaleio/vllm-tools:1-0-0
  image: docker.io/swaleio/vllm-tools@sha256:0000000000000000000000000000000000000000000000000000000000000000
  args:
    - lm_eval
    - "--model"
    - vllm
    - "--model_args"
    - pretrained=${{inputs.model_dir}}
    - "--tasks"
    - ${{inputs.tasks}}
    - "--batch_size"
    - auto
    - "--output_path"
    - ${{inputs.output_path}}
---

# LM evaluation harness

Runs the EleutherAI
[lm-evaluation-harness](https://github.com/EleutherAI/lm-evaluation-harness)
(`lm_eval`) against a model, using the bundled **vLLM** engine as the inference
backend with `--batch_size auto`. Evaluate a checkpoint fine-tuned earlier in
the run, or a base model straight off the Hub, on standard benchmarks such as
`mmlu`, `gsm8k`, `hellaswag`, `arc_challenge`, or `winogrande`. Benchmark
datasets are downloaded from the Hub at run time.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `model_dir` | yes | — | Full path of a local model directory (e.g. from `hf-download`), or a Hugging Face repo id. |
| `tasks` | yes | — | Comma-separated lm-eval task names, e.g. `mmlu,gsm8k` — passed as one value, no word-splitting. |
| `output_path` | yes | — | Absolute path the results are written under. Point it at the mounted workspace (e.g. `/mnt/workspace/eval`) to share them with later tasks. |
| `token` | no | — | HF access token for gated/private models (pass a secret). |

## Outputs

None declared. `lm_eval` writes its results under `output_path`: current
harness versions create a per-model subdirectory there containing
`results_<timestamp>.json`. Pass a workspace path so a later task can parse,
compare, or publish the results.

## Compute

This task requires a **GPU compute type**, selected by the workflow via
`compute_type` — the definition does not choose hardware. The model is loaded
through vLLM, so the GPU's VRAM must fit it: roughly 2 GB per billion
parameters for bf16 weights plus KV-cache headroom, so a 7–8B model wants a
24 GB+ GPU. Models larger than a single GPU are normally sharded with tensor
parallelism across a multi-GPU compute type; this task's fixed command line
keeps vLLM's default engine settings, so size the compute type so that one GPU
fits the model. Scheduling this task on a CPU compute type fails at runtime
with CUDA errors.

## Reusing downloaded weights

`model_dir` accepts the full path of a local model directory. Point it at the
output of an `hf-download` task (e.g. `${{tasks.<id>.outputs.path}}`) to avoid
re-downloading multi-gigabyte weights from the Hub on every run.

## Gated and private models

When `model_dir` is a gated or private Hub repo id, pass a Hugging Face access
token via `token` (as a secret). The image entrypoint exports it as `HF_TOKEN`
before the harness starts.

## Example

```yaml
tasks:
  weights:
    name: Fetch weights
    uses: swaleio/hf-download@1-0-0
    args:
      repo: Qwen/Qwen2.5-7B-Instruct
      include: "*.safetensors,*.json,tokenizer.*"
      dest: /mnt/workspace/qwen
  eval:
    name: Evaluate
    uses: swaleio/lm-eval@1-0-0
    start_on:
      - weights
    compute_type: a100-80gb   # any GPU compute type whose VRAM fits the model
    args:
      model_dir: ${{tasks.weights.outputs.path}}
      tasks: "mmlu,gsm8k"
      output_path: /mnt/workspace/eval
```

The harness evaluates the downloaded checkpoint without re-fetching it and
writes the results JSON under `/mnt/workspace/eval`, where a later task can
read it — for example to gate a deployment on a minimum benchmark score.
