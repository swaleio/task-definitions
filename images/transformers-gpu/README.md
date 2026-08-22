# transformers-gpu

Swale-built image backing the `transformers`, `trl-sft`, and `gpu-smoke-test`
task definitions. It layers the Hugging Face training stack on top of the
official PyTorch CUDA runtime, so a workflow can run inference, supervised
fine-tuning, or arbitrary GPU Python without a build step.

- **Base:** `pytorch/pytorch:2.13.0-cuda13.0-cudnn9-runtime` (torch 2.13.0,
  CUDA 13.0, cuDNN 9)
- **Installed (pinned):** `transformers==4.57.1`, `accelerate==1.11.0`,
  `datasets==4.4.1`, `trl==0.24.0`, `peft==0.18.0`, `sentencepiece==0.2.1`,
  `huggingface_hub[hf_xet]==0.36.0`
- **User:** non-root `swale` (uid 1000)
- **Hub cache** — stays at the Hugging Face default under the home directory,
  which the platform mounts writable and per-task. It is scratch, so a model a
  later task needs belongs on the shared workspace instead.
- **`WORKDIR /mnt/workspace`**, **no `ENTRYPOINT`**

## Invocation

The image declares **no entrypoint** (the PyTorch base leaves it unset), so a
task definition's `exec.args` are the **full** command line — one image serves
a fixed CLI task (`["trl", "sft", "--config", "${{inputs.config}}"]`) and a
free-form script task (`["bash", "-lc", "… exec python /tmp/run.py"]`) alike.
`bash`, `trl`, and `python` are all on `PATH`.

Hugging Face authentication is not the image's job: a definition that needs it
maps its `token` input to `HF_TOKEN` via its own `exec.env` (an omitted token
resolves to an empty `HF_TOKEN`, which the Hugging Face stack treats as no
token).

## GPU

This is a CUDA image. Tasks that reference it require a **GPU compute type** —
the workflow selects the compute type, and scheduling on a CPU type fails at
runtime with CUDA errors (`gpu-smoke-test` exists to surface exactly that,
fast).

## Building

```sh
docker build -t docker.io/swaleio/transformers-gpu:1-0-0 images/transformers-gpu
```

CI pins the real base digest and publishes the image; task definitions
reference it as `docker.io/swaleio/transformers-gpu@sha256:<digest>`.
