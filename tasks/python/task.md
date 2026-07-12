---
name: Python
description: Runs an arbitrary Python 3.13 script in the workspace. The escape hatch for anything without a dedicated task.
inputs:
  script:
    description: The Python program to run. Parameterize it by interpolating a trusted workflow expression into the program text, or by reading a run-level environment variable via os.environ inside it.
    required: true
exec:
  # ghcr.io/astral-sh/uv:python3.13-bookworm-slim
  image: ghcr.io/astral-sh/uv:python3.13-bookworm-slim@sha256:531f855bda2c73cd6ef67d56b733b357cea384185b3022bd09f05e002cd144ca
  args:
    - bash
    - -lc
    - 'printf %s "$INPUT_SCRIPT" > /tmp/run.py && exec python /tmp/run.py'
---

# Python

Writes your `script` to `/tmp/run.py` and runs it with `python` (CPU-only
Python 3.13), so tracebacks, multi-line programs, and standard-library imports
all behave exactly as they do in a normal interpreter.

This image ships [`uv`](https://docs.astral.sh/uv/) and `uvx`, so a script that
needs extra packages can pull them in a single shot without a build step — for
example `uv pip install --system httpx` at the top of the script, or invoke a
tool with `uvx`. This is a **CPU** task: there is no CUDA/GPU stack and no
`torch` — use a GPU-typed task for accelerated workloads.

## Parameterizing

This task declares only `script`, so there are no extra args to pass — the
example below passes `script` and nothing else. To feed a value into the
program, either:

- interpolate a **trusted** workflow expression — `${{ inputs.x }}` or
  `${{ tasks.x.outputs.y }}` — into the program text before it runs, or
- read a run-level environment variable inside the program (via `os.environ`,
  for example `os.environ["HOME"]`).

Never interpolate an **untrusted** value into the program text: it is executed
as Python, so an attacker-controlled expression could inject arbitrary code.
Keep untrusted data out of the program body.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `script` | yes | — | The Python program to run. Parameterize by interpolating a trusted workflow expression or reading a run-level env var via `os.environ`. |

## Emitting outputs

Append `key=value` lines to the file at `$WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks (declare them in a task that needs typed outputs;
this generic `python` task declares none, so emitting a key here would fail the
task — exchange results through files instead: write to the working directory,
or to a shared mount such as `/mnt/workspace` when a later task must read them).

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money; GPU workloads belong in the `transformers` task (the GPU Python lane).

## Example

The task declares only `script`, so the example passes only `script` and the
program is self-contained — it writes to a relative `out/` directory under the
working directory rather than assuming any particular mount.

```yaml
tasks:
  summarize:
    name: Summarize
    uses: swaleio/python@1-0-0
    args:
      script: |
        from pathlib import Path

        out = Path("out")
        out.mkdir(exist_ok=True)
        rows = [f"row {i}" for i in range(100)]
        (out / "data.txt").write_text("\n".join(rows))

        print(f"wrote {len(rows)} rows")
```
