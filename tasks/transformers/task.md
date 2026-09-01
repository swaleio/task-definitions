---
name: Transformers
description: Runs an arbitrary Python script on a CUDA GPU with torch, transformers, trl, and peft ready.
inputs:
  script:
    description: The Python program to run. Parameterize it by interpolating a trusted workflow expression into the program text, or by reading a run-level environment variable via os.environ inside it.
    required: true
exec:
  # docker.io/swaleio/transformers-gpu:1-0-0
  image: docker.io/swaleio/transformers-gpu@sha256:cd90129e2b50edd8c9f5bbe2cf5e717e173df50822143208d69d5a80b02136a5
  args:
    - bash
    - -lc
    - 'printf %s "$INPUT_SCRIPT" > /tmp/run.py && exec python /tmp/run.py'
---

# Transformers

Writes your `script` to `/tmp/run.py` and runs it with `python` on the Swale
GPU ML image: **torch 2.13 (CUDA 13.0)** plus pinned **transformers**,
**accelerate**, **datasets**, **trl**, **peft**, and **sentencepiece** are
preinstalled, so inference pipelines, tokenizer work, dataset preprocessing,
and custom training loops run without any build step. Tracebacks and multi-line
programs behave exactly as they do in a normal interpreter.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `script` | yes | — | The Python program to run. Parameterize by interpolating a trusted workflow expression or reading a run-level env var via `os.environ`. |

## Compute

**GPU required.** Small pipeline inference fits in a few GB of VRAM; 7–8B
models in bf16 want 16–24 GB; larger models scale from there. The workflow
selects the compute type via `compute_type`; on a CPU compute type the task
fails at runtime with CUDA errors (`torch.cuda.is_available()` is `False`,
and any `.to("cuda")` raises).

## Example

The task declares only `script`, so the example passes only `script` and the
program is self-contained — it pulls a small public model from the Hub and runs
it on the GPU.

```yaml
name: Transformers example
compute_type: gpu
entry_point: main

blocks:
  main:
    tasks:
      classify:
        name: Classify
        uses: swaleio/transformers@1.0.0
        args:
          script: |
            import torch
            from transformers import pipeline

            assert torch.cuda.is_available(), "schedule this task on a GPU compute type"

            clf = pipeline(
                "text-classification",
                model="distilbert/distilbert-base-uncased-finetuned-sst-2-english",
                device=0,
            )
            for result in clf(["Swale makes this easy.", "This queue is painfully slow."]):
                print(result)
```

## Parameterizing

This task declares only `script`, so there are no extra args to pass — the
example passes `script` and nothing else. To feed a value into the program,
either:

- interpolate a **trusted** workflow expression — `${{ inputs.x }}` or
  `${{ tasks.x.outputs.y }}` — into the program text before it runs, or
- read a run-level environment variable inside the program (via `os.environ`).

Never interpolate an **untrusted** value into the program text: it is executed
as Python, so an attacker-controlled expression could inject arbitrary code.
Keep untrusted data out of the program body.

## Gated models and tokens

Because this free-form task declares only `script`, there is no `token` input
(and no `INPUT_TOKEN` for the image entrypoint to export). To authenticate
against the Hugging Face Hub for gated or private repos, publish `HF_TOKEN` as
a run-level environment variable from an earlier task — the platform injects
run-level env vars into every later container, and the Hugging Face libraries
pick `HF_TOKEN` up automatically:

```yaml
name: Transformers - Gated models and tokens
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      publish_token:
        name: Publish HF token
        uses: swaleio/bash@1.0.0
        args:
          script: |
            printf 'HF_TOKEN=%s\n' '${{secrets.hf_token}}' >> "$WORKFLOW_ENV"
      generate:
        name: Generate
        uses: swaleio/transformers@1.0.0
        compute_type: gpu   # any GPU compute type available to your project
        start_on:
          - publish_token
        args:
          script: |
            # HF_TOKEN is now in the environment; load a gated model as usual.
            ...
```

## Emitting outputs

Append `key=value` lines to the file at `$WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks (declare them in a task that needs typed outputs;
this generic `transformers` task declares none, so emitting a key here would
fail the task). Exchange large results through files instead: write to the
working directory, or to the shared workspace (`$WORKFLOW_STORAGE` in the container) when a later
task must read them.

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
