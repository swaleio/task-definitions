---
name: Rust
description: Runs an arbitrary shell script with the current stable Rust toolchain and Cargo available.
inputs:
  script:
    description: The shell script to run. cargo and rustc are on PATH. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable inside it.
    required: true
exec:
  # docker.io/library/rust:1-slim-trixie
  image: docker.io/library/rust@sha256:6f14b2b4b278ec0d50aa1d69541c304ce0f95e0f6268487aa9924af1c2e9aebe
  args:
    - bash
    - -c
    - 'cd "$WORKFLOW_TASK_STORAGE" && export CARGO_HOME="$HOME/.cargo" && printf %s "$INPUT_SCRIPT" > /tmp/run.sh && exec bash /tmp/run.sh'
---

# Rust

Writes your `script` to a file and executes it with `bash` on the
`rust:1-slim-trixie` image, so `cargo` and `rustc` are on `PATH` for builds,
tests, and `cargo` subcommands. `script` is a **shell** script (not Rust
source): call the toolchain from it the way you would in a terminal.

This task follows the current stable Rust rather than offering one definition
per Rust version. Rust supports only its latest stable release, ships a new one
every six weeks, and promises backward compatibility across Rust 1; editions are
chosen per crate, and every compiler supports all of them. Pin an older version
of this task to hold a build still.

The toolchain installed in the image is the one that runs. A project's
`rust-toolchain.toml` asking for a different version would make `rustup` try to
install it into the image's read-only toolchain directory, and the build fails.

The image keeps `CARGO_HOME` at `/usr/local/cargo`, which is read-only on the
platform, so the task moves it to `$HOME/.cargo`: the crate registry and its
downloads land in the writable home directory. `cargo` and `rustc` stay on
`PATH` from the image.

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
| `script` | yes | — | Shell script to run with `cargo` and `rustc` on `PATH`. Parameterize by interpolating a trusted workflow expression or reading a run-level env var. |

## Emitting outputs

Append `key=value` lines to the file at `$WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks (declare them in a task that needs typed outputs;
this generic `rust` task declares none). Share build artifacts by writing them
somewhere a later task reads — the working directory for this task alone, or the
shared workspace (`$WORKFLOW_STORAGE` in the container) when another task must
pick them up.

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money.
`cargo` compiles crates in parallel, so a larger CPU compute type shortens
builds with many dependencies.

## Example

The task declares only `script`, so the example passes only `script` and the
script is self-contained — it works in a relative `out/` directory under the
working directory rather than assuming any particular mount. The task starts in
its own scratch directory (`$WORKFLOW_TASK_STORAGE`), which is writable and
discarded when the task ends.

```yaml
name: Rust example
compute_type: cpu-4
entry_point: main

blocks:
  main:
    tasks:
      build:
        name: Build binary
        uses: swaleio/rust@1.0.0
        args:
          script: |
            set -euo pipefail
            cargo new --bin out/hello
            cd out/hello
            cargo add itoa
            cat > src/main.rs <<'EOF'
            fn main() {
                let mut buffer = itoa::Buffer::new();
                println!("built with rust: {}", buffer.format(2026));
            }
            EOF
            cargo build --release
            ./target/release/hello
```

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
