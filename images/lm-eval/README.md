# lm-eval

Swale-built image backing the `lm-eval` task definition. It is the official
[vLLM](https://docs.vllm.ai) image with the EleutherAI
[evaluation harness](https://github.com/EleutherAI/lm-evaluation-harness)
installed on top, so a workflow can benchmark a model on a GPU with vLLM as
the inference backend.

- **Base:** the official `vllm/vllm-openai` image (CUDA 13.0, Ubuntu 24.04)
- **Installed:** `lm-eval`, at the version pinned in
  [`requirements.txt`](https://github.com/swaleio/task-definitions/blob/main/images/lm-eval/requirements.txt) — the `lm_eval`
  CLI, which drives the bundled vLLM engine as its inference backend
- **User:** non-root `swale` (uid 1000; replaces the Ubuntu base image's
  default uid-1000 user)
- **`WORKDIR /mnt/workspace`**, **`ENTRYPOINT []`**

## Entrypoint

The base image's ENTRYPOINT launches the OpenAI-compatible API server; this
image **resets it to empty** (`ENTRYPOINT []`), so a task definition's
`exec.args` form the **full** command line: `["lm_eval", ...]`.

Hugging Face authentication is not the image's job: a definition that needs it
maps its `token` input to `HF_TOKEN` via its own `exec.env` (an omitted token
resolves to an empty `HF_TOKEN`, which the Hugging Face stack treats as no
token).

## Outputs

The `lm-eval` task declares no outputs — results are written to a
caller-supplied file path — so nothing is appended to `$WORKFLOW_TASK_OUTPUT`.

## Shared memory

vLLM's tensor-parallel workers exchange tensors through `/dev/shm`, so shared
memory sizing matters when a model is sharded across several GPUs. The platform
provides a default shm size; single-GPU workloads run fine with it.

## Tags

Each tag is the version of lm-eval the image packages, such as `0.4.12`. A
rebuild that keeps that version, to pick up a fixed base image or wrapper,
adds `-r1`, `-r2`, and so on. A tag is never reused; `latest` follows the
newest publish.

## Building

From the repository root:

```sh
docker build -t swaleio/lm-eval:dev images/lm-eval
```

Merging a change under `images/lm-eval` publishes the image under its next tag;
task definitions reference it by digest.

---

Built from [`images/lm-eval`](https://github.com/swaleio/task-definitions/tree/main/images/lm-eval) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile is covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). The software this image packages keeps
its own licenses, which ship inside the image.
