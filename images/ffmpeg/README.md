# ffmpeg

Swale-built image backing the `ffmpeg` task definition. It is Debian's own
[FFmpeg](https://ffmpeg.org/) build — `ffmpeg` and `ffprobe` with the full CPU
codec set (libx264, libx265, libvpx, libaom, libsvtav1, libopus, ...) — on a
slim base, so a workflow can transcode, cut, stitch, extract frames from, or
assemble frames into video inside the shared workspace.

- **Base:** `debian:13-slim`
- **Installed:** the `ffmpeg` package from Debian 13 (FFmpeg 7.1), signed and
  kept patched by Debian; nothing compiled here
- **User:** non-root `swale` (uid 1000)
- **No ENTRYPOINT:** the task's `exec.args` are the full command line
  (`bash -lc <script>`), exactly like the `bash` task, with `ffmpeg` and
  `ffprobe` on `PATH`
- **`WORKDIR /mnt/workspace`**

Debian's build lists the NVENC/NVDEC encoders (`h264_nvenc`, `hevc_nvenc`);
they need the NVIDIA driver, which is only present on a GPU compute type, and
the image does not request the driver's video capability — treat them as
unverified here and use the CPU encoders.

## Invocation

The `ffmpeg` task is free-form: the platform delivers the caller's script as
`INPUT_SCRIPT`, the command line writes it to `/tmp/run.sh` and executes it with
`bash`. Inside the script `$WORKFLOW_STORAGE` names the shared workspace and
`$WORKFLOW_TASK_STORAGE` the task's private scratch.

## Building

From the repository root:

```sh
docker build -t docker.io/swaleio/ffmpeg:1.0.0 images/ffmpeg
```

CI pins the real base digest and publishes the image; task definitions reference
it as `docker.io/swaleio/ffmpeg@sha256:<digest>`.

---

Built from [`images/ffmpeg`](https://github.com/swaleio/task-definitions/tree/main/images/ffmpeg) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile is covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). FFmpeg as Debian builds it is
GPL-2.0-or-later and keeps its own license, which ships inside the image.
