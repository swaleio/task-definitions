---
name: Java 25 Maven
description: Runs an arbitrary shell script with a Java 25 JDK and Maven, for building and testing Java.
inputs:
  script:
    description: The shell script to run. A JDK and Maven are on PATH; invoke Maven as `mvn -B`. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable inside it.
    required: true
exec:
  # docker.io/library/maven:3.9.16-eclipse-temurin-25
  image: docker.io/library/maven@sha256:93b8a14ea2f412782e4e842651273b4d903e35cc496284f178fbbe2d67d00976
  args:
    - bash
    - -lc
    - 'cd "$WORKFLOW_TASK_STORAGE" && export MAVEN_OPTS="-Duser.home=$HOME $MAVEN_OPTS" && printf %s "$INPUT_SCRIPT" > /tmp/run.sh && exec bash /tmp/run.sh'
---

# Java 25 Maven

Writes your `script` to a file and executes it with `bash` inside an image that
has a JDK (Eclipse Temurin 25) and Apache Maven 3.9 on `PATH`. Use it to build,
test, and package Java projects. Run Maven in batch mode (`mvn -B`) so it emits
non-interactive, log-friendly output.

Maven reads its home from the image's account rather than `$HOME`, so the task
points it at `$HOME` through `MAVEN_OPTS`; the local repository therefore lands
in the writable home directory. The image's own entrypoint still reports that it
cannot write to `/root/.m2` as the task starts — that message is harmless.

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
| `script` | yes | — | Shell script to run; a JDK and `mvn` are on `PATH`. Parameterize by interpolating a trusted workflow expression or reading a run-level env var. |

## Compute

**CPU.** No GPU is needed and scheduling it on a GPU compute type wastes money; GPU workloads belong in the `transformers` task (the GPU Python lane).

## Example

The task declares only `script`, so the example passes only `script` and the
script is self-contained — it scaffolds and packages a project under a relative
`out/` directory rather than assuming any particular mount. The task starts in its own scratch directory (`$WORKFLOW_TASK_STORAGE`), which is writable and discarded when the task ends.

```yaml
name: Java 25 Maven example
compute_type: cpu-4
entry_point: main

blocks:
  main:
    tasks:
      build:
        name: Build
        uses: swaleio/java-maven-25
        args:
          script: |
            set -euo pipefail
            mvn -B archetype:generate \
              -DgroupId=com.example -DartifactId=app \
              -DarchetypeArtifactId=maven-archetype-quickstart \
              -DarchetypeVersion=1.4 -DinteractiveMode=false \
              -DoutputDirectory=out
            mvn -B -f out/app/pom.xml -Dmaven.compiler.source=25 -Dmaven.compiler.target=25 package
```

The example scaffolds and packages into a relative `out/` directory; point Maven
at the shared workspace (`$WORKFLOW_STORAGE` in the container) instead when a downstream task must
consume the produced artifacts.

## Emitting outputs

Append `key=value` lines to the file at `$WORKFLOW_TASK_OUTPUT` to publish
outputs for downstream tasks. This generic task declares no typed outputs; use a
fixed task when you need a declared output contract.

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
