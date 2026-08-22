---
name: GPU smoke test
description: Verifies a GPU compute type end to end and emits the GPU name, VRAM size, and CUDA version.
outputs:
  gpu_name:
    description: The CUDA device name reported by torch (e.g. NVIDIA A100-SXM4-80GB).
  vram_gb:
    description: Total GPU memory in GiB, one decimal place (from torch.cuda.get_device_properties).
  cuda_version:
    description: The CUDA version the torch build targets (e.g. 13.0).
exec:
  # docker.io/swaleio/transformers-gpu:1-0-0
  image: docker.io/swaleio/transformers-gpu@sha256:cd90129e2b50edd8c9f5bbe2cf5e717e173df50822143208d69d5a80b02136a5
  args:
    - bash
    - -lc
    - >-
      set -eu;
      nvidia-smi --query-gpu=name,memory.total --format=csv,noheader;
      exec python -c "import os, torch;
      assert torch.cuda.is_available(), 'torch.cuda.is_available() is False - this task must run on a GPU compute type';
      p = torch.cuda.get_device_properties(0);
      x = torch.rand(1024, 1024, device='cuda');
      print('cuda matmul ok:', (x @ x).sum().item());
      open(os.environ['WORKFLOW_TASK_OUTPUT'], 'a').write('gpu_name=' + p.name + chr(10) + 'vram_gb=' + format(p.total_memory / 2**30, '.1f') + chr(10) + 'cuda_version=' + str(torch.version.cuda) + chr(10))"
---

# GPU smoke test

The mandatory first-run canary for a GPU compute type. It proves the whole GPU
path in seconds — the NVIDIA driver is mounted (`nvidia-smi`), torch sees the
device (`torch.cuda.is_available()`), and a real CUDA kernel runs (a
1024×1024 matmul) — then emits the GPU's name, VRAM, and CUDA version as typed
outputs. Run it as the first task the first time you point a workflow at a new
GPU compute type, before committing hours of training time to it.

## Inputs

None — the task takes no parameters.

## Outputs

| Output | Description |
|--------|-------------|
| `gpu_name` | The CUDA device name reported by torch (e.g. `NVIDIA A100-SXM4-80GB`). |
| `vram_gb` | Total GPU memory in GiB, one decimal place. |
| `cuda_version` | The CUDA version the torch build targets (e.g. `13.0`). |

## Compute

**GPU required.** Any VRAM size passes (it allocates only a few MB); the
workflow selects the compute type via `compute_type`. On a CPU compute type
the task **fails** — `nvidia-smi` is absent and `torch.cuda.is_available()`
is `False` — and that is by design: a mis-typed compute selection surfaces
here in seconds instead of deep inside a training job.

## Example

The task declares no inputs, so it takes no args:

```yaml
tasks:
  gpu_check:
    name: GPU check
    uses: swaleio/gpu-smoke-test@1-0-0
```

Downstream tasks read the probed hardware via
`${{tasks.gpu_check.outputs.gpu_name}}`,
`${{tasks.gpu_check.outputs.vram_gb}}`, and
`${{tasks.gpu_check.outputs.cuda_version}}`.

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
