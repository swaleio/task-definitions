# blender-5-2

Swale-built image backing the `blender-render-5-2` task definition. It packages the
official [Blender](https://www.blender.org/) 5.2 LTS Linux build for background
(`-b`) rendering, so a workflow can render a `.blend` file's frames into the
shared workspace — split across as many tasks as the frame range has chunks.

- **Base:** `ubuntu:24.04`
- **Installed:** Blender 5.2 LTS from `download.blender.org`, checked against the
  SHA-256 Blender publishes beside it,
  under `/opt/blender` with `blender` on `PATH`; the X11/GL client libraries
  the binary links against (needed even without a display)
- **User:** non-root `swale` (uid 1000)
- **GPU:** `NVIDIA_DRIVER_CAPABILITIES=compute,utility`, so on a GPU compute
  type the NVIDIA runtime mounts the driver Cycles needs for `CUDA`/`OPTIX`;
  on CPU compute types the variable is inert
- **`WORKDIR /mnt/workspace`**, **`ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`**

## Invocation

The task definition passes no `exec.args`; the entrypoint assembles the whole
Blender command line from the task's inputs (`INPUT_*` env vars injected by the
platform), in the order Blender requires:

| Input env | Effect |
|-----------|--------|
| `INPUT_SCENE` | The `.blend` file to render (`-b <scene>`). Must exist; checked before Blender starts. |
| `INPUT_OUTPUT` | Render output path (`-o <output>`), Blender's own pattern with `#` for frame digits. The directory is created if missing. |
| `INPUT_ENGINE` | `-E <engine>`; default `CYCLES`. |
| `INPUT_FORMAT` | `-F <format>` when non-empty; otherwise the scene's own output format. |
| `INPUT_FRAMES` | `START-END` → `-s START -e END -a`; a single number → `-f N`; empty → `-a` (the scene's frame range). |
| `INPUT_DEVICE` | Anything but `CPU` is passed as `-- --cycles-device <device>` (e.g. `OPTIX`, `CUDA`). |

Blender runs with `-noaudio`; a non-zero exit fails the task.

## Output

After a successful render, the entrypoint appends

```
path=<directory of INPUT_OUTPUT>
```

to `$WORKFLOW_TASK_OUTPUT`. The consuming task must declare a `path` output.

## Tags

Each tag is the version of Blender the image packages, such as `5.2.4`. A
rebuild that keeps that version, to pick up a fixed base image or wrapper,
adds `-r1`, `-r2`, and so on. A tag is never reused; `latest` follows the
newest publish.

## Building

From the repository root:

```sh
docker build -t swaleio/blender-5-2:dev images/blender-5-2
```

Merging a change under `images/blender-5-2` publishes the image under its next tag;
task definitions reference it by digest.

---

Built from [`images/blender-5-2`](https://github.com/swaleio/task-definitions/tree/main/images/blender-5-2) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile and entrypoint are covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). Blender is
[GPL-2.0-or-later](https://www.blender.org/about/license/) and keeps its own license, which ships inside the image.
