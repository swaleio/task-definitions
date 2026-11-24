---
name: Go
description: Runs an arbitrary shell script with the current Go toolchain available.
inputs:
  script:
    description: The shell script to run. go is on PATH. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable inside it.
    required: true
exec:
  # docker.io/library/golang:1.27.4-trixie
  image: docker.io/library/golang@sha256:c393c00864b56f4404b3fe4d029e47742fbb53ee11506521d2f3377009ad7a3a
  args:
    - bash
    - -c
    - 'cd "$WORKFLOW_TASK_STORAGE" && export GOPATH="$HOME/go" && printf %s "$INPUT_SCRIPT" > /tmp/run.sh && exec bash /tmp/run.sh'
---

# Go

Writes your `script` to a file and executes it with `bash` on the
`golang:1-trixie` image, so the `go` toolchain is on `PATH` for builds, tests,
`go vet`, and code generation. `script` is a **shell** script (not Go source):
call the toolchain from it the way you would in a terminal.

This task follows the newest Go release rather than offering one definition per
Go version. Go promises backward compatibility across Go 1, and a module's
`go.mod` declares the language version its code is built with, so the newest
toolchain builds older modules faithfully. A module whose `go.mod` asks for a
**newer** Go than this task carries fails instead of downloading one — the image
sets `GOTOOLCHAIN=local` — so pin an older version of this task only to hold a
build still, not to reach a newer Go.

The image keeps `GOPATH` at `/go`, which is read-only on the platform, so the
task moves it to `$HOME/go`: the module cache and `go install`ed binaries land
in the writable home directory. The build cache already lives there.

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
| `script` | yes | — | Shell script to run with `go` on `PATH`. Parameterize by interpolating a trusted workflow expression or reading a run-level env var. |

## Emitting outputs

Append `key=value` lines to the file at `$WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks (declare them in a task that needs typed outputs;
this generic `go` task declares none). Share build artifacts by writing them
somewhere a later task reads — the working directory for this task alone, or the
shared workspace (`$WORKFLOW_STORAGE` in the container) when another task must
pick them up.

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money.

## Example

The task declares only `script`, so the example passes only `script` and the
script is self-contained — it works in a relative `out/` directory under the
working directory rather than assuming any particular mount. The task starts in
its own scratch directory (`$WORKFLOW_TASK_STORAGE`), which is writable and
discarded when the task ends.

```yaml
name: Go example
compute_type: cpu-4
entry_point: main

blocks:
  main:
    tasks:
      build:
        name: Build service
        uses: swaleio/go
        args:
          script: |
            set -euo pipefail
            mkdir -p out/hello
            cd out/hello
            go mod init example.com/hello
            cat > main.go <<'EOF'
            package main

            import (
            	"fmt"

            	"rsc.io/quote"
            )

            func main() { fmt.Println(quote.Go()) }
            EOF
            go mod tidy
            go build -o hello .
            ./hello
```

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
