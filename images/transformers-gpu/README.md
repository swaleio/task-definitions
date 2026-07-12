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
- **Hub cache** — stays at the Hugging Face default under the user's home; the
  image does not force a location. A caller can relocate it (e.g. onto the
  mounted workspace so model blobs persist across tasks in a run) by setting
  `INPUT_HF_HOME`.
- **`WORKDIR /mnt/workspace`**, **`ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`**

## Invocation

The entrypoint does not run a fixed tool. It exports Hugging Face environment
variables from task inputs (`INPUT_*` env vars injected by the platform) and
then `exec`s the task definition's `exec.args` verbatim — so one image serves a
fixed CLI task (`["trl", "sft", "--config", "${{inputs.config}}"]`) and a
free-form script task (`["bash", "-lc", "… exec python /tmp/run.py"]`) alike.

| Input env | Effect |
|-----------|--------|
| `INPUT_TOKEN` | Exported as `HF_TOKEN` to authenticate against the Hugging Face Hub (gated/private repos). Pass a secret. |
| `INPUT_HF_HOME` | Exported as `HF_HOME` to relocate the Hub cache (e.g. onto the mounted workspace). Optional; the default under the user's home is used when unset. |

Free-form tasks declare only `script`, so neither variable is set for them;
they read run-level environment variables instead (see the task docs).

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
