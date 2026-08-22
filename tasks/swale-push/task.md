---
name: Swale push
description: Pushes run artifacts from the workspace back to a Swale repository.
inputs:
  project:
    description: Target Swale repository (project) to push the artifacts to.
    required: true
  account:
    description: Swale account name for authentication. Read from the INPUT_ACCOUNT environment variable and exported to the CLI as SWALE_ACCOUNT_NAME.
    required: true
  source:
    description: Absolute path inside the container. Point it at the mounted workspace (e.g. /mnt/workspace/outputs) to publish a result an earlier task wrote there, or any other container-local path.
    required: true
  message:
    description: Message recorded with the push.
    default: ""
  token:
    description: Swale access token for authentication (pass a secret). Read from the INPUT_TOKEN environment variable and exported to the CLI as SWALE_ACCOUNT_TOKEN, never placed on the command line.
    required: true
exec:
  # docker.io/swaleio/swale-cli:1-0-0
  image: docker.io/swaleio/swale-cli@sha256:c3717a48cd51c2c2b2f2890e52e21818d06a6e0dba7ee2abe713238c596d773c
  # Flag names (--project, --message) are provisional — verify against the swale CLI.
  # `account` and `token` are intentionally NOT args: the image reads them from
  # INPUT_ACCOUNT / INPUT_TOKEN so the secret never lands in the container argv
  # (pod spec / run logs).
  args:
    - push
    - "--project=${{inputs.project}}"
    - "--message=${{inputs.message}}"
    - ${{inputs.source}}
---

# Swale push

Pushes the contents of the `source` path you supply to the Swale repository named
by `project`, recording an optional `message`. Point `source` at the mounted
workspace (e.g. `/mnt/workspace/outputs`) to publish artifacts an earlier task
wrote there, or at any other container-local path. This is how a run publishes
its artifacts back to Swale once the work is done.

Authentication uses `account` and `token`, which the platform injects as the
`INPUT_ACCOUNT` and `INPUT_TOKEN` environment variables and the image exports to
the CLI as `SWALE_ACCOUNT_NAME` and `SWALE_ACCOUNT_TOKEN`. Pass `token` as a
secret so it never appears in the task's argv, pod spec, or run logs.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `project` | yes | — | Target Swale repository (project) to push to. |
| `account` | yes | — | Swale account name; injected as `INPUT_ACCOUNT` → `SWALE_ACCOUNT_NAME`. |
| `source` | yes | — | Absolute container path to push (e.g. `/mnt/workspace/outputs`). |
| `message` | no | `""` | Message recorded with the push. |
| `token` | yes | — | Swale access token (pass a secret); injected as `INPUT_TOKEN` → `SWALE_ACCOUNT_TOKEN`. |

> The `swale push` flag names above (`--project`, `--message`) are provisional
> and should be verified against the swale CLI before this version is published.

## Compute

**CPU.** Data movement only — no GPU is needed, and scheduling it on a GPU compute type wastes money.

## Example

```yaml
tasks:
  publish:
    name: Publish artifacts
    uses: swaleio/swale-push@1-0-0
    args:
      project: acme/model-artifacts
      account: acme
      source: /mnt/workspace/outputs
      message: Nightly build artifacts
      token: ${{secrets.swale_token}}
```

This pushes `/mnt/workspace/outputs` to the `acme/model-artifacts` repository,
authenticating with the `acme` account and the `swale_token` secret.

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
