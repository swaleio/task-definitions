---
name: Node
description: Runs an arbitrary shell script with Node.js, npm, npx, and corepack available.
inputs:
  script:
    description: The shell script to run. node, npm, and npx are on PATH. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable inside it.
    required: true
exec:
  # docker.io/library/node:24-trixie-slim
  image: docker.io/library/node@sha256:366fdef91728b1b7fa18c84fba63b6e79ed77b7e10cc206878e9705da4d7b169
  args:
    - bash
    - -lc
    - 'printf %s "$INPUT_SCRIPT" > /tmp/run.sh && exec bash /tmp/run.sh'
---

# Node

Writes your `script` to a file and executes it with `bash` on the
`node:24-trixie-slim` image, so `node`, `npm`, and `npx` are on `PATH` and you
can run JavaScript/TypeScript build tooling — installs, builds, tests, bundlers,
and codegen. `script` is a **shell** script (not raw JavaScript): call the Node
toolchain from it the way you would in a terminal.

`corepack` is bundled, so `pnpm` and `yarn` are available too — enable the one
your project uses with `corepack enable` (or `corepack prepare`) at the top of
your script.

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
this generic `node` task declares none).

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money; GPU workloads belong in the `transformers` task (the GPU Python lane).

## Example

The task declares only `script`, so the example passes only `script` and the
script is self-contained — it works in a relative `out/` directory under the
working directory rather than assuming any particular mount.

```yaml
name: Node example
compute_type: cpu
entry_point: main

blocks:
  main:
    tasks:
      build:
        name: Build web app
        uses: swaleio/node@1-0-0
        args:
          script: |
            set -euo pipefail
            corepack enable
            mkdir -p out
            cd out
            npm init -y
            node -e "require('fs').writeFileSync('hello.txt', 'built with node ' + process.version)"
            cat hello.txt
```

---

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
