# Contributing task definitions

## File format

A task definition is a Markdown file with a YAML frontmatter block:

- Path: `tasks/<name>/<version>.md` — e.g. `tasks/git-clone/1-0-0.md`.
- Extension `.md`, size ≤ 1 MiB, frontmatter starting at byte 0, **non-empty body**.
- The body is the task's rendered documentation page — write it for the person
  who will use the task.

### Names and versions

- Both match `^[A-Za-z0-9_-]{1,100}$`. **No dots** — use `1-0-0`, not `1.0.0`.
- A task **version is immutable** once published. Any change (including a rebuilt
  image) is a new `<version>.md` file, never an edit to an existing one.

### YAML is snake_case

Field names and identifiers are snake_case: `compute_type`, `entry_point`,
`for_each`, and input/output identifiers like `repository_url`, `commit_sha`.

### The `exec` block

`exec` is `{ image, args }` — **only**. There is no command/workingdir/env
override.

```yaml
exec:
  # docker.io/swaleio/git:1-0-0 (image version matches this task version)
  image: docker.io/swaleio/git@sha256:<digest>   # digest-pinned
  args:
    - clone
    - ${{inputs.repository_url}}
    - ${{inputs.dest}}
```

- `args` become the container's argv, appended to the image's ENTRYPOINT. Each
  element is **one token**; `${{inputs.x}}` interpolates inside a single token
  (no word-splitting — inputs are strings).
- **Images are digest-pinned** (`repo@sha256:…`). Keep the human-readable tag in
  a comment on the line **directly above** `image:`. For a swale-built image the
  tag version must equal this task's version — write it as
  `# docker.io/swaleio/<name>:1-0-0 (image version matches this task version)`.
  Swale-built images live at `docker.io/swaleio/<name>`; vendor images keep their
  own registry and tag (`# <full ref>:<tag>`).

### Inputs and outputs

```yaml
inputs:
  repository_url:
    description: HTTPS URL of the repository to clone.
    required: true
  dest:
    description: >-
      Absolute path inside the container. Point it at the mounted workspace
      (e.g. /mnt/workspace/repo) to share the result with later tasks, or any
      other container-local path.
    required: true
outputs:
  commit_sha:
    description: The resolved HEAD commit SHA.
```

Inputs are strings. A task emits a declared output by appending `key=value` to
the file at `$WORKFLOW_TASK_OUTPUT` (see the container contract). Emitting an
**undeclared** key fails the task.

### Paths

- **Never hardcode `/mnt/workspace`** — not in `exec.args`, not in an input
  default, not in an image entrypoint. A filesystem path a task reads or writes
  is a consumer-supplied input holding the **full** path.
- A path whose result a downstream task consumes (a clone destination, a download
  directory, an upload source) is a **required** input with no default — the
  consumer supplies it. The platform mounts the shared workspace at
  `/mnt/workspace`, which the consumer MAY target (e.g. `/mnt/workspace/repo`) to
  share the result with later tasks, but the task must not force that prefix.
- An incidental output path the task just needs somewhere to put (e.g. a response
  file) may stay optional with a bare **relative** default (e.g. `response.json`)
  — never a `/mnt/workspace`-prefixed default. Note that the consumer can pass an
  absolute workspace path to share it downstream.

## The two task forms

- **Fixed** — one bounded operation; the user supplies typed inputs that fill
  fixed argv placeholders. The default. Safe, discoverable, composable. Each
  declared input also arrives in the container as `$INPUT_*`, safe to read as
  data.
- **Free-form** — a per-runtime escape hatch (`bash`, `powershell`, `python`, …)
  that takes a single multiline `script` input, writes it to a file, and executes
  it. A free-form task declares **only** `script` (and no outputs), so there are
  no extra `$INPUT_*` values. Parameterize it by interpolating a **trusted**
  workflow expression (`${{inputs.x}}`, `${{tasks.x.outputs.y}}`) into the script,
  or by reading a run-level environment variable — never interpolate an untrusted
  value into the script text.

### Workflow examples in the body

Examples must use only inputs declared in the task's frontmatter — the platform
does not currently reject undeclared args, but the declared inputs are the task's
contract. A free-form example therefore passes only `script`, and that script
must be self-contained (see above).

## The container contract

Every image an image references must honor
[`docs/container-contract.md`](docs/container-contract.md): the `INPUT_*` env
convention, the `/mnt/workspace` shared volume, the `$WORKFLOW_TASK_OUTPUT`
key=value output file, and non-interactive (no-TTY) operation.

## Swale-built images

If no trusted vendor image fits (wrong entrypoint, missing tooling, or an output
needs to be emitted), add one under `images/<name>/`:

```
images/<name>/Dockerfile     # FROM a digest-pinned trusted base; non-root; workdir /mnt/workspace
images/<name>/entrypoint.sh  # runs the tool, emits declared outputs to $WORKFLOW_TASK_OUTPUT
images/<name>/README.md      # synced to the Docker Hub page by CI
```

Publish CI builds changed images, pushes `docker.io/swaleio/<name>`, attests
build provenance, and syncs the image README to Docker Hub.

## CI checks (run on every PR)

- Frontmatter parses; only known keys; `exec.image` present.
- `name`/`version`/identifiers match the regex and are snake_case.
- Images are digest-pinned.
- Non-empty body.
