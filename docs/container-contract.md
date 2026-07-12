# Container contract

Every image referenced by a task definition runs under this contract. It applies
equally to vendor images (which must already satisfy it) and swale-built images
(which are built to satisfy it).

## Invocation

- The task definition's `exec.args` are passed as the container's **argv**,
  appended to the image's `ENTRYPOINT`. There is no command, working-directory,
  or environment override from the definition.
- Containers run **non-interactively** — no TTY. All configuration arrives as
  command-line arguments or environment variables.
- Containers should run as a **non-root** user where the image allows it.

## Inputs

- Every task input is injected as an environment variable `INPUT_<NAME>`, where
  `<NAME>` is the input identifier uppercased with `-` replaced by `_`
  (`repository_url` → `INPUT_REPOSITORY_URL`).
- The same values are also available for interpolation into `exec.args` as
  `${{inputs.<name>}}`.
- **Free-form (script) tasks** receive the user's program as `INPUT_SCRIPT`,
  write it to a file, and execute it — so values are referenced inside scripts
  via `$INPUT_*`, never substituted into the script text.

## Workspace

- A single per-run volume is mounted at **`/mnt/workspace`**, shared by every
  task in the run. This is how tasks exchange files: a producer writes to a path,
  a consumer reads it.
- File-producing tasks take a destination-path input and **must** use distinct
  subpaths, since the volume is shared across concurrent tasks.
- The workspace path is also available as `$WORKFLOW_STORAGE`.

## Outputs

- A task publishes an output by appending a `key=value` line to the file named by
  **`$WORKFLOW_TASK_OUTPUT`** (located under the per-task private state directory
  `/mnt/state`, not the shared workspace).
- Only keys declared in the task's `outputs` may be emitted — emitting an
  **undeclared** key fails the task. Missing a declared output does not.
- Values are one line each (the file is parsed line-by-line on the first `=`).
  Serialize multi-line data (e.g. `jq -c`) or write it to a workspace file and
  emit the path instead.
- Downstream tasks read outputs as `${{tasks.<task-id>.outputs.<key>}}`.

## Environment

- `WORKFLOW_TASK_OUTPUT` — path of the key=value output file.
- `WORKFLOW_ENV` — append `key=value` here to publish run-level environment
  variables to later tasks.
- `WORKFLOW_STORAGE` — the workspace path (`/mnt/workspace`).
- `WORKFLOW_TASK_ID` — this task's run id.

## Networking

- The public internet is reachable; DNS resolves.
- Private ranges (RFC 1918) and cloud metadata endpoints are blocked.

## Long-running "runner" tasks

- A task that other tasks terminate (via `terminate_on`) runs as a long-lived
  pod and exposes `${{tasks.<id>.ip-address}}` to consumers.
- The address is available once the pod is **running**, which is *before* the
  server inside is ready. Consumers must poll for readiness (e.g. retry against a
  health endpoint) and must list the runner in their own `start_on`.
