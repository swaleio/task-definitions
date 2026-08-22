---
name: Swale pull
description: Pulls a Swale project's content into the workspace, at an optional ref and subpath.
inputs:
  project:
    description: The Swale project (repository) to pull content from.
    required: true
  account:
    description: Swale account name for authentication. Read from the INPUT_ACCOUNT environment variable and exported to the CLI as SWALE_ACCOUNT_NAME.
    required: true
  ref:
    description: Branch, tag, or commit to pull. Empty pulls the project's default ref.
    default: ""
  path:
    description: Restrict the pull to this subpath within the project. Empty pulls the whole project.
    default: ""
  dest:
    description: Absolute path inside the container. Point it at the mounted workspace (e.g. /mnt/workspace/repo) to share the result with later tasks, or any other container-local path.
    required: true
  token:
    description: Swale access token for authentication (pass a secret). Read from the INPUT_TOKEN environment variable and exported to the CLI as SWALE_ACCOUNT_TOKEN, never placed on the command line.
    required: true
exec:
  # docker.io/swaleio/swale-cli:1-0-0
  image: docker.io/swaleio/swale-cli@sha256:0000000000000000000000000000000000000000000000000000000000000000
  args:
    - pull
    - "--project"
    - ${{inputs.project}}
    - "--ref"
    - ${{inputs.ref}}
    - "--path"
    - ${{inputs.path}}
    - "--dest"
    - ${{inputs.dest}}
---

# Swale pull

Pulls the content of a Swale `project` into the `dest` path you supply, using the
Swale client CLI (`swale-cli`). Point `dest` at the mounted workspace (e.g.
`/mnt/workspace/repo`) so later tasks in the run can read it from the shared
workspace, or at any other container-local path. Restrict the pull to a single
`ref` and/or `path` when you only need part of a project.

Authentication uses `account` and `token`. The platform injects them as
`INPUT_ACCOUNT` and `INPUT_TOKEN`; the image exports them to the CLI as
`SWALE_ACCOUNT_NAME` and `SWALE_ACCOUNT_TOKEN`. Pass `token` as a secret so it
never appears in the container's argv or run logs.

> **CLI flags are provisional.** The exact `swale-cli pull` flag names
> (`--project`, `--ref`, `--path`, `--dest`) should be verified against the
> installed Swale CLI and adjusted if they differ. An empty `--ref`/`--path`
> value is expected to fall back to the project default / whole project.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `project` | yes | — | The Swale project to pull from. |
| `account` | yes | — | Swale account name; injected as `INPUT_ACCOUNT` → `SWALE_ACCOUNT_NAME`. |
| `ref` | no | default ref | Branch, tag, or commit to pull. |
| `path` | no | whole project | Subpath within the project to pull. |
| `dest` | yes | — | Absolute container path to write into (e.g. `/mnt/workspace/repo`). |
| `token` | yes | — | Swale access token (pass a secret); injected as `INPUT_TOKEN` → `SWALE_ACCOUNT_TOKEN`. |

Because the workspace is shared across concurrent tasks, give parallel pulls
distinct `dest` paths so they don't overwrite each other.

## Compute

**CPU.** Data movement only — no GPU is needed, and scheduling it on a GPU compute type wastes money.

## Example

```yaml
tasks:
  fetch_data:
    name: Fetch data
    uses: swaleio/swale-pull@1-0-0
    args:
      project: acme/datasets
      account: acme
      ref: main
      path: images/train
      dest: /mnt/workspace/data
      token: ${{secrets.swale_token}}
```

Downstream tasks read the pulled files from `/mnt/workspace/data`.

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
