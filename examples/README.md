# Example workflows

End-to-end **workflow** definitions that compose the catalog's tasks. Unlike the
`tasks/` directory (which the platform imports), these are illustrative starting
points — copy one into your own project and adapt it.

| File | Pipeline | Compute |
|------|----------|---------|
| [`finetune-to-gguf.yaml`](finetune-to-gguf.yaml) | `hf-download` → `axolotl-train` (QLoRA) → `merge` → GGUF `convert`+`quantize` → `swale-push` | GPU (CPU for the llama.cpp steps) |
| [`batch-inference.yaml`](batch-inference.yaml) | `hf-download` → batch requests → `vllm-batch` → `swale-push` | GPU |
| [`clone-build-publish.yaml`](clone-build-publish.yaml) | `git-clone` → `bash` build → `swale-push` | CPU |

## Conventions these examples follow

- **Tasks are referenced as `swaleio/<name>@<version>`.** They pin `@1-0-0`; bump
  the version when you adopt a newer task release.
- **Secrets** (`${{secrets.hf_token}}`, `${{secrets.swale_token}}`,
  `${{secrets.git_token}}`) are project/account secrets you configure in Swale —
  they are not part of the workflow file.
- **`account: swaleio`** in the `swale-push` steps names the catalog's own
  account only because these publish *to* Swale; change it to your account.
- **`compute_type`** is `cpu` or `gpu`; the exact GPU compute type available to a
  project is chosen at run time. CPU-bound steps in a GPU pipeline override
  `compute_type: cpu` so they don't occupy a GPU.
- **Files flow through `/mnt/workspace`** — each task writes to a path a later
  task reads. Adjust the paths freely; they are the consumers' choice.
- **Expression string literals use single quotes** (e.g. `${{inputs.mode == 'fast'}}`).

See the [workflow definition syntax](https://docs.swale.io/reference/workflow-definition-syntax)
reference for the full format.
