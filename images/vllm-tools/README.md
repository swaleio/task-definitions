# vllm-tools

Swale-built image backing the `vllm-batch` and `lm-eval` task definitions. It
is the official [vLLM](https://docs.vllm.ai) OpenAI-server image with the
EleutherAI [evaluation harness](https://github.com/EleutherAI/lm-evaluation-harness)
installed on top, so a single GPU image covers both offline batch inference and
model evaluation.

- **Base:** `vllm/vllm-openai:v0.25.0-cu129-ubuntu2404` (digest-pinned)
- **Installed on top:** `lm-eval==0.4.12` — the `lm_eval` CLI, which drives the
  bundled vLLM engine as its inference backend
- **User:** non-root `swale` (uid 1000; replaces the Ubuntu base image's
  default uid-1000 user)
- **`WORKDIR /mnt/workspace`**, **`ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`**

## Entrypoint

The base image's ENTRYPOINT launches the OpenAI-compatible API server; this
image **resets** it. `entrypoint.sh` exports environment from task inputs and
then runs `exec "$@"`, so a task definition's `exec.args` form the **full**
command line:

- `["vllm", "run-batch", ...]` — offline batch inference (the `vllm-batch` task)
- `["lm_eval", ...]` — benchmark evaluation (the `lm-eval` task)

| Input env | Effect |
|-----------|--------|
| `INPUT_TOKEN` | Exported as `HF_TOKEN` to authenticate against the Hugging Face Hub for gated or private repos. Pass a secret. |
| `INPUT_HF_HOME` | Exported as `HF_HOME` to relocate the Hub cache (e.g. onto the mounted workspace so downloaded blobs persist across tasks in a run). Optional; the default under the user's home is used when unset. |

## Outputs

Neither backed task declares outputs — results are written to caller-supplied
file paths — so the entrypoint appends nothing to `$WORKFLOW_TASK_OUTPUT`.

## Shared memory

vLLM's tensor-parallel workers exchange tensors through `/dev/shm`, so shared
memory sizing matters when a model is sharded across several GPUs. The platform
provides a default shm size; single-GPU workloads run fine with it.

## Building

```sh
docker build -t docker.io/swaleio/vllm-tools:1-0-0 images/vllm-tools
```

CI pins the real base digest and publishes the image; task definitions
reference it as `docker.io/swaleio/vllm-tools@sha256:<digest>`.
