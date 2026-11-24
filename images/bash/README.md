# bash

Swale-built image backing the `bash` task definition: Debian 13 slim as it
is, with a non-root user added. It exists so the task's version names the
Bash it runs, which the Debian tag does not.

- **Base:** `debian:13-slim`
- **User:** non-root `swale` (uid 1000)
- **No ENTRYPOINT:** the task's `exec.args` are the full command line
  (`bash -lc <script>`)
- **`WORKDIR /mnt/workspace`**

## Tags

Each tag is the version of Bash the image packages, such as `5.2.37`. A
rebuild that keeps that version, to pick up a fixed base image or wrapper,
adds `-r1`, `-r2`, and so on. A tag is never reused; `latest` follows the
newest publish.

## Building

From the repository root:

```sh
docker build -t swaleio/bash:dev images/bash
```

Merging a change under `images/bash` publishes the image under its next tag;
task definitions reference it by digest.

---

Built from [`images/bash`](https://github.com/swaleio/task-definitions/tree/main/images/bash) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile is covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). The software this image packages keeps
its own licenses, which ship inside the image.
