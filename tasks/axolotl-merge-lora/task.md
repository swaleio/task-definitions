---
name: Axolotl merge LoRA
description: Merges a trained LoRA/QLoRA adapter into its base model with Axolotl, producing standalone merged weights ready to serve, quantize, or upload.
inputs:
  config:
    description: Absolute path inside the container to the Axolotl config YAML the adapter was trained with. Point it at the mounted workspace (e.g. /mnt/workspace/axolotl.yaml) to reuse the file the training task read, or any other container-local path.
    required: true
  adapter_dir:
    description: Absolute path inside the container to the trained LoRA adapter directory. Point it at the mounted workspace (e.g. /mnt/workspace/lora-out, the training config's output_dir) to consume the training task's result, or any other container-local path.
    required: true
exec:
  # docker.io/axolotlai/axolotl:main-20260712-py3.12-cu130-2.12.0
  image: docker.io/axolotlai/axolotl@sha256:c33b21ad322e49fcc2db6116042cc206c69f26716482fc2902179fa303dd60b4
  args:
    - axolotl
    - merge-lora
    - ${{inputs.config}}
    - "--lora-model-dir"
    - ${{inputs.adapter_dir}}
---

# Axolotl merge LoRA

Runs `axolotl merge-lora`: loads the base model named in the config, applies
the LoRA/QLoRA adapter from `adapter_dir`, and writes a standalone set of
merged weights that no longer needs the adapter — ready to serve, quantize, or
upload.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `config` | yes | — | Absolute path to the Axolotl config YAML the adapter was trained with. Point it at the mounted workspace (e.g. `/mnt/workspace/axolotl.yaml`) to reuse the file the training task read. |
| `adapter_dir` | yes | — | Absolute path to the trained LoRA adapter directory. Point it at the mounted workspace (e.g. `/mnt/workspace/lora-out`, the training config's `output_dir`) to consume the training task's result. |

## Merged model location

This task declares no outputs — the vendor image has no wrapper to emit them.
Per Axolotl's convention the merged model is written to a `merged/`
subdirectory alongside the adapter: with
`adapter_dir: /mnt/workspace/lora-out`, downstream tasks read the merged
weights at `/mnt/workspace/lora-out/merged`. Keep `adapter_dir` on the shared
workspace so later tasks can reach the result.

## Compute

**GPU recommended.** Merging runs on a CPU compute type — it loads the base
model weights, applies the adapter deltas, and saves the result; no training
kernels are involved — but it needs **RAM at least the size of the model
weights** (a 7–8B model in bf16 is roughly 16 GB), and a GPU compute type
makes the merge faster. The workflow selects the compute type via
`compute_type`, not this definition.

## Gated base models

Merging re-reads the base model from the Hugging Face Hub, so a gated base
needs a token here just like during training. This task runs a vendor image
and cannot take the token as an input; publish it as a **run-level environment
variable** instead — an earlier task appends `HF_TOKEN=...` to the file at
`$WORKFLOW_ENV`, and every later container (including this one) receives it.
See `swaleio/axolotl-train` for a ready-made snippet.

## Example

Chains training and merging: the config written in the first task is the same
one the merge reads, and `adapter_dir` is the config's `output_dir`.

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
    compute_type: gpu_a100   # training needs a GPU compute type — see swaleio/axolotl-train
    args:
      config: /mnt/workspace/axolotl.yaml
  merge:
    name: Merge adapter
    uses: swaleio/axolotl-merge-lora@1-0-0
    start_on:
      - train
    args:
      config: /mnt/workspace/axolotl.yaml
      adapter_dir: /mnt/workspace/lora-out
```

After the run, the merged model is at `/mnt/workspace/lora-out/merged`, ready
for `swaleio/swale-push` (the platform's own store), `swaleio/hf-upload`,
or a serving task.
