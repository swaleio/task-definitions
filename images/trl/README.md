# trl

Swale-built image backing the `trl-sft` task definition. It layers Hugging
Face [TRL](https://huggingface.co/docs/trl) and the training stack it drives on
top of the official PyTorch CUDA runtime, so a workflow can run supervised
fine-tuning from a config file without a build step.

- **Base:** the official PyTorch CUDA runtime image (`pytorch/pytorch`, CUDA
  13.0, cuDNN 9)
- **Installed:** TRL, Transformers, Accelerate, Datasets, PEFT, SentencePiece
  and the Hugging Face Hub client, at the versions pinned in
  [`requirements.txt`](https://github.com/swaleio/task-definitions/blob/main/images/trl/requirements.txt)
- **User:** non-root `swale` (uid 1000)
- **`WORKDIR /mnt/workspace`**, **no `ENTRYPOINT`**

## Invocation

The image declares **no entrypoint** (the PyTorch base leaves it unset), so a
task definition's `exec.args` are the **full** command line:
`["trl", "sft", "--config", "${{inputs.config}}"]`.

Hugging Face authentication is not the image's job: a definition that needs it
maps its `token` input to `HF_TOKEN` via its own `exec.env` (an omitted token
resolves to an empty `HF_TOKEN`, which the Hugging Face stack treats as no
token).

## GPU

This is a CUDA image. Tasks that reference it require a **GPU compute type**;
on a CPU type it fails at runtime with CUDA errors.

## Tags

Each tag is the version of TRL the image packages, such as `0.24.0`. A
rebuild that keeps that version, to pick up a fixed base image or wrapper,
adds `-r1`, `-r2`, and so on. A tag is never reused; `latest` follows the
newest publish.

## Building

From the repository root:

```sh
docker build -t swaleio/trl:dev images/trl
```

Merging a change under `images/trl` publishes the image under its next tag;
task definitions reference it by digest.

---

Built from [`images/trl`](https://github.com/swaleio/task-definitions/tree/main/images/trl) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile is covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). The software this image packages keeps
its own licenses, which ship inside the image.
