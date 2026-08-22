---
name: PowerShell
description: Runs an arbitrary PowerShell (pwsh) script. The escape hatch for anything without a task.
inputs:
  script:
    description: The PowerShell script to run. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable via $env inside it.
    required: true
exec:
  # mcr.microsoft.com/dotnet/sdk:10.0
  image: mcr.microsoft.com/dotnet/sdk@sha256:ea8bde36c11b6e7eec2656d0e59101d4462f6bd630730f2c8201ed0572b295d5
  args:
    - pwsh
    - -NoLogo
    - -NonInteractive
    - -Command
    - '$s=$env:INPUT_SCRIPT; Set-Content -Path /tmp/run.ps1 -Value $s; pwsh -File /tmp/run.ps1'
---

# PowerShell

Writes your `script` to `/tmp/run.ps1` and executes it with `pwsh`, so
`$ErrorActionPreference`, multi-line pipelines, functions, and error records all
behave exactly as they do in a normal PowerShell session. Runs on the
cross-platform PowerShell that ships in the `mcr.microsoft.com/dotnet/sdk:10.0`
base image, non-interactively (`-NonInteractive`, no TTY).

## Parameterizing

This task declares only `script`, so there are no extra args to pass — the
example below passes `script` and nothing else. To feed a value into the script,
either:

- interpolate a **trusted** workflow expression — `${{ inputs.x }}` or
  `${{ tasks.x.outputs.y }}` — into the script text before it runs, or
- read a run-level environment variable inside the script (for example
  `$env:HOME`).

Never interpolate an **untrusted** value into the script text: it is executed
as PowerShell, so an attacker-controlled expression could inject arbitrary
commands. Keep untrusted data out of the script body.

## Telemetry

PowerShell honors `POWERSHELL_TELEMETRY_OPTOUT` to disable its usage telemetry.
Because a task definition cannot set container environment (the `exec` block is
`{ image, args }` only), opt out from inside your script when you want it —
`$env:POWERSHELL_TELEMETRY_OPTOUT = '1'` at the top has no effect on the already
started host, so set it for child `pwsh`/tooling you launch, or rely on the
Swale runtime which sets it in the execution environment.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `script` | yes | — | The PowerShell script to run. Parameterize by interpolating a trusted workflow expression or reading a run-level env var via `$env`. |

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money; GPU workloads belong in the `transformers` task (the GPU Python lane).

## Example

The task declares only `script`, so the example passes only `script` and the
script is self-contained — it writes to a relative `out/` directory under the
working directory rather than assuming any particular mount.

```yaml
tasks:
  report:
    name: Report
    uses: swaleio/powershell@1-0-0
    args:
      script: |
        $ErrorActionPreference = 'Stop'
        New-Item -ItemType Directory -Force -Path out | Out-Null
        $count = (Get-ChildItem -Recurse -File | Measure-Object).Count
        "file count: $count" | Set-Content out/report.txt
        Get-Content out/report.txt
```

## Emitting outputs

Append `key=value` lines to the file at `$env:WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks (declare them in a task that needs typed outputs;
this generic `powershell` task declares none).
