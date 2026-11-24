---
name: Python 3.15
description: Runs an arbitrary Python 3.15 script. The escape hatch for anything without a dedicated task.
inputs:
  script:
    description: The Python program to run. Parameterize it by interpolating a trusted workflow expression into the program text, or by reading a run-level environment variable via os.environ inside it.
    required: true
exec:
  # docker.io/library/python:3.15.2-slim-trixie
  image: docker.io/library/python@sha256:1c670c3568107e243bfd05457ad9ca0b11c35a855c985af73e4452db9a714e70
  args:
    - bash
    - -lc
    - 'cd "$WORKFLOW_TASK_STORAGE" && printf %s "$INPUT_SCRIPT" > /tmp/run.py && exec python /tmp/run.py'
---

# Python 3.15

Writes your `script` to `/tmp/run.py` and runs it with `python` (CPU-only
Python 3.15), so tracebacks, multi-line programs, and standard-library imports
all behave exactly as they do in a normal interpreter.

It runs on the official Python image, whose own packages are read-only. A
script that needs a package the image lacks installs it with `pip` into a
writable directory and puts that directory on `sys.path` before importing it:

```python
import subprocess, sys

subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "--target", "/tmp/deps", "httpx"], check=True)
sys.path.insert(0, "/tmp/deps")
import httpx
```

`pip install --user` does not work inside one script: Python adds the user
package directory to `sys.path` only if it exists when the interpreter starts.
This is a **CPU** task: there is no CUDA/GPU stack and no `torch` — use a
GPU-typed task for accelerated workloads.

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
this generic `python-3-15` task declares none, so emitting a key here would fail the
task — exchange results through files instead: write to the working directory,
or to the shared workspace (`$WORKFLOW_STORAGE` in the container) when a later task must read them).

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money; GPU workloads belong in the `transformers` task (the GPU Python lane).

## Example

The task declares only `script`, so the example passes only `script` and the
program is self-contained — it writes to a relative `out/` directory under the
working directory rather than assuming any particular mount. The task starts in its own scratch directory (`$WORKFLOW_TASK_STORAGE`), which is writable and discarded when the task ends.

```yaml
name: Python 3.15 example
compute_type: cpu-4
entry_point: main

blocks:
  main:
    tasks:
      summarize:
        name: Summarize
        uses: swaleio/python-3-15
        args:
          script: |
            from pathlib import Path

            out = Path("out")
            out.mkdir(exist_ok=True)
            rows = [f"row {i}" for i in range(100)]
            (out / "data.txt").write_text("\n".join(rows))

            print(f"wrote {len(rows)} rows")
```

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
