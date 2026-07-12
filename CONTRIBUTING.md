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
  image: docker.io/swaleio/git@sha256:<digest>   # digest-pinned; tag in a comment above
  args:
    - clone
    - ${{inputs.repository_url}}
    - /mnt/workspace/${{inputs.dest}}
```

- `args` become the container's argv, appended to the image's ENTRYPOINT. Each
  element is **one token**; `${{inputs.x}}` interpolates inside a single token
  (no word-splitting — inputs are strings).
- **Images are digest-pinned** (`repo@sha256:…`). Keep the human-readable tag in
  a comment on the line above. Swale-built images live at
  `docker.io/swaleio/<name>`; vendor images stay on their own registries.

### Inputs and outputs

```yaml
inputs:
  repository_url:
    description: HTTPS URL of the repository to clone.
    required: true
  dest:
    description: Destination directory, relative to the workspace root.
    default: repo
outputs:
  commit_sha:
    description: The resolved HEAD commit SHA.
```

Inputs are strings. A task emits a declared output by appending `key=value` to
the file at `$WORKFLOW_TASK_OUTPUT` (see the container contract). Emitting an
**undeclared** key fails the task.

## The two task forms

- **Fixed** — one bounded operation; the user supplies typed inputs that fill
  fixed argv placeholders. The default. Safe, discoverable, composable.
- **Free-form** — a per-runtime escape hatch (`bash`, `powershell`, `python`, …)
  that takes a multiline `script` input, writes it to a file, and executes it.
  Reference values inside the script via `$INPUT_*` environment variables —
  never paste `${{…}}` into the script body.

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
