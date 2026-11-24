---
name: Node.js 22
description: Runs an arbitrary shell script with Node.js 22, npm, npx, and corepack available.
inputs:
  script:
    description: The shell script to run. node, npm, and npx are on PATH. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable inside it.
    required: true
exec:
  # docker.io/library/node:22.23.5-trixie-slim
  image: docker.io/library/node@sha256:f0960f8dc047f358e3fb428f36ccba21732194fa5f0cac849f401e63e62fb9e6
  args:
    - bash
    - -lc
    - 'cd "$WORKFLOW_TASK_STORAGE" && printf %s "$INPUT_SCRIPT" > /tmp/run.sh && exec bash /tmp/run.sh'
---

# Node.js 22

Writes your `script` to a file and executes it with `bash` on the
`node:22-trixie-slim` image, so `node`, `npm`, and `npx` are on `PATH` and you
can run JavaScript/TypeScript build tooling — installs, builds, tests, bundlers,
and codegen. `script` is a **shell** script (not raw JavaScript): call the Node
toolchain from it the way you would in a terminal.

`corepack` is bundled, so `pnpm` and `yarn` are available too. Call them
through it — `corepack pnpm install` — rather than running `corepack enable`,
which writes its shims into the image's read-only `/usr/local/bin` and fails.

## Parameterizing

This task declares only `script`, so there are no extra args to pass — the
example below passes `script` and nothing else. To feed a value into the script,
either:

- interpolate a **trusted** workflow expression — `${{ inputs.x }}` or
  `${{ tasks.x.outputs.y }}` — into the script text before it runs, or
- read a run-level environment variable inside the script (for example
  `"$HOME"`).

Never interpolate an **untrusted** value into the script text: it is executed
as shell, so an attacker-controlled expression could inject arbitrary commands.
Keep untrusted data out of the script body.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `script` | yes | — | Shell script to run with `node`/`npm`/`npx` (and `corepack`) on `PATH`. Parameterize by interpolating a trusted workflow expression or reading a run-level env var. |

## Emitting outputs

Append `key=value` lines to the file at `$WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks (declare them in a task that needs typed outputs;
this generic `node-22` task declares none).

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money; GPU workloads belong in the `transformers` task (the GPU Python lane).

## Example

The task declares only `script`, so the example passes only `script` and the
script is self-contained — it works in a relative `out/` directory under the
working directory rather than assuming any particular mount. The task starts in its own scratch directory (`$WORKFLOW_TASK_STORAGE`), which is writable and discarded when the task ends.

```yaml
name: Node.js 22 example
compute_type: cpu-4
entry_point: main

blocks:
  main:
    tasks:
      build:
        name: Build web app
        uses: swaleio/node-22
        args:
          script: |
            set -euo pipefail
            mkdir -p out
            cd out
            npm init -y
            node -e "require('fs').writeFileSync('hello.txt', 'built with node ' + process.version)"
            cat hello.txt
```

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
