---
name: HF upload
description: Uploads a workspace directory to a repository on the Hugging Face Hub.
inputs:
  repo:
    description: Target repository id on the Hub, as "namespace/name".
    required: true
  repo_type:
    description: Repository kind on the Hub — one of "model", "dataset", or "space".
    default: model
  source:
    description: Absolute path inside the container to the directory to upload. Point it at the mounted workspace (e.g. ${{env.WORKFLOW_STORAGE}}/model) to pick up a directory an earlier task produced, or any other container-local path.
    required: true
  path_in_repo:
    description: Destination path inside the repository. Defaults to the repository root.
    default: ""
  token:
    description: Hugging Face access token with write scope (pass a secret).
    required: true
exec:
  # docker.io/swaleio/hf-cli:1-0-0
  image: docker.io/swaleio/hf-cli@sha256:c4433260a36c46289265b5ccd3a06847986879cefd2c1052cbe8e43ccbe7b116
  env:
    HF_TOKEN: ${{inputs.token}}
  args:
    - upload
    - "--repo-type"
    - ${{inputs.repo_type}}
    - ${{inputs.repo}}
    - ${{inputs.source}}
---

# HF upload

Uploads the directory given by `source` to the Hugging Face Hub repository
`repo`. Authentication uses the `token` secret, delivered to the CLI as
`HF_TOKEN` via the definition's `exec.env`; `path_in_repo` selects the
destination folder within the repository (root by default).

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `repo` | yes | — | Target repository id, `namespace/name`. |
| `repo_type` | no | `model` | Repository kind: `model`, `dataset`, or `space`. |
| `source` | yes | — | Absolute path to the directory to upload inside the container (e.g. `${{env.WORKFLOW_STORAGE}}/model`). |
| `path_in_repo` | no | repo root | Destination path inside the repository. |
| `token` | yes | — | Hugging Face write token (pass a project/account secret). |

## Compute

**CPU.** Data movement only — no GPU is needed, and scheduling it on a GPU compute type wastes money.

## Example

```yaml
name: HF upload example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      publish:
        name: Publish model
        uses: swaleio/hf-upload@1.0.0
        args:
          repo: acme/text-classifier
          repo_type: model
          source: ${{env.WORKFLOW_STORAGE}}/artifacts/model
          token: ${{secrets.hf_token}}
```

Uploads everything under `${{env.WORKFLOW_STORAGE}}/artifacts/model` to the `acme/text-classifier`
model repository on the Hub.

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
