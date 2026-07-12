# git

Swale-built image backing the `git-clone` task definition. It wraps `git` with
Git LFS and non-interactive HTTPS token authentication, and emits the resolved
commit SHA as a task output.

- **Base:** `alpine/git`
- **Installed:** `git`, `git-lfs`, `openssh-client`, `ca-certificates`
- **User:** non-root `swale` (uid 1000)
- **`WORKDIR /mnt/workspace`**, **`ENTRYPOINT ["/opt/git/entrypoint.sh"]`**

## Invocation

The task definition's `exec.args` are the `git` command line (e.g.
`["clone", "--depth=1", "${{inputs.repository_url}}", "/mnt/workspace/${{inputs.dest}}"]`).
The entrypoint runs `git "$@"` and augments it from these inputs:

| Input env | Effect |
|-----------|--------|
| `INPUT_GIT_TOKEN` | Configures HTTPS credential storage so a private repo can be cloned over `https://oauth2:<token>@host`. Pass a secret. |
| `INPUT_REPOSITORY_URL` | Used to derive the credential host. |
| `INPUT_DEST` | Names the clone destination under the workspace; used to emit the `commit_sha` output. Defaults to `repo`. |

## Output

After a successful `clone`, the entrypoint appends

```
commit_sha=<resolved HEAD SHA>
```

to `$WORKFLOW_TASK_OUTPUT`.

## Building

```sh
docker build -t docker.io/swaleio/git:1-0-0 images/git
```

CI publishes the image; task definitions reference it as
`docker.io/swaleio/git@sha256:<digest>`.
