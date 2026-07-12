# swale-cli image

Swale-built image that provides the Swale client CLI (`swale`), backing the
`swale-pull` and `swale-push` task definitions.

- **Base:** `docker.io/library/debian:13-slim` (digest-pinned in the Dockerfile).
- **Built image ref:** `docker.io/swaleio/swale-cli:1-0-0`
  (`docker.io/swaleio/swale-cli@sha256:…`, real digest pinned by CI).
- **User:** non-root `swale` (uid 1000).
- **Workdir:** `/mnt/workspace` — the shared per-run workspace volume.
- **Entrypoint:** `entrypoint.sh`, which runs `exec swale "$@"`, so a task's
  `exec.args` become the `swale` argv (`["pull", ...]` / `["push", ...]`).

## Placeholder: the CLI install is NOT finalized

The Dockerfile does **not** yet install the `swale` binary. The install step is a
clearly-marked `TODO` placeholder because the CLI distribution method (vendored
release binary vs downloaded release vs package) has not been decided. Before this
image can build into a working artifact, replace the placeholder with the
finalized install that lands an executable at `/usr/local/bin/swale` and pins its
version plus checksum/digest. Until then the image builds without `swale` and
fails at runtime — that is intentional, and this image is not shippable as-is.

## Token handling

`entrypoint.sh` re-exports the task's `INPUT_TOKEN` (from the `token` input) as
`SWALE_TOKEN` for the CLI. The env var name `SWALE_TOKEN` is a **placeholder to
confirm** against the real CLI — update the entrypoint if the CLI expects a
different name.

## Contract

Runs under the standard container contract: non-root, no command/working-dir/env
override from the definition, shared `/mnt/workspace` (`$WORKFLOW_STORAGE`), and
outputs emitted by appending `key=value` to `$WORKFLOW_TASK_OUTPUT`. Every task
input arrives as an `INPUT_<NAME>` environment variable.
