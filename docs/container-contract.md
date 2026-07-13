# Container contract

Every image referenced by a task definition runs under this contract. It applies
equally to vendor images (which must already satisfy it) and swale-built images
(which are built to satisfy it).

## Invocation

- The task definition's `exec.args` are passed as the container's **argv**,
  appended to the image's `ENTRYPOINT`. There is no command or
  working-directory override from the definition; the definition may only add
  environment variables via `exec.env` (see Environment below).
- Containers run **non-interactively** — no TTY. All configuration arrives as
  command-line arguments or environment variables.
- Containers should run as a **non-root** user where the image allows it.

## Inputs

- Every task input is injected as an environment variable `INPUT_<NAME>`, where
  `<NAME>` is the input identifier uppercased with `-` replaced by `_`
  (`repository_url` → `INPUT_REPOSITORY_URL`).
- The same values are also available for interpolation into `exec.args` as
  `${{inputs.<name>}}`.
- **Free-form (script) tasks** declare only `script`, delivered as `INPUT_SCRIPT`,
  which the image writes to a file and executes. Such a task declares no other
  inputs, so there are no extra `$INPUT_*` values to read: parameterize the script
  by interpolating a **trusted** workflow expression (`${{…}}`) into it, or by
  reading a run-level environment variable — never by interpolating an untrusted
  value into the script text. (For fixed tasks, each declared input arrives as
  `$INPUT_*`, safe to read as data.)

## Workspace

- A single per-run volume is mounted at **`/mnt/workspace`**, shared by every
  task in the run. This is how tasks exchange files: a producer writes to a path,
  a consumer reads the same path in a later task.
- **Tasks must not hardcode `/mnt/workspace`.** A path a task reads or writes is
  a consumer-supplied input holding the **full** path — required when a
  downstream task consumes the result, so the consumer chooses where it lands.
  The consumer MAY point that path at the mounted workspace (e.g.
  `/mnt/workspace/repo`) to share it with later tasks, or at any other
  container-local path; the task must not force the workspace prefix.
- Because the volume is shared across concurrent tasks, consumers that write to
  the workspace **must** use distinct subpaths.
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

A definition may also declare its own environment variables under `exec.env` —
a map of UPPER_SNAKE names to values that may embed `${{inputs.*}}`
expressions, resolved before injection. These are injected at the **lowest**
precedence (`exec.env` < `INPUT_*` < run-level environment < the reserved
`WORKFLOW_*` variables above), and the reserved `WORKFLOW_`/`INPUT_` name
prefixes are protected. This is how catalog tasks deliver well-known variables
such as `HF_TOKEN` to the tools they wrap.

## Networking

- The public internet is reachable; DNS resolves.
- Private ranges (RFC 1918) and cloud metadata endpoints are blocked.
- **Within a run, every port of every task container is reachable by the run's
  other tasks** — there is nothing to declare or expose. Traffic from outside
  the run (including other runs) is blocked entirely. A runner listening on any
  port is therefore reachable at `${{tasks.<id>.ip-address}}:<port>` with no
  further configuration.

## Long-running "runner" tasks

- A task that other tasks terminate (via `terminate_on`) runs as a long-lived
  pod and exposes `${{tasks.<id>.ip-address}}` to consumers.
- The address is available once the pod is **running**, which is *before* the
  server inside is ready. Consumers must poll for readiness (e.g. retry against a
  health endpoint) and must list the runner in their own `start_on`.
