---
name: Axolotl train
description: Fine-tunes a model with Axolotl — full fine-tune, LoRA, or QLoRA — driven entirely by a caller-supplied Axolotl config YAML.
inputs:
  config:
    description: Absolute path inside the container to the Axolotl config YAML. Point it at the mounted workspace (e.g. /mnt/workspace/axolotl.yaml) so an earlier task can write it there, or any other container-local path.
    required: true
exec:
  # docker.io/axolotlai/axolotl:main-20260712-py3.12-cu130-2.12.0
  image: docker.io/axolotlai/axolotl@sha256:c33b21ad322e49fcc2db6116042cc206c69f26716482fc2902179fa303dd60b4
  args:
    - axolotl
    - train
    - ${{inputs.config}}
---

# Axolotl train

Runs `axolotl train` on the official Axolotl image against the config file you
point it at. Everything about the run — base model, dataset, adapter type
(full fine-tune, LoRA, QLoRA), hyperparameters, and where artifacts are
written — lives in that one Axolotl config YAML, so the task itself takes a
single input.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `config` | yes | — | Absolute path to the Axolotl config YAML inside the container. Point it at the mounted workspace (e.g. `/mnt/workspace/axolotl.yaml`) so an earlier task can write it there, or any other container-local path. |

## Training artifacts

This task declares no outputs — the vendor image has no wrapper to emit them.
Everything the run produces (adapter weights or full checkpoints, tokenizer
files, training logs) is written to the config's `output_dir`. Point
`output_dir` at a path a later task can consume — e.g.
`/mnt/workspace/lora-out` on the shared workspace — so downstream tasks such
as `swaleio/axolotl-merge-lora` or a publish task — `swaleio/swale-push@1-0-0`
(the platform's own store) or `swaleio/hf-upload` — can pick the artifacts up
from there.

## Compute

**GPU required.** Rough sizing:

- **Full fine-tune** of a 7–8B model wants an A100/H100-class card (80 GB
  VRAM).
- **QLoRA** of the same models fits in 24–48 GB; the example below runs
  comfortably at the low end.

The workflow selects the compute type via `compute_type`; the definition does
not pin one. On a CPU compute type the task does not fail fast — the container
starts, then crashes at runtime with CUDA errors once training tries to reach
a GPU.

## Gated base models

This task runs a vendor image, so it cannot export `HF_TOKEN` from a task
input. To fine-tune a gated base model (e.g. the Llama family), publish the
token as a **run-level environment variable** before this task runs: any
earlier task can append `HF_TOKEN=...` to the file at `$WORKFLOW_ENV`, and
run-level variables are injected into every later container in the run —
including this one, where Axolotl's Hub client picks `HF_TOKEN` up
automatically.

```yaml
  publish_token:
    name: Publish HF token
    uses: swaleio/bash@1-0-0
    args:
      script: |
        set -euo pipefail
        printf 'HF_TOKEN=%s\n' '${{secrets.hf_token}}' >> "$WORKFLOW_ENV"
```

List `publish_token` in the training task's `start_on` so the variable is
published before training starts. The interpolated `${{secrets.hf_token}}` is
a trusted workflow expression (a secret you configured) — the only kind of
value that may be interpolated into a script.

## Example

A self-contained QLoRA run: a `bash` task writes a minimal config to the
shared workspace, then this task trains from it.

```yaml
tasks:
  write_config:
    name: Write training config
    uses: swaleio/bash@1-0-0
    args:
      script: |
        set -euo pipefail
        cat > /mnt/workspace/axolotl.yaml <<'EOF'
        base_model: TinyLlama/TinyLlama-1.1B-Chat-v1.0
        load_in_4bit: true
        adapter: qlora
        lora_r: 32
        lora_alpha: 16
        lora_dropout: 0.05
        lora_target_linear: true
        datasets:
          - path: mhenrichsen/alpaca_2k_test
            type: alpaca
        output_dir: /mnt/workspace/lora-out
        sequence_len: 2048
        micro_batch_size: 2
        gradient_accumulation_steps: 4
        num_epochs: 1
        optimizer: adamw_bnb_8bit
        learning_rate: 0.0002
        bf16: auto
        gradient_checkpointing: true
        EOF
  train:
    name: QLoRA fine-tune
    uses: swaleio/axolotl-train@1-0-0
    start_on:
      - write_config
    compute_type: gpu_a100   # any GPU compute type — see Compute above
    args:
      config: /mnt/workspace/axolotl.yaml
```

The trained adapter lands at `/mnt/workspace/lora-out` (the config's
`output_dir`), ready for `swaleio/axolotl-merge-lora`, `swaleio/swale-push`,
or `swaleio/hf-upload`.
