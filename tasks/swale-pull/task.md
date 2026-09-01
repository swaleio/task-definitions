---
name: Swale pull
description: Pulls the content of a Swale repository into a path you choose.
inputs:
  target:
    description: "Repository to pull from, as <project>/<repository>[:<tag>]. Without a tag, the latest is pulled."
    required: true
  dest:
    description: Absolute path inside the container to write the pulled files to. Point it at the mounted workspace (e.g. ${{env.WORKFLOW_STORAGE}}/data) to share the result with later tasks, or at any other container-local path.
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
    - pull
    - ${{inputs.target}}
    - "--path"
    - ${{inputs.dest}}
---

# Swale pull

Pulls the content of a Swale repository into the `dest` path you supply. Point
`dest` at the mounted workspace (e.g. `${{env.WORKFLOW_STORAGE}}/data`) so later
tasks in the run can read it, or at any other container-local path.

`target` names what to pull, in the CLI's own form —
`<project>/<repository>[:<tag>]`. The tag selects the version and is part of the
target rather than a separate input; omit it and the latest is pulled.

Authentication uses `account` and `token`, delivered to the CLI as
`SWALE_ACCOUNT_NAME` and `SWALE_ACCOUNT_TOKEN`. Pass `token` as a secret so it
never appears in the container's argv, pod spec, or run logs.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `target` | yes | — | Repository to pull, as `<project>/<repository>[:<tag>]`. |
| `dest` | yes | — | Absolute container path to write into (e.g. `${{env.WORKFLOW_STORAGE}}/data`). |
| `account` | yes | — | Swale account name; delivered as `SWALE_ACCOUNT_NAME`. |
| `token` | yes | — | Swale access token (pass a secret); delivered as `SWALE_ACCOUNT_TOKEN`. |

A pull fetches the whole repository at the given tag; there is no way to
restrict it to a subpath.

Because the workspace is shared across concurrent tasks, give parallel pulls
distinct `dest` paths so they don't overwrite each other.

## Compute

**CPU.** Data movement only — no GPU is needed, and scheduling it on a GPU compute type wastes money.

## Example

```yaml
name: Swale pull example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      fetch_data:
        name: Fetch data
        uses: swaleio/swale-pull@1.0.0
        args:
          target: acme/datasets:v3
          dest: ${{env.WORKFLOW_STORAGE}}/data
          account: acme
          token: ${{secrets.swale_token}}
```

Downstream tasks read the pulled files from `${{env.WORKFLOW_STORAGE}}/data`.

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
