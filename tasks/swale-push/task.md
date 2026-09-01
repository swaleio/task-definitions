---
name: Swale push
description: Pushes files from the workspace to a Swale repository.
inputs:
  target:
    description: "Repository to push to, as <project>/<repository>[:<tag>]. Without a tag, the push is tagged latest."
    required: true
  source:
    description: Absolute path inside the container to push. Point it at the mounted workspace (e.g. ${{env.WORKFLOW_STORAGE}}/outputs) to publish a result an earlier task wrote there, or at any other container-local path.
    required: true
  account:
    description: Swale account name for authentication. Delivered to the CLI as SWALE_ACCOUNT_NAME.
    required: true
  token:
    description: Swale access token for authentication (pass a secret). Delivered to the CLI as SWALE_ACCOUNT_TOKEN, never placed on the command line.
    required: true
exec:
  # docker.io/swaleio/swale-cli:0.1.0
  image: docker.io/swaleio/swale-cli@sha256:9a5ccf315a27f27740dc1683d3a5720793e9215c3eae57b83f0fb3a5b8eb173f
  # The CLI reads its credentials from the environment. exec.env is how they get
  # there without appearing in the container's argv, and so its pod spec.
  env:
    SWALE_ACCOUNT_NAME: ${{inputs.account}}
    SWALE_ACCOUNT_TOKEN: ${{inputs.token}}
  args:
    - push
    - ${{inputs.target}}
    - "--path"
    - ${{inputs.source}}
---

# Swale push

Pushes the file or directory at `source` to a Swale repository. Point `source`
at the mounted workspace (e.g. `${{env.WORKFLOW_STORAGE}}/outputs`) to publish
artifacts an earlier task wrote there, or at any other container-local path.
This is how a run publishes its results back to Swale once the work is done.

`target` names where to push, in the CLI's own form —
`<project>/<repository>[:<tag>]`. The tag labels the version this push creates
and is part of the target rather than a separate input; omit it and the push is
tagged latest.

Authentication uses `account` and `token`, delivered to the CLI as
`SWALE_ACCOUNT_NAME` and `SWALE_ACCOUNT_TOKEN`. Pass `token` as a secret so it
never appears in the container's argv, pod spec, or run logs.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `target` | yes | — | Repository to push to, as `<project>/<repository>[:<tag>]`. |
| `source` | yes | — | Absolute container path to push (e.g. `${{env.WORKFLOW_STORAGE}}/outputs`). |
| `account` | yes | — | Swale account name; delivered as `SWALE_ACCOUNT_NAME`. |
| `token` | yes | — | Swale access token (pass a secret); delivered as `SWALE_ACCOUNT_TOKEN`. |

A push records no message; the tag in `target` is what identifies the version it
creates.

## Compute

**CPU.** Data movement only — no GPU is needed, and scheduling it on a GPU compute type wastes money.

## Example

```yaml
name: Swale push example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      publish:
        name: Publish artifacts
        uses: swaleio/swale-push@1.0.0
        args:
          target: acme/model-artifacts:nightly
          source: ${{env.WORKFLOW_STORAGE}}/outputs
          account: acme
          token: ${{secrets.swale_token}}
```

This pushes `${{env.WORKFLOW_STORAGE}}/outputs` to the `acme/model-artifacts`
repository under the `nightly` tag, authenticating with the `acme` account and
the `swale_token` secret.

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
