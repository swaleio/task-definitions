---
name: .NET 10
description: Runs an arbitrary shell script with the .NET 10 SDK available, for build, test, and publish flows.
inputs:
  script:
    description: The shell script to run. The dotnet CLI is on PATH. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable inside it.
    required: true
exec:
  # mcr.microsoft.com/dotnet/sdk:10.0
  image: mcr.microsoft.com/dotnet/sdk@sha256:2b1e13a22e46b55117f9cdb4b38e73172de08a30370166c8227d06cdaff82473
  args:
    - bash
    - -lc
    - 'cd "$WORKFLOW_TASK_STORAGE" && printf %s "$INPUT_SCRIPT" > /tmp/run.sh && exec bash /tmp/run.sh'
---

# .NET 10

Writes your `script` to a file and executes it with `bash` inside the
`mcr.microsoft.com/dotnet/sdk:10.0` image, so the full .NET SDK — `dotnet build`,
`dotnet test`, `dotnet publish`, `dotnet pack`, NuGet restore — is on `PATH`.
Shebangs, `set -euo pipefail`, multi-line scripts, and error line numbers all
behave exactly as they do in a normal shell.

To quiet the CLI, set `DOTNET_CLI_TELEMETRY_OPTOUT=1` and `DOTNET_NOLOGO=1`
in-script.

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
| `script` | yes | — | Shell script to run with the .NET SDK on `PATH`. Parameterize by interpolating a trusted workflow expression or reading a run-level env var. |

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money; GPU workloads belong in the `transformers` task (the GPU Python lane).

## Example

The task declares only `script`, so the example passes only `script` and the
script is self-contained — it scaffolds and builds under a relative `out/`
directory rather than assuming any particular mount. The task starts in its own scratch directory (`$WORKFLOW_TASK_STORAGE`), which is writable and discarded when the task ends.

```yaml
name: Dotnet 10 example
compute_type: cpu-4
entry_point: main

blocks:
  main:
    tasks:
      test:
        name: Build and test
        uses: swaleio/dotnet-10@1.0.0
        args:
          script: |
            set -euo pipefail
            export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
            dotnet new console -o out/app
            dotnet build out/app --configuration Release
```

## Emitting outputs

Append `key=value` lines to the file at `$WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks (declare them in a task that needs typed outputs;
this generic `dotnet-10` task declares none). Share build artifacts by writing them
somewhere a later task reads — the working directory for this task alone, or the
shared workspace (`$WORKFLOW_STORAGE` in the container) when another task must
pick them up.

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
