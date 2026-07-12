# swaleio/rclone

A thin wrapper around [rclone](https://rclone.org) that backs the `rclone-copy`
task. It configures a single rclone remote named **`remote`** from task inputs
and runs `rclone copy <source> <dest>`.

## The remote model

This image never reads an on-disk rclone config. Instead it maps task inputs to
rclone's `RCLONE_CONFIG_<REMOTE>_<OPTION>` environment variables for one remote
whose name is always the literal string `remote`. Every path you hand the task
is therefore written in rclone's `remote:path` form:

```
remote:my-bucket/data/          # "remote" == the backend configured from your inputs
```

The backend behind `remote` is selected by the `remote_type` input (default
`s3`). Credentials come from the recognized credential inputs below and are
exported **only when set**, so an unset input never overrides a backend's own
default. No `eval` is used and no config file is written.

To move data in or out of the shared workspace, use a local path such as
`/mnt/workspace/out` on one side of the copy:

```
source: remote:my-bucket/data     dest: /mnt/workspace/out     # download
source: /mnt/workspace/build      dest: remote:my-bucket/rel   # upload
```

## Supported `remote_type` values

| `remote_type` | Backend | Credential inputs it uses |
|---------------|---------|---------------------------|
| `s3` (default) | AWS S3 and S3-compatible stores (Cloudflare R2, MinIO, DigitalOcean Spaces, Wasabi) | `access_key_id`, `secret_access_key`, `endpoint` |
| `b2` | Backblaze B2 | `account`, `key` |
| `azureblob` | Azure Blob Storage | `account`, `key` |

Other rclone backends that authenticate with a single OAuth token can be named
directly (e.g. `remote_type: dropbox`) and supplied through the `token` input.

## Recognized credential inputs

Each input, when set, is exported as the matching remote-config variable:

| Input | rclone config key | Env var exported |
|-------|-------------------|------------------|
| `remote_type` | `type` | `RCLONE_CONFIG_REMOTE_TYPE` |
| `access_key_id` | `access_key_id` | `RCLONE_CONFIG_REMOTE_ACCESS_KEY_ID` |
| `secret_access_key` | `secret_access_key` | `RCLONE_CONFIG_REMOTE_SECRET_ACCESS_KEY` |
| `account` | `account` | `RCLONE_CONFIG_REMOTE_ACCOUNT` |
| `key` | `key` | `RCLONE_CONFIG_REMOTE_KEY` |
| `token` | `token` | `RCLONE_CONFIG_REMOTE_TOKEN` |
| `endpoint` | `endpoint` | `RCLONE_CONFIG_REMOTE_ENDPOINT` |

Pass credentials as project/account **secrets**, never as literals.

## Invocation

The entrypoint runs, after exporting the config above:

```
rclone copy "$INPUT_SOURCE" "$INPUT_DEST" $INPUT_FLAGS
```

- `source` and `dest` are `remote:path` (with a local `/mnt/workspace/...` path
  on one side to read from or write to the shared workspace).
- `flags` is optional extra rclone flags (e.g. `--dry-run --progress`), passed
  through verbatim.

The image is Alpine-based and runs as the base image's non-root `rclone` user
(UID 1009) with `ca-certificates` already installed.
