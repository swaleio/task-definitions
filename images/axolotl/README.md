# axolotl

Swale-built image backing the `axolotl-train` and `axolotl-merge-lora` task
definitions. It is the official [Axolotl](https://docs.axolotl.ai) image, made
runnable by a non-root user: the official image installs its Python under
`/root`, which only root can enter, so any other user fails with `Permission
denied` before Axolotl starts.

- **Base:** the official `axolotlai/axolotl` image (Python 3.12, CUDA 13.0),
  whose tag is the Axolotl version
- **Changed:** `/root` opened to traversal so the virtualenv's interpreter is
  reachable; nothing else under it is readable that was not already
- **User:** non-root `swale` (uid 1000; replaces the Ubuntu base image's
  default uid-1000 user)
- **`WORKDIR /mnt/workspace`**, so the relative paths Axolotl writes, such as
  its prepared-dataset cache, land somewhere writable. The base's entrypoint,
  which sets up CUDA and then runs the task's `exec.args`, is unchanged.

## Invocation

A task definition's `exec.args` are the Axolotl command line, run through the
base image's entrypoint: `["axolotl", "train", "${{inputs.config}}"]` or
`["axolotl", "merge-lora", "${{inputs.config}}", "--lora-model-dir", ...]`.

Hugging Face authentication is not the image's job: a definition that needs it
maps its `token` input to `HF_TOKEN` via its own `exec.env` (an omitted token
resolves to an empty `HF_TOKEN`, which the Hugging Face stack treats as no
token).

## GPU

This is a CUDA image. Tasks that reference it require a **GPU compute type**;
on a CPU type training fails at runtime with CUDA errors.

## Tags

Each tag is the version of Axolotl the image packages, such as `0.21.1`. A
rebuild that keeps that version, to pick up a fixed base image or wrapper,
adds `-r1`, `-r2`, and so on. A tag is never reused; `latest` follows the
newest publish.

## Building

From the repository root:

```sh
docker build -t swaleio/axolotl:dev images/axolotl
```

Merging a change under `images/axolotl` publishes the image under its next tag;
task definitions reference it by digest.

---

Built from [`images/axolotl`](https://github.com/swaleio/task-definitions/tree/main/images/axolotl) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile is covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). The software this image packages keeps
its own licenses, which ship inside the image.
