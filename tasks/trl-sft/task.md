---
name: TRL SFT
description: Fine-tunes a causal language model with TRL supervised fine-tuning from a config file.
inputs:
  config:
    description: Absolute path inside the container to the TRL SFT YAML config. Point it at the mounted workspace (e.g. /mnt/workspace/sft.yaml) so an earlier task can write it there, or any other container-local path.
    required: true
  token:
    description: Hugging Face access token for gated or private models and datasets (pass a secret). Delivered as HF_TOKEN via the definition's exec.env; omit for public repos.
    default: ""
exec:
  # docker.io/swaleio/transformers-gpu:1-0-0
  image: docker.io/swaleio/transformers-gpu@sha256:0000000000000000000000000000000000000000000000000000000000000000
  env:
    HF_TOKEN: ${{inputs.token}}
  args:
    - trl
    - sft
    - "--config"
    - ${{inputs.config}}
---

# TRL SFT

Runs `trl sft --config <config>` — supervised fine-tuning with
[TRL](https://huggingface.co/docs/trl)'s `SFTTrainer`. Everything about the run
lives in the YAML file at `config`: the base model, the dataset, PEFT/LoRA
settings, precision, batch sizes, and where the result lands.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `config` | yes | — | Absolute path to the TRL SFT YAML config inside the container. Point it at the mounted workspace (e.g. `/mnt/workspace/sft.yaml`) so an earlier task can write it there. |
| `token` | no | — | HF access token for gated/private models and datasets (pass a secret). Delivered to the trainer as `HF_TOKEN` via the definition's `exec.env` (an omitted token resolves to an empty value, which the Hugging Face stack treats as no token); it is never placed on the command line. |

## Where the model lands

This task declares **no outputs** — the fine-tuned model is written to the
config's `output_dir`, wherever that points. Set `output_dir` to a path on the
mounted workspace that you choose (e.g. `/mnt/workspace/sft-out`) so later
tasks — evaluation, publishing, serving — can read the checkpoint directly from
that path. To publish the checkpoint, use `swaleio/swale-push` (the
platform's own store) or `swaleio/hf-upload` for the Hugging Face Hub.

## Compute

**GPU required.** As rough guidance, a LoRA/QLoRA fine-tune of a 0.5–8B model
fits on 16–24 GB-class GPUs; full-parameter fine-tunes of 7–8B models want
80 GB-class hardware. The workflow selects the compute type via
`compute_type`; on a CPU compute type the task fails at runtime with CUDA
errors.

## Example

A `bash` task writes the config onto the shared workspace, then `trl-sft`
consumes it. A tiny model and public dataset keep the run small:

```yaml
tasks:
  write_config:
    name: Write config
    uses: swaleio/bash@1-0-0
    args:
      script: |
        cat > /mnt/workspace/sft.yaml <<'EOF'
        model_name_or_path: Qwen/Qwen2.5-0.5B-Instruct
        dataset_name: trl-lib/Capybara
        learning_rate: 2.0e-5
        num_train_epochs: 1
        per_device_train_batch_size: 2
        gradient_accumulation_steps: 8
        bf16: true
        use_peft: true
        lora_r: 16
        lora_alpha: 32
        report_to: none
        output_dir: /mnt/workspace/sft-out
        EOF
  train:
    name: Train
    uses: swaleio/trl-sft@1-0-0
    start_on:
      - write_config
    args:
      config: /mnt/workspace/sft.yaml
      token: ${{secrets.hf_token}}
```

Downstream tasks read the fine-tuned adapter/model at `/mnt/workspace/sft-out`
— the `output_dir` the config chose.
