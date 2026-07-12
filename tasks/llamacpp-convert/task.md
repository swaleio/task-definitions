---
name: llama.cpp convert
description: Converts a Hugging Face format model directory into a single GGUF file with llama.cpp's convert_hf_to_gguf.py.
inputs:
  model_dir:
    description: Absolute path inside the container of the Hugging Face format model directory to convert. Point it at the mounted workspace (e.g. /mnt/workspace/model-hf) where an earlier task placed the model, or any other container-local path.
    required: true
  outfile:
    description: Absolute path inside the container for the converted .gguf file. Point it at the mounted workspace (e.g. /mnt/workspace/model-f16.gguf) to share it with later tasks, or any other container-local path.
    required: true
  outtype:
    description: "GGUF tensor type to write: f16, bf16, or q8_0."
    required: true
exec:
  # ghcr.io/ggml-org/llama.cpp:full-b9976
  image: ghcr.io/ggml-org/llama.cpp@sha256:2db4f3db6f354a7e73bb414674b32ea9812d93beee09ac28dcd71ed16f1060e0
  args:
    - "--convert"
    - ${{inputs.model_dir}}
    - "--outfile"
    - ${{inputs.outfile}}
    - "--outtype"
    - ${{inputs.outtype}}
---

# llama.cpp convert

Converts a Hugging Face format model directory (`config.json`, tokenizer files,
`*.safetensors`) into a single GGUF file that llama.cpp-based runtimes can load.
The image's ENTRYPOINT is llama.cpp's `/app/tools.sh` dispatcher, which runs
**exactly one mode per invocation**: the leading `--convert` argument execs
`convert_hf_to_gguf.py` with the remaining arguments. That one-mode-per-invocation
dispatch is why converting and quantizing are two separate tasks —
`llamacpp-convert` and `llamacpp-quantize` — rather than one; chain them, as in
the example below.

This task declares no outputs: it runs the vendor image unmodified, so there is
no wrapper to append to `$WORKFLOW_TASK_OUTPUT` — and none is needed, because
the consumer already knows where the result lands: it supplied `outfile`. Pass
the same path to the next task.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `model_dir` | yes | — | Absolute path of the Hugging Face format model directory to convert. Point it at the mounted workspace (e.g. `/mnt/workspace/model-hf`) where an earlier task placed the model, or any other container-local path. |
| `outfile` | yes | — | Absolute path for the converted `.gguf` file. Point it at the mounted workspace (e.g. `/mnt/workspace/model-f16.gguf`) to share it with later tasks, or any other container-local path. |
| `outtype` | yes | — | GGUF tensor type: `f16`, `bf16`, or `q8_0`. |

All three inputs are required. In particular `outtype` carries no default,
because definition defaults are not applied at runtime: an unset input would
interpolate into the fixed argv as an empty token and break the converter's
argument parsing. Pick `f16` as the usual full-precision baseline before
quantizing, `bf16` to carry a bf16 checkpoint through unchanged, or `q8_0` to
get an 8-bit file directly from conversion.

## Compute

This task needs **no GPU** — schedule it on a CPU `compute_type`. Conversion is
CPU- and RAM-bound: it reads the source tensors and rewrites them in GGUF
layout, with no CUDA involved. Budget disk rather than VRAM: the workspace must
hold the source directory and the converted file side by side (an `f16` GGUF is
roughly 2 bytes per parameter).

## Example

Download a model from the Hugging Face Hub, convert it to an `f16` GGUF, then
quantize it with `llamacpp-quantize`. Each task lists its predecessor in
`start_on` so the steps run in order, and the files are exchanged through the
shared workspace paths the consumer chose.

```yaml
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
      outfile: /mnt/workspace/qwen-f16.gguf
      outtype: f16
  quantize:
    name: Quantize
    uses: swaleio/llamacpp-quantize@1-0-0
    start_on:
      - convert
    args:
      input_gguf: /mnt/workspace/qwen-f16.gguf
      output_gguf: /mnt/workspace/qwen-q4_k_m.gguf
      preset: Q4_K_M
```

Downstream tasks read the quantized model at `/mnt/workspace/qwen-q4_k_m.gguf`
— the path the workflow supplied, so no output lookup is needed.
