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
- **Push one release tag per `git push`.** GitHub starts no workflow for a
  push of more than three tags, so pushing several release tags together
  releases none of them:

  ```sh
  for tag in git-clone/1.0.0 node-24/1.0.0; do git tag "$tag" && git push origin "$tag"; done
  ```
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
  while a definition pins its digest.** A digest stays pullable once untagged,
  but it disappears from the registry's listing, so nobody can see what the
  catalog runs. A swale-built image never reuses a tag, so its tags never move.
  `latest` does not count: each publish moves it, so it stops naming the pinned
  digest as soon as the next build lands.

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
- **Free-form** — a per-runtime escape hatch (`bash`, `powershell-7-6`,
  `python-3-13`, …) that takes a single multiline `script` input, writes it to a file, and
  executes it. A free-form task declares **only** `script` (and no outputs), so
  there are no extra `$INPUT_*` values. Parameterize it by interpolating a
  **trusted** workflow expression (`${{inputs.x}}`, `${{tasks.x.outputs.y}}`) into
  the script, or by reading a run-level environment variable — never interpolate
  an untrusted value into the script text.
- A free-form wrapper **starts in `$WORKFLOW_TASK_STORAGE`** before running the
  script. A vendor image usually sets no working directory, which leaves the
  script in `/` — read-only on the platform — so a relative path such as `out/`
  would fail. The task's scratch is writable, private, and discarded afterwards.
- A tool that ignores `$HOME` has to be pointed at it in the wrapper. The JVM
  takes its home from the image's account entry, so the `java-maven-*` wrappers
  set `-Duser.home=$HOME` through `MAVEN_OPTS`.
- A wrapper whose toolchain lives outside `/usr/local/bin` and `/usr/bin` runs
  `bash -c`, not `bash -lc`. A login shell reads Debian's `/etc/profile`, which
  replaces `PATH` for a non-root user and drops the image's own entries — that
  is why `go` and `rust` cannot find `/usr/local/go/bin` or `/usr/local/cargo/bin`
  under `-l`.

### Runtime lines

A language runtime with several supported versions gets **one definition per
release line**, named `<runtime>-<line>`: `node-24`, `python-3-13`, `dotnet-10`,
`java-maven-21`. Names cannot contain dots, so a line's dots become hyphens.

- **The line follows the ecosystem's own compatibility boundary**: the major
  version for Node.js, .NET, and Java, and the minor version for Python and
  PowerShell. Node.js and Java ship only their LTS lines — their other releases
  are supported for six to eight months, too short to be worth a definition —
  while .NET and PowerShell give every release at least two years.
- **Go and Rust have one line each**, `go` and `rust`, following the newest
  release. Both promise backward compatibility across all of 1.x, so their
  compatibility boundary is the major version, and there is only one.
- **Ship every line its upstream still supports.** Add a definition when a line
  is released; stop releasing one when its line reaches end of life. Versions
  already published stay usable, so nobody's pinned workflow breaks.
- **One definition never spans lines.** A definition version pins one image
  digest, and `uses:` without a version resolves to the most recently
  *published* version, not the highest — so putting several lines behind one
  name would let a refresh of an old line become everyone's default.
- **The definition's own version describes the definition**, not the runtime:
  a patch refreshes the image digest within the line, a minor adds an optional
  input, a major breaks the interface.

[Renovate](renovate.json) opens a weekly pull request moving each definition's
digest to whatever its tag now names. It never moves a definition to another
tag — a new line is a new definition, added by hand. Merging that pull request
changes `main`; each changed definition still needs a release tag to publish
the refreshed version.

### Workflow examples in the body

Examples must use only inputs declared in the task's frontmatter — when a step
passes args not declared as inputs, the platform warns in the task's first
run-log entry (the args are still passed through), and the declared inputs are
the task's contract. A free-form example therefore passes only `script`, and that script
must be self-contained (see above).

Examples name compute types the platform offers — the documentation lists them
under [Compute types](https://docs.swale.io/explanation/core-concepts#compute-types).
Lint does not parse the examples, so nothing in this repository catches a name
the platform does not offer. Use `cpu-4` as the workflow default, and give a
task that runs on a GPU the smallest GPU compute type whose VRAM fits the model
the example loads. Where an example mixes hardware, put that type on the task
as a per-task `compute_type`, so the steps around it stay on the default.

When an example demonstrates publishing run artifacts, show swale-push (the
platform's own store) first; external stores (hf-upload, rclone-copy) come
after.

## The container contract

Every image a task definition references must honor
[`docs/container-contract.md`](docs/container-contract.md): the `INPUT_*` env
convention, the `/mnt/workspace` shared volume, the `$WORKFLOW_TASK_OUTPUT`
key=value output file, and non-interactive (no-TTY) operation.

## Swale-built images

If no trusted vendor image fits (wrong entrypoint, missing tooling, an output
that needs to be emitted, or a tag that does not name the tool's version), add
one under `images/<name>/`:

```
images/<name>/Dockerfile        # FROM <base>:<tag>@sha256:<digest>; non-root; workdir /mnt/workspace
images/<name>/entrypoint.sh     # runs the tool, emits declared outputs to $WORKFLOW_TASK_OUTPUT
images/<name>/requirements.txt  # the pinned Python packages, when the image installs any
images/<name>/README.md         # synced to the Docker Hub page by CI
```

- **An image records the version of the tool it is built around**, read from
  the tool itself, in `/usr/share/swale-image-version`. Publishing tags the
  image with that version, adding `-r1`, `-r2`, and so on when it is already
  published: a rebuilt base or a wrapper fix keeps the tool's version. A tag is
  never reused; `latest` follows the newest publish.
- **Everything a build installs is pinned where Renovate can see it:** the base
  as `<image>:<tag>@sha256:<digest>`, Python packages in `requirements.txt`, and
  any other version in an `ARG` under a `# renovate: datasource=… depName=…`
  comment. Packages from the base distribution's own repositories stay unpinned
  and arrive with the base's digest refreshes.
- **Merging a change under `images/<name>` publishes the image.** Publish CI
  builds each image the change touched, picks its tag, pushes
  `docker.io/swaleio/<name>`, attests build provenance, and then syncs the
  README to Docker Hub, so an image's first publish also gives it its page. A
  pull request builds the same images and reports the tag each would get.
- **Renovate keeps bases and pins current.** A rebuilt base or a patch release
  merges itself once the image builds; a minor or major release waits for
  review. A distribution base (`debian`, `ubuntu`, `alpine`, `python`) moves to
  a new release by hand.
- To republish an image unchanged, dispatch "Publish images" with **publish**
  ticked. Unticked, it only syncs the selected images' READMEs.

Images are pushed with a Docker Hub organization access token; a second, personal
credential exists only to sync image READMEs, because Docker Hub's management
API rejects organization tokens. See the comments in
`.github/workflows/publish-images.yml` if you are changing that workflow.

### Labels

`title`, `description` and `licenses` are read back out of the Dockerfile by CI
and handed to `metadata-action`, because a build `--label` overrides a
Dockerfile `LABEL` and the repository's own values would otherwise win. A
missing one fails the build.

`licenses` names the license of **the software the image exists to provide**, as
an SPDX expression — not this repository's license, and not an audit of every
package in the base. This repository is MIT; the software in the images mostly
is not. Two tools in one image is `A AND B` (`curl AND MIT`). Take it from
upstream's own `COPYING`/`LICENSE` or, for a Python package, from PyPI — not
from whichever image it was copied from.

## CI checks

On every PR (`lint.yml`):

- Frontmatter parses; only known keys; `exec.image` present.
- Task name and input/output identifiers match the regex and are snake_case.
- Images are digest-pinned.
- Non-empty body.

On every PR that touches `images/` (`publish-images.yml`):

- Each image the PR touches builds, and the run reports the tag it would
  publish under.

On every release tag (`release-task.yml`):

- Tag matches `<name>/<version>` with both parts regex-valid (no dots).
- `tasks/<name>/task.md` exists at the tag and lints.
- No placeholder digests — an image must be published and pinned before its
  task can be released.
