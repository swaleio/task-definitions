# powershell-7-7

Swale-built image backing the `powershell-7-7` task definition: PowerShell 7.7,
installed from Microsoft's signed package repository for Debian 13. Microsoft no
longer publishes PowerShell container images; it ships PowerShell inside its
.NET SDK image instead, whose tag names the SDK rather than PowerShell.

- **Base:** `debian:13-slim`
- **Installed:** the `powershell` package from `packages.microsoft.com`, whose
  signing key must match a pinned fingerprint before anything it signs is
  trusted. Its version stays on the 7.7 line.
- **User:** non-root `swale` (uid 1000)
- **No ENTRYPOINT:** the task's `exec.args` are the full command line
  (`pwsh -NoLogo -NoProfile -Command ...`), with `pwsh` on `PATH`
- **`WORKDIR /mnt/workspace`**

## Tags

Each tag is the version of PowerShell the image packages, such as `7.7.0`. A
rebuild that keeps that version, to pick up a fixed base image or wrapper,
adds `-r1`, `-r2`, and so on. A tag is never reused; `latest` follows the
newest publish.

## Building

From the repository root:

```sh
docker build -t swaleio/powershell-7-7:dev images/powershell-7-7
```

Merging a change under `images/powershell-7-7` publishes the image under its next tag;
task definitions reference it by digest.

---

Built from [`images/powershell-7-7`](https://github.com/swaleio/task-definitions/tree/main/images/powershell-7-7) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile is covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). The software this image packages keeps
its own licenses, which ship inside the image.
