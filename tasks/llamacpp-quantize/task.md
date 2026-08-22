---
name: llama.cpp quantize
description: Quantizes a GGUF model file to a smaller preset (e.g. Q4_K_M) with llama.cpp's llama-quantize.
inputs:
  input_gguf:
    description: Absolute path inside the container of the source .gguf file, typically the outfile of a llamacpp-convert task. Point it at the mounted workspace (e.g. /mnt/workspace/model-f16.gguf), or any other container-local path.
    required: true
  output_gguf:
    description: Absolute path inside the container for the quantized .gguf file. Point it at the mounted workspace (e.g. /mnt/workspace/model-q4_k_m.gguf) to share it with later tasks, or any other container-local path.
    required: true
  preset:
    description: Quantization preset understood by llama-quantize, e.g. Q4_K_M, Q5_K_M, Q8_0.
    required: true
exec:
  # ghcr.io/ggml-org/llama.cpp:full-b9976
  image: ghcr.io/ggml-org/llama.cpp@sha256:2db4f3db6f354a7e73bb414674b32ea9812d93beee09ac28dcd71ed16f1060e0
  args:
    - "--quantize"
    - ${{inputs.input_gguf}}
    - ${{inputs.output_gguf}}
    - ${{inputs.preset}}
---

# llama.cpp quantize

Quantizes an existing GGUF file down to a smaller preset using llama.cpp's
`llama-quantize`, trading a little quality for a much smaller and faster model.
The image's ENTRYPOINT is llama.cpp's `/app/tools.sh` dispatcher, which runs
**exactly one mode per invocation**: the leading `--quantize` argument execs
`llama-quantize` with the remaining arguments. That one-mode-per-invocation
dispatch is why quantizing and converting are two separate tasks —
`llamacpp-quantize` and `llamacpp-convert` — rather than one; chain them, as in
the example below.

This task declares no outputs: it runs the vendor image unmodified, so there is
no wrapper to append to `$WORKFLOW_TASK_OUTPUT` — and none is needed, because
the consumer already knows where the result lands: it supplied `output_gguf`.
Pass the same path to the next task.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `input_gguf` | yes | — | Absolute path of the source `.gguf` file — typically the `outfile` of a `llamacpp-convert` task (e.g. `/mnt/workspace/model-f16.gguf`). |
| `output_gguf` | yes | — | Absolute path for the quantized `.gguf` file. Point it at the mounted workspace (e.g. `/mnt/workspace/model-q4_k_m.gguf`) to share it with later tasks, or any other container-local path. |
| `preset` | yes | — | Quantization preset, e.g. `Q4_K_M`, `Q5_K_M`, `Q8_0`. |

All three inputs are required. `input_gguf` and `output_gguf` are the paths you
choose; `preset` has no default because `llama-quantize` has none either — it
refuses to guess a quantization type, and neither does this task. The preset is
the decision the task exists to make: every value is a different
quality-per-byte trade, none of them a neutral setting. `Q4_K_M` is the usual
choice, `Q5_K_M` trades size for quality, and `Q8_0` is near-lossless but
largest.

## Compute

**CPU.** `llama-quantize` is a multi-threaded CPU program — more cores make it
faster, and a GPU adds nothing. Budget disk rather than VRAM: the workspace
must hold the source and quantized files side by side (a `Q4_K_M` file is
roughly a third the size of its 16-bit source).

## Example

Download a model from the Hugging Face Hub, convert it to a 16-bit GGUF with
`llamacpp-convert`, then quantize it to `Q4_K_M`. Each task lists its
predecessor in `start_on` so the steps run in order, and the files are
exchanged through the shared workspace paths the consumer chose.

```yaml
name: llama.cpp quantize example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      weights:
        name: Fetch weights
        uses: swaleio/hf-download@1-0-0
        args:
          repo: Qwen/Qwen2.5-1.5B-Instruct
          include: "*.safetensors,*.json,tokenizer.*"
          dest: /mnt/workspace/qwen-hf
      convert:
        name: Convert to GGUF
        uses: swaleio/llamacpp-convert@1-0-0
        start_on:
          - weights
        args:
          model_dir: /mnt/workspace/qwen-hf
          outfile: /mnt/workspace/qwen-16bit.gguf
      quantize:
        name: Quantize
        uses: swaleio/llamacpp-quantize@1-0-0
        start_on:
          - convert
        args:
          input_gguf: /mnt/workspace/qwen-16bit.gguf
          output_gguf: /mnt/workspace/qwen-q4_k_m.gguf
          preset: Q4_K_M
```

Downstream tasks read the quantized model at `/mnt/workspace/qwen-q4_k_m.gguf`
— the path the workflow supplied, so no output lookup is needed.

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
