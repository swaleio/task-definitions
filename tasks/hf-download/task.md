---
name: Hugging Face download
description: Downloads a model, dataset, or space from the Hugging Face Hub into a caller-chosen directory.
inputs:
  repo:
    description: The Hugging Face repo id to download, e.g. meta-llama/Llama-3.1-8B-Instruct.
    required: true
  repo_type:
    description: Repository type — model, dataset, or space.
    default: model
  revision:
    description: Git revision (branch, tag, or commit) to download. Defaults to the repo's main revision.
    default: ""
  include:
    description: Comma-separated glob patterns to download (e.g. "*.safetensors,*.json"). Empty downloads everything.
    default: ""
  cache_dir:
    description: Directory for the Hub download cache. Point it at the workspace to reuse blobs across tasks in the run; defaults to the per-task home directory, which is discarded with the task.
    default: ""
  dest:
    description: Absolute path inside the container. Point it at the mounted workspace (e.g. /mnt/workspace/llama) to share the result with later tasks, or any other container-local path.
    required: true
  token:
    description: Hugging Face access token for gated or private repos (pass a secret). Omit for public repos.
    default: ""
outputs:
  path:
    description: The local directory the content was downloaded to, i.e. the value of the dest input.
exec:
  # docker.io/swaleio/hf-cli:1-0-0
  image: docker.io/swaleio/hf-cli@sha256:c4433260a36c46289265b5ccd3a06847986879cefd2c1052cbe8e43ccbe7b116
  env:
    HF_TOKEN: ${{inputs.token}}
  args:
    - download
    - "--repo-type"
    - ${{inputs.repo_type}}
    - ${{inputs.repo}}
    - "--local-dir"
    - ${{inputs.dest}}
---

# Hugging Face download

Downloads `repo` from the Hugging Face Hub into the directory given by `dest` and
emits that local `path` for downstream tasks. The definition's `exec.env` delivers
the `token` input as `HF_TOKEN` for gated or private repos (an omitted token
resolves to an empty value, which the Hugging Face stack treats as no token). The
wrapper appends `--revision` when `revision` is set and splits `include` on commas
into repeated `--include` glob filters — so a single string input drives multiple
download patterns without word-splitting in `args`.

The Hub cache defaults to the per-task home directory, so it is discarded when the
task ends. `hf` stages every file through that cache before materializing it into
`dest`, which means a large download needs room for both. Set `cache_dir` to a
workspace path when a run downloads repeatedly: the blobs survive the task, later
downloads of the same revision reuse them, and the staging copies stop competing
with the task's own scratch capacity.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `repo` | yes | — | Repo id to download, e.g. `meta-llama/Llama-3.1-8B-Instruct`. |
| `repo_type` | no | `model` | Repository type: `model`, `dataset`, or `space`. |
| `revision` | no | main revision | Branch, tag, or commit to download. |
| `include` | no | everything | Comma-separated glob patterns (e.g. `*.safetensors,*.json`). |
| `cache_dir` | no | per-task home | Where the Hub cache lives. A workspace path (e.g. `/mnt/workspace/hf-cache`) survives the task and is reused by later downloads. |
| `dest` | yes | — | Absolute path to the download directory inside the container (e.g. `/mnt/workspace/llama` to share it with later tasks). |
| `token` | no | — | HF access token for gated/private repos (pass a secret). |

## Outputs

| Output | Description |
|--------|-------------|
| `path` | The local directory the content was downloaded to — the `dest` you passed (e.g. `/mnt/workspace/llama`). |

## Compute

**CPU.** Data movement only — no GPU is needed, and scheduling it on a GPU compute type wastes money.

## Example

```yaml
name: Hugging Face download example
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
```

Downstream tasks read the files at `/mnt/workspace/llama`, or reference the
resolved location via `${{tasks.weights.outputs.path}}`.

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
