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
    description: "GGUF tensor type to write: f16, bf16, or q8_0. Defaults to auto, which writes the checkpoint's own 16-bit float type — bf16 for a bf16 model, f16 otherwise."
    default: "auto"
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
| `outtype` | no | `auto` | GGUF tensor type: `f16`, `bf16`, or `q8_0`. The default `auto` matches the checkpoint — `bf16` for a bf16 model, `f16` otherwise. |

`model_dir` and `outfile` are required — they are the paths you choose and the
next task reads. `outtype` is optional and defaults to `auto`, which is what
`convert_hf_to_gguf.py` itself does when the flag is omitted: it reads the
checkpoint's own tensor dtype and writes `bf16` for a bf16 model, `f16` for an
f16 one. Pass it explicitly to override that heuristic — `f16` for a fixed
full-precision baseline whatever the source is, `bf16` to force bfloat16, or
`q8_0` to get an 8-bit file directly from conversion.

## Compute

**CPU.** Conversion is CPU- and RAM-bound — no CUDA is involved, so a GPU
compute type adds nothing. Budget disk rather than VRAM: the workspace must
hold the source directory and the converted file side by side (a 16-bit GGUF
is roughly 2 bytes per parameter).

## Example

Download a model from the Hugging Face Hub, convert it to a 16-bit GGUF, then
quantize it with `llamacpp-quantize`. The `convert` step leaves `outtype` unset,
so the converted file keeps the checkpoint's own dtype. Each task lists its
predecessor in `start_on` so the steps run in order, and the files are exchanged
through the shared workspace paths the consumer chose.

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
