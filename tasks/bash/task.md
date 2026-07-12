---
name: Bash
description: Runs an arbitrary Bash script in the workspace. The escape hatch for anything without a dedicated task.
inputs:
  script:
    description: The Bash script to run. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable inside it.
    required: true
exec:
  # docker.io/library/debian:13-slim
  image: docker.io/library/debian@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2
  args:
    - bash
    - -lc
    - 'printf %s "$INPUT_SCRIPT" > /tmp/run.sh && exec bash /tmp/run.sh'
---

# Bash

Writes your `script` to a file and executes it with `bash`, so shebangs,
`set -euo pipefail`, multi-line scripts, and error line numbers all behave
exactly as they do in a normal shell.

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money; GPU workloads belong in the `transformers` task (the GPU Python lane).

## Example

The task declares only `script`, so the example passes only `script` and the
script is self-contained — it writes to a relative `out/` directory under the
working directory rather than assuming any particular mount.

```yaml
tasks:
  build:
    name: Build
    uses: swaleio/bash@1-0-0
    args:
      script: |
        set -euo pipefail
        mkdir -p out
        echo "$(date -u) build ok" > out/build.log
        cat out/build.log
```

## Parameterizing

This task declares only `script`, so there are no extra args to pass — the
example passes `script` and nothing else. To feed a value into the script,
either:

- interpolate a **trusted** workflow expression — `${{ inputs.x }}` or
  `${{ tasks.x.outputs.y }}` — into the script text before it runs, or
- read a run-level environment variable inside the script (for example
  `"$HOME"`).

Never interpolate an **untrusted** value into the script text: it is executed
as shell, so an attacker-controlled expression could inject arbitrary commands.
Keep untrusted data out of the script body.

## Emitting outputs

Append `key=value` lines to the file at `$WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks (declare them in a task that needs typed outputs;
this generic `bash` task declares none).
