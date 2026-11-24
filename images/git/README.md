# git

Swale-built image backing the `git-clone` task definition. It wraps `git` with
Git LFS and non-interactive HTTPS token authentication, and emits the resolved
commit SHA as a task output.

- **Base:** `alpine/git`, whose tag is the Git version
- **Installed:** `git`, `git-lfs`, `openssh-client`, `ca-certificates`
- **User:** non-root `swale` (uid 1000)
- **`WORKDIR /mnt/workspace`**, **`ENTRYPOINT ["/opt/git/entrypoint.sh"]`**

## Invocation

The task definition's `exec.args` are the `git` command line (e.g.
`["clone", "--depth=1", "${{inputs.repository_url}}", "${{inputs.dest}}"]`).
The entrypoint runs `git "$@"` and augments it from these inputs:

| Input env | Effect |
|-----------|--------|
| `INPUT_GIT_TOKEN` | Configures HTTPS credential storage so a private repo can be cloned over `https://oauth2:<token>@host`. Pass a secret. |
| `INPUT_REPOSITORY_URL` | Used to derive the credential host. |
| `INPUT_DEST` | The full consumer-supplied clone path; used to locate the repo when emitting the `commit_sha` output. |

## Output

After a successful `clone`, the entrypoint appends

```
commit_sha=<resolved HEAD SHA>
```

to `$WORKFLOW_TASK_OUTPUT`.

## Tags

Each tag is the version of Git the image packages, such as `2.54.0`. A
rebuild that keeps that version, to pick up a fixed base image or wrapper,
adds `-r1`, `-r2`, and so on. A tag is never reused; `latest` follows the
newest publish.

## Building

From the repository root:

```sh
docker build -t swaleio/git:dev images/git
```

Merging a change under `images/git` publishes the image under its next tag;
task definitions reference it by digest.

---

Built from [`images/git`](https://github.com/swaleio/task-definitions/tree/main/images/git) in the
[swaleio/task-definitions](https://github.com/swaleio/task-definitions) repository. For how a task definition
references an image, see the
[task definition reference](https://docs.swale.io/reference/task-definition-syntax)
in the [Swale documentation](https://docs.swale.io).

The Dockerfile and entrypoint are covered by the
[MIT License](https://github.com/swaleio/task-definitions/blob/main/LICENSE). The software this image packages keeps
its own licenses, which ship inside the image.
