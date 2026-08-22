# ollama

Swale-built image backing the **`ollama-serve`** runner task. It wraps the
[Ollama](https://ollama.com) server so a workflow can stand up a model-serving
API that other tasks in the run call over HTTP — Ollama's native API
(`/api/generate`, `/api/chat`, `/api/tags`, …) and its OpenAI-compatible
endpoints (`/v1/chat/completions`, …) are both served on port `11434`.

- **Base:** `ollama/ollama:0.31.2` (digest-pinned)
- **User:** non-root `swale` (uid 1000)
- **`OLLAMA_HOST=0.0.0.0:11434`** baked in, so the server binds all interfaces
  on the expected port regardless of base-image defaults and consumer tasks can
  reach it at the runner pod's address.
- **`WORKDIR /mnt/workspace`**, **`ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`**
  (the base entrypoint `/bin/ollama` is reset to the wrapper).

## Invocation

The `ollama-serve` task passes **no `args`** — the wrapper is driven entirely by
`INPUT_*` environment variables (injected by the platform from task inputs):

| Input env | Required | Purpose |
|-----------|----------|---------|
| `INPUT_MODEL` | yes (required task input) | Model to `ollama pull` once the server answers, e.g. `llama3.2:3b`. |
| `INPUT_MODELS_PATH` | no | Exported as `OLLAMA_MODELS` when non-empty, moving the model store off the per-task home directory. |

## Lifecycle

1. `ollama serve` starts in the background.
2. The wrapper polls `ollama list` until the API answers (2-minute cap; it
   exits non-zero if the server dies or never answers).
3. It pulls `INPUT_MODEL`. The pull necessarily happens **after** the server is
   answering (`ollama pull` talks to the running server), so `/api/tags` can
   return `200` while a multi-gigabyte pull is still in flight — consumers that
   need the model loaded should gate on its presence, not just on a `200` (see
   the `ollama-serve` task docs).
4. It waits on the server process for the runner's lifetime, forwarding
   `SIGTERM` so `terminate_on` teardown is clean.

## Outputs

None. Runner tasks have no output-tracking sidecar, and the wrapper never
writes to `$WORKFLOW_TASK_OUTPUT` — results flow over HTTP.

## Model storage

Pulled models land under the home directory (`~/.ollama/models`), which the
platform mounts writable and per-task, so the store is discarded when the runner
pod ends and each run pulls the model again.

`INPUT_MODELS_PATH` moves the store elsewhere. Pointed at the shared workspace it
outlives the pod, so a store populated by an earlier task is already there when
the server starts — `ollama pull` finds the model present and returns without
transferring anything. Because the workspace is shared by every task in the run,
two tasks writing the same store path must not overlap.

## Building

From the repository root:

```sh
docker build -t docker.io/swaleio/ollama:1-0-0 images/ollama
```

CI pins the base digest, publishes the image, and task definitions reference it
as `docker.io/swaleio/ollama@sha256:<digest>`.

---

Built from [`images/ollama`](https://github.com/swaleio/task-definitions/tree/main/images/ollama) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository, and licensed under the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE).
