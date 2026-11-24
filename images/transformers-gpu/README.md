# transformers-gpu

Swale-built image backing the `transformers` task definition. It layers the
Hugging Face training stack on top of the official PyTorch CUDA runtime, so a
workflow can run inference, supervised fine-tuning, or arbitrary GPU Python
without a build step.

- **Base:** the official PyTorch CUDA runtime image (`pytorch/pytorch`, CUDA
  13.0, cuDNN 9)
- **Installed:** Transformers, Accelerate, Datasets, TRL, PEFT, SentencePiece
  and the Hugging Face Hub client, at the versions pinned in
  [`requirements.txt`](https://github.com/swaleio/task-definitions/blob/main/images/transformers-gpu/requirements.txt)
- **User:** non-root `swale` (uid 1000)
- **Hub cache** — defaults to the Hugging Face location under the home
  directory, which the platform mounts writable and per-task, so it is discarded
  with the task. A script that wants the weights reused by later tasks in the run
  sets `HF_HOME` (or `from_pretrained(cache_dir=...)`) to a workspace path
  itself — this image is driven by a free-form script, so nothing here forces
  the default.
- **`WORKDIR /mnt/workspace`**, **no `ENTRYPOINT`**

## Invocation

The image declares **no entrypoint** (the PyTorch base leaves it unset), so a
task definition's `exec.args` are the **full** command line, here a free-form
script (`["bash", "-lc", "… exec python /tmp/run.py"]`). `bash`, `trl`, and
`python` are all on `PATH`.

Hugging Face authentication is not the image's job: a definition that needs it
maps its `token` input to `HF_TOKEN` via its own `exec.env` (an omitted token
resolves to an empty `HF_TOKEN`, which the Hugging Face stack treats as no
token).

## GPU

This is a CUDA image. Tasks that reference it require a **GPU compute type** —
the workflow selects the compute type, and scheduling on a CPU type fails at
runtime with CUDA errors (`gpu-smoke-test` exists to surface exactly that,
fast).

## Tags

Each tag is the version of Transformers the image packages, such as `4.57.1`. A
rebuild that keeps that version, to pick up a fixed base image or wrapper,
adds `-r1`, `-r2`, and so on. A tag is never reused; `latest` follows the
newest publish.

## Building

From the repository root:

```sh
docker build -t swaleio/transformers-gpu:dev images/transformers-gpu
```

Merging a change under `images/transformers-gpu` publishes the image under its next tag;
task definitions reference it by digest.

---

Built from [`images/transformers-gpu`](https://github.com/swaleio/task-definitions/tree/main/images/transformers-gpu) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile and entrypoint are covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). The software this image packages keeps
its own licenses, which ship inside the image.
