---
name: FFmpeg
description: Runs a Bash script with ffmpeg and ffprobe on PATH. Transcode, cut, or turn frames into video.
inputs:
  script:
    description: The Bash script to run; ffmpeg and ffprobe are on PATH. Parameterize it by interpolating a trusted workflow expression into the script text, or by reading a run-level environment variable inside it.
    required: true
exec:
  # docker.io/swaleio/ffmpeg:1.0.0
  image: docker.io/swaleio/ffmpeg@sha256:3f1239cac560f19208a56fa0fa3f417dc4a2979925c6166f837e168232175271
  args:
    - bash
    - -lc
    - 'printf %s "$INPUT_SCRIPT" > /tmp/run.sh && exec bash /tmp/run.sh'
---

# FFmpeg

The `bash` task with [FFmpeg](https://ffmpeg.org/) installed: writes your
`script` to a file and executes it with `bash`, with `ffmpeg` and `ffprobe` on
`PATH`. It is Debian's own FFmpeg 7.1 build, so the CPU codec set is the one you
would get from `apt` — libx264, libx265, libvpx, libaom, libsvtav1, libopus and
the rest.

Read the source from and write the result into the shared workspace
(`$WORKFLOW_STORAGE`) so an earlier task's output — a rendered frame sequence,
a pulled mezzanine file — is the input, and a later task (`swale-push`, a
model that consumes the frames) picks up the output. Put large intermediates
on the task's private scratch (`$WORKFLOW_TASK_STORAGE`), which is local disk.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `script` | yes | The Bash script to run. Self-contained; parameterize only with trusted workflow expressions. |

## Outputs

None. Append `key=value` lines to `$WORKFLOW_TASK_OUTPUT` from a task that
declares outputs; this generic task declares none.

## Compute

**CPU.** FFmpeg's software encoders use every core the compute type has and no
GPU; scheduling this task on a GPU compute type wastes money. Debian's build
does list the NVENC encoders, but they are unverified on this platform — use
the CPU encoders.

## Example

Turn the frame sequence a render left in the workspace into an H.264 file, then
publish it:

```yaml
name: Encode a frame sequence
compute_type: cpu-4
entry_point: main

blocks:
  main:
    tasks:
      encode:
        name: Encode
        uses: swaleio/ffmpeg@1.0.0
        args:
          script: |
            set -euo pipefail
            mkdir -p "$WORKFLOW_STORAGE/out"
            ffmpeg -y -framerate 24 \
              -i "$WORKFLOW_STORAGE/frames/frame_%04d.png" \
              -c:v libx264 -pix_fmt yuv420p \
              "$WORKFLOW_STORAGE/out/animation.mp4"
            ffprobe -v error -show_entries stream=codec_name,width,height,nb_frames \
              -of default=nw=1 "$WORKFLOW_STORAGE/out/animation.mp4"
      publish:
        name: Publish
        start_on:
          - encode
        uses: swaleio/swale-push@1.0.0
        args:
          target: my-project/renders:latest
          source: ${{env.WORKFLOW_STORAGE}}/out
          account: my-account
          token: ${{secrets.WORKFLOW_TOKEN}}
```

See `blender-render` for the task that produces such a frame sequence, split
across a `for_each` over frame ranges.

## Parameterizing

This task declares only `script`, so there are no extra args to pass. To feed a
value into the script, interpolate a **trusted** workflow expression —
`${{ inputs.x }}` or `${{ tasks.x.outputs.y }}` — into the script text, or read a
run-level environment variable inside it. Never interpolate an **untrusted**
value into the script text: it is executed as shell.

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
