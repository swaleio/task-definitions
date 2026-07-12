# hf-cli

Swale-built image backing the `hf-download` and `hf-upload` task definitions. It
wraps the [Hugging Face CLI](https://huggingface.co/docs/huggingface_hub) (`hf`)
so a workflow can pull models/datasets into the shared workspace or push
artifacts back to the Hub.

- **Base:** `python:3.13-slim`
- **Installed:** `huggingface_hub[cli,hf_xet]` (the `hf` CLI plus the Xet
  accelerated transfer backend)
- **User:** non-root `swale` (uid 1000)
- **`HF_HOME=/mnt/workspace/.hf-cache`** — the Hub cache lives on the shared
  workspace volume, so downloaded blobs persist across tasks in a run.
- **`WORKDIR /mnt/workspace`**, **`ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`**

## Invocation

The task definition's `exec.args` are appended to the entrypoint as the `hf`
command line, e.g. `["download", "${{inputs.repo}}", "--local-dir",
"/mnt/workspace/${{inputs.dest}}"]`. The entrypoint then augments that command
line from these inputs before running `hf "$@"`:

| Input env | Applies to | Effect |
|-----------|------------|--------|
| `INPUT_TOKEN` | all | Exported as `HF_TOKEN` to authenticate against the Hub. Pass a secret. |
| `INPUT_INCLUDE` | `download` | Comma-separated glob patterns; each becomes a repeated `--include <glob>`. Patterns are passed literally (no shell globbing). |
| `INPUT_REVISION` | all | Appended as `--revision <ref>` to pin a branch, tag, or commit. |
| `INPUT_DEST` | `download` | Names the download destination directory; used to emit the `path` output. Defaults to `model`. |
| `INPUT_PATH_IN_REPO` | `upload` | Appended as the trailing positional destination path inside the target repository. |

## Output

After a successful `download`, the entrypoint appends

```
path=/mnt/workspace/<dest>
```

to `$WORKFLOW_TASK_OUTPUT`, where `<dest>` is `INPUT_DEST` (default `model`).
The consuming task must declare a `path` output. `upload` emits nothing.

## Building

```sh
docker build -t docker.io/swaleio/hf-cli:1-0-0 images/hf-cli
```

CI pins the real base digest and publishes the image; task definitions reference
it as `docker.io/swaleio/hf-cli@sha256:<digest>`.
