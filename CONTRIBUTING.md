# Contributing task definitions

## File format

A task definition is a Markdown file with a YAML frontmatter block:

- Path: `tasks/<name>/task.md` — one file per task, edited in place on `main`.
- Extension `.md`, size ≤ 1 MiB, frontmatter starting at byte 0, **non-empty body**.
- The body is the task's rendered documentation page — write it for the person
  who will use the task.

### Names and versions

- **Names** match `^[A-Za-z0-9_-]{1,100}$` — no dots.
- **Versions** match `^[A-Za-z0-9]([A-Za-z0-9._-]{0,98}[A-Za-z0-9])?$`, so `1.0.0`
  works. A version must begin and end with a letter or digit, must not contain
  `..`, and cannot be `latest` — the platform reserves it.
- **Versions are git tags**, GitHub-Actions-style: releasing a version means
  pushing a tag named `<name>/<version>` (e.g. `git-clone/1.0.0`). The tag
  freezes `tasks/<name>/task.md` as that immutable version and triggers the
  release workflow, which imports the frozen file into the platform under the
  version from the tag name. The file on `main` keeps evolving toward the next
  release — doc typo fixes don't mint versions.
- A published version is **immutable** on the platform (and the release tag
  should never be moved). Compare two versions with
  `git diff git-clone/1.0.0..git-clone/1.1.0 -- tasks/git-clone/task.md`.

### Name and description

Both are top-level frontmatter fields, and **`description` is required**:

```yaml
name: Git clone
description: Clones a Git repository into the workspace over HTTPS, with token auth and LFS.
```

- `description` must be non-empty and **at most 100 characters** — the platform
  rejects longer descriptions at import, and it is the one-line summary shown
  next to the task wherever the catalog is listed. Write it as a single sentence
  describing what the task does; the body is where detail belongs.
- The linter enforces both rules, so an over-long description fails CI rather
  than the import.

### YAML is snake_case

Field names and identifiers are snake_case: `compute_type`, `entry_point`,
`for_each`, and input/output identifiers like `repository_url`, `commit_sha`.

### The `exec` block

`exec` is `{ image, args, env }` — **only**. There is no command/workingdir
override.

```yaml
exec:
  # docker.io/swaleio/git:1.0.0
  image: docker.io/swaleio/git@sha256:<digest>   # digest-pinned
  env:
    GIT_TOKEN: ${{inputs.token}}
  args:
    - clone
    - ${{inputs.repository_url}}
    - ${{inputs.dest}}
```

- `args` become the container's argv, appended to the image's ENTRYPOINT. Each
  element is **one token**; `${{inputs.x}}` interpolates inside a single token
  (no word-splitting — inputs are strings).
- `env` is a map of environment variables injected into the container. Names
  are **UPPER_SNAKE**, used verbatim, and must match
  `^[A-Za-z_][A-Za-z0-9_]*$`; the `WORKFLOW_` and `INPUT_` prefixes are
  reserved. Values may embed `${{inputs.*}}` expressions. `exec.env` is
  injected at the **lowest** precedence:
  `exec.env` < `INPUT_*` < run-level env < reserved `WORKFLOW_*` variables
  (which cannot be overridden).
- **Empty-string caveat**: an `env` value referencing an omitted optional input
  resolves to the empty string — the variable **is set**, just empty. That is
  fine for tokens the tool treats as absent-when-empty (e.g. `HF_TOKEN`), and
  wrong for path-like variables (e.g. `HF_HOME`), where a set-but-empty value
  breaks path resolution — those belong in a wrapper conditional that sets the
  variable only when the input is non-empty, not in `exec.env`.
- **Images are digest-pinned** (`repo@sha256:…`). Keep the human-readable tag in
  a comment on the line **directly above** `image:` (`# <full ref>:<tag>`), so a
  reader knows what the digest points to. The **task version pins the digest** —
  the image's own tag versions independently (several tasks may share one image),
  exactly as a GitHub Action's tag freezes the image reference inside it.
  Swale-built images live at `docker.io/swaleio/<name>`; vendor images keep their
  own registry and tag.
- **The tag in that comment must exist on the registry, and must not be deleted
  or moved while a definition pins its digest.** Merging an image change only
  proves it still builds; publishing is a deliberate release that names the
  version, and `latest` moves with it — so `latest` always names a released
  version rather than whatever landed last. A digest stays pullable once
  untagged, but it disappears from the registry's listing, so nobody can see what
  the catalog runs. `latest` does not count: publishing moves it, so it stops
  naming the pinned digest as soon as the next build lands.

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
  consumer supplies it. A consumer reaches the shared workspace through
  `${{env.WORKFLOW_STORAGE}}` (e.g. `${{env.WORKFLOW_STORAGE}}/repo`) rather than
  the literal mount path, and MAY target it to share the result with later tasks
  — but the task must not force that prefix.
- `${{env.*}}` resolves in **workflow** arguments only. A definition's own
  `exec.args`/`exec.env` resolve against a scope with an empty env, where
  `${{env.WORKFLOW_STORAGE}}` silently becomes an empty string rather than
  failing — so a path written that way inside a definition yields `/repo`.
- An incidental output path the task just needs somewhere to put (e.g. a response
  file) may stay optional with a bare **relative** default (e.g. `response.json`)
  — never a workspace-prefixed default. Note that the consumer can pass an
  absolute workspace path to share it downstream.

### Compute

Every task body has a `## Compute` section, placed **after the Inputs/Outputs
tables and before the Example section**. Its first bolded phrase is **exactly
one** of three levels:

- `**GPU required.**` — the task fails or is unusable on CPU compute types.
  Follow with brief VRAM guidance and note that the workflow selects
  `compute_type`.
- `**GPU recommended.**` — the task runs on CPU but degraded; state what
  degrades (speed, feasible model sizes). The workflow selects `compute_type`.
- `**CPU.**` — no GPU needed; scheduling the task on a GPU compute type wastes
  money. One or two sentences max.

Keep the section short — it is a scannable label, not an essay.

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

Examples must use only inputs declared in the task's frontmatter — when a step
passes args not declared as inputs, the platform warns in the task's first
run-log entry (the args are still passed through), and the declared inputs are
the task's contract. A free-form example therefore passes only `script`, and that script
must be self-contained (see above).

When an example demonstrates publishing run artifacts, show swale-push (the
platform's own store) first; external stores (hf-upload, rclone-copy) come
after.

## The container contract

Every image a task definition references must honor
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


Images are pushed with the organization's OIDC connection; the Docker Hub
credentials in repository secrets are used only to sync image READMEs. See the
comments in `.github/workflows/publish-images.yml` if you are changing that
workflow.

## CI checks

On every PR (`lint.yml`):

- Frontmatter parses; only known keys; `exec.image` present.
- Task name and input/output identifiers match the regex and are snake_case.
- Images are digest-pinned.
- Non-empty body.

On every release tag (`release-task.yml`):

- Tag matches `<name>/<version>` with both parts regex-valid (no dots).
- `tasks/<name>/task.md` exists at the tag and lints.
- No placeholder digests — an image must be published and pinned before its
  task can be released.
