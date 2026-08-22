# Swale task definitions

The catalog of **task definitions** for [Swale](https://swale.io) workflows — the
reusable building blocks a workflow chains together to move data, build code,
fine-tune models, run inference, and more.

Each task is a Markdown file with YAML frontmatter. Swale imports it and renders
the Markdown body as the task's documentation page. Tasks run as containers on
Swale's compute; some reference public vendor images, others reference images
built from this repo and published to Docker Hub under
[`docker.io/swaleio`](https://hub.docker.com/u/swaleio).

## Using a task in a workflow

Reference a task by `account/name@version`:

```yaml
name: Checkout example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      checkout:
        name: Checkout
        uses: swaleio/git-clone@1-0-0
        args:
          repository_url: https://github.com/acme/app.git
          dest: ${{env.WORKFLOW_STORAGE}}/repo
```

`name`, `compute_type`, `entry_point` and `blocks` are all required; tasks live
inside a block, and `entry_point` names the block execution starts from. Compute
type names come from what your project has available — `cpu` and `gpu` are the
documented defaults.

## Repository layout

```
tasks/<name>/task.md           # one file per task; versions are git tags '<name>/<version>'
images/<name>/                 # Dockerfile + entrypoint + README for swale-built images
docs/container-contract.md     # the runtime contract every image must honor
.github/workflows/             # lint (PRs) + release (tags) + publish images (main)
```

A task version is released by pushing a tag `<name>/<version>` (e.g.
`git-clone/1-0-0`), which freezes `tasks/<name>/task.md` as that immutable
version and imports it into the platform.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the authoring rules, the two task
forms (fixed vs free-form), and the container contract. CI enforces the schema,
digest-pinning, and naming on every pull request.
