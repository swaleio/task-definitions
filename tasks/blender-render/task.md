---
name: Blender render
description: Renders frames of a .blend file with Blender in the background, on CPU or on the GPU.
inputs:
  scene:
    description: Absolute path of the .blend file to render, e.g. ${{env.WORKFLOW_STORAGE}}/scene/animation.blend.
    required: true
  output:
    description: "Absolute output path in Blender's own form, with # for the frame digits, e.g. ${{env.WORKFLOW_STORAGE}}/frames/frame_####. The directory is created; the extension follows the format."
    required: true
  frames:
    description: Which frames to render — START-END for an inclusive range, a single number for one frame, or empty for the scene's own frame range.
    default: ""
  engine:
    description: Render engine passed to Blender's -E. Cycles is the engine this task is verified with; Eevee needs a display context that background rendering does not provide.
    default: CYCLES
  device:
    description: Cycles device — CPU, or OPTIX / CUDA on a GPU compute type. Anything but CPU is passed as --cycles-device and fails fast when no such device exists.
    default: CPU
  format:
    description: Output format passed to Blender's -F (PNG, JPEG, OPEN_EXR, ...). Empty keeps the format saved in the scene.
    default: ""
outputs:
  path:
    description: The directory the frames were written to, i.e. the directory of the output input.
exec:
  # docker.io/swaleio/blender:1.0.0
  image: docker.io/swaleio/blender@sha256:e65baad8e666a31e9fe91b0c8ca5cda807ec9b2e695f3cfe40537949f23cbce0
---

# Blender render

Renders `frames` of the `.blend` file at `scene` with Blender 5.2 LTS in
background mode, writing them to `output`. Point both at the shared workspace
and the task becomes one unit of a render farm: a `for_each` over frame ranges
runs as many of these as the workflow lists, every one reading the same scene
and its textures from the workspace without copying them, and every one
writing into the same frame sequence for the encoder that follows.

The image is the official Blender build straight from `download.blender.org`,
checksum-verified, running as a non-root user; nothing is added to it. Keep the
scene's external data reachable from the workspace — packed into the `.blend`,
or at relative paths beside it — since the task container sees nothing else.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `scene` | yes | — | Absolute path of the `.blend` file. |
| `output` | yes | — | Absolute output path in Blender's form, `#` for frame digits (`frame_####` → `frame_0001.png`). |
| `frames` | no | scene range | `START-END`, a single frame number, or empty for the scene's frame range. |
| `engine` | no | `CYCLES` | Blender's `-E` engine. |
| `device` | no | `CPU` | `CPU`, or `OPTIX` / `CUDA` on a GPU compute type. |
| `format` | no | scene setting | Blender's `-F` output format. |

## Outputs

| Output | Description |
|--------|-------------|
| `path` | The directory the frames were written to. |

## Compute

**GPU recommended.** Cycles renders on any CPU compute type with `device: CPU`,
which is correct but slow. On a GPU compute type, `device: OPTIX` (or `CUDA`)
moves the render onto the GPU — the workflow selects the compute type via
`compute_type`. Asking for a GPU device on a CPU compute type fails at once with
"Found no Cycles device of the specified type", by design. Eevee is not
supported in background rendering here: it needs a display context the task
container does not have.

## Example

Render 96 frames as four chunks in parallel, then encode and publish the
sequence. The frame chunks are a JSON array the run can override at start:

```yaml
name: Render an animation
compute_type: cpu-4
entry_point: main

inputs:
  frame_chunks:
    default: '["1-24","25-48","49-72","73-96"]'

blocks:
  main:
    tasks:
      fetch:
        name: Fetch the scene
        uses: swaleio/swale-pull@1.0.0
        args:
          target: my-project/scenes:latest
          dest: ${{env.WORKFLOW_STORAGE}}/scene
          account: my-account
          token: ${{secrets.WORKFLOW_TOKEN}}
      render_chunks:
        name: Render frame chunks
        start_on:
          - fetch
        for_each:
          items: ${{inputs.frame_chunks}}
          block: render_chunk
      encode:
        name: Encode
        start_on:
          - render_chunks
        uses: swaleio/ffmpeg@1.0.0
        args:
          script: |
            set -euo pipefail
            mkdir -p "$WORKFLOW_STORAGE/out"
            ffmpeg -y -framerate 24 \
              -i "$WORKFLOW_STORAGE/frames/frame_%04d.png" \
              -c:v libx264 -pix_fmt yuv420p \
              "$WORKFLOW_STORAGE/out/animation.mp4"
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

  render_chunk:
    tasks:
      render:
        name: Render frames
        uses: swaleio/blender-render@1.0.0
        compute_type: t4-1   # any GPU compute type — see Compute above
        args:
          scene: ${{env.WORKFLOW_STORAGE}}/scene/animation.blend
          output: ${{env.WORKFLOW_STORAGE}}/frames/frame_####
          frames: ${{tasks.render_chunks.for_each.item}}
          device: OPTIX
```

Every chunk writes into the same `frames/` directory with Blender's frame
numbering, so the sequence assembles itself; a chunk that fails stops the run
before the encoder consumes a gap. More chunks means more concurrent tasks —
size the list to the compute type's pool, since each chunk takes a node of its
own.

To render a single still, pass `frames: 42` and no `for_each`.

---

For the workflow syntax these examples use, see the
[workflow definition reference](https://docs.swale.io/reference/workflow-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

Licensed under the [MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
