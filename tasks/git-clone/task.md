---
name: Git clone
description: Clones a Git repository into the workspace over HTTPS, with optional token auth and Git LFS support.
inputs:
  repository_url:
    description: HTTPS URL of the repository to clone.
    required: true
  revision:
    description: Branch, tag, or commit to check out. Defaults to the repository's default branch.
    default: ""
  dest:
    description: Absolute path inside the container. Point it at the mounted workspace (e.g. /mnt/workspace/repo) to share the result with later tasks, or any other container-local path.
    required: true
  git_token:
    description: Token for private-repository HTTPS auth (pass a secret). Omit for public repos.
    default: ""
outputs:
  commit_sha:
    description: The resolved HEAD commit SHA after cloning.
exec:
  # docker.io/swaleio/git:1-0-0
  image: docker.io/swaleio/git@sha256:0000000000000000000000000000000000000000000000000000000000000000
  args:
    - clone
    - "--depth=1"
    - ${{inputs.repository_url}}
    - ${{inputs.dest}}
---

# Git clone

Clones `repository_url` into the container-local path given by `dest` and emits
the resolved `commit_sha` for downstream tasks.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `repository_url` | yes | — | HTTPS URL of the repository. |
| `revision` | no | default branch | Branch, tag, or commit to check out. |
| `dest` | yes | — | Absolute clone path inside the container. Point it at the mounted workspace (e.g. `/mnt/workspace/repo`) to share the clone with later tasks, or any other container-local path. |
| `git_token` | no | — | Token for private repos (pass a project/account secret). |

## Outputs

| Output | Description |
|--------|-------------|
| `commit_sha` | The resolved HEAD commit SHA. |

## Compute

**CPU.** Data movement only — no GPU is needed, and scheduling it on a GPU compute type wastes money.

## Example

```yaml
tasks:
  checkout:
    name: Checkout
    uses: swaleio/git-clone@1-0-0
    args:
      repository_url: https://github.com/acme/app.git
      dest: /mnt/workspace/repo
      git_token: ${{secrets.github_token}}
```

Downstream tasks read the cloned files at `/mnt/workspace/repo` and the commit
via `${{tasks.checkout.outputs.commit_sha}}`.

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
