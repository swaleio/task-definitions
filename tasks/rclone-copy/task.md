---
name: Rclone copy
description: Copies files between a cloud/remote storage backend and the workspace using rclone. Credentials arrive as inputs and are mapped to environment, never passed on the command line.
inputs:
  source:
    description: Source to copy from. Use `remote:bucket/path` for the configured remote, or a workspace path like `/mnt/workspace/data`.
    required: true
  dest:
    description: Destination to copy to. Use `remote:bucket/path` for the configured remote, or a workspace path like `/mnt/workspace/out`.
    required: true
  remote_type:
    description: The rclone backend for the `remote:` remote. One of s3, azureblob, gcs, dropbox, sftp, http.
    default: s3
  access_key_id:
    description: Access key id for the S3 backend (remote_type=s3). Pass a secret.
    default: ""
  secret_access_key:
    description: Secret access key for the S3 backend (remote_type=s3). Pass a secret.
    default: ""
  account:
    description: Storage account name for the Azure Blob backend (remote_type=azureblob).
    default: ""
  key:
    description: Shared key for the Azure Blob backend (remote_type=azureblob). Pass a secret.
    default: ""
  token:
    description: OAuth token JSON for backends that use it (remote_type=gcs or dropbox). Pass a secret.
    default: ""
  flags:
    description: Extra rclone flags appended to the copy command, split on whitespace (e.g. "--s3-region eu-west-1 --transfers 8"). Also how SFTP/HTTP connection details are supplied — see below.
    default: ""
exec:
  # docker.io/swaleio/rclone:1-0-0
  image: docker.io/swaleio/rclone@sha256:0000000000000000000000000000000000000000000000000000000000000000
  args: []
---

# Rclone copy

Copies files between a remote storage backend and the run's workspace using
[`rclone`](https://rclone.org). It handles S3, Azure Blob, Google Cloud Storage,
Dropbox, SFTP, and HTTP. Point `source` and `dest` at either the configured
remote (`remote:…`) or a workspace path (`/mnt/workspace/…`), in either
direction: `remote:` → workspace downloads, workspace → `remote:` uploads.

## Connection model

The image builds a **single rclone remote named `remote`** entirely from
environment variables — there is no config file to author. `remote_type` selects
the backend, and the credential inputs are mapped into `RCLONE_CONFIG_REMOTE_*`
environment variables by the image wrapper. Because credentials arrive as inputs
and are exported as environment, they never appear in the container's argv or in
a process listing.

Reference the remote in `source`/`dest` by its fixed name, `remote:` — for
example `remote:my-bucket/path` or `remote:container/blob`.

Which credential inputs you set depends on `remote_type`:

| `remote_type` | Credential inputs | Maps to rclone option |
|---------------|-------------------|-----------------------|
| `s3` | `access_key_id`, `secret_access_key` | `access_key_id`, `secret_access_key` |
| `azureblob` | `account`, `key` | `account`, `key` |
| `gcs` | `token` | `token` (OAuth JSON) |
| `dropbox` | `token` | `token` (OAuth JSON) |
| `sftp` | *(via `flags`)* | `--sftp-host`, `--sftp-user`, `--sftp-key-file`, … |
| `http` | *(via `flags`)* | `--http-url` |

For SFTP and HTTP, supply the non-secret connection details as backend flags
through `flags` (e.g. `--sftp-host files.example.com --sftp-user alice`).
Backend-specific tuning for any remote — region, endpoint, chunk size,
concurrency — also goes through `flags`.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `source` | yes | — | Source path — `remote:bucket/path` or a workspace path. |
| `dest` | yes | — | Destination path — `remote:bucket/path` or a workspace path. |
| `remote_type` | no | `s3` | rclone backend: `s3`, `azureblob`, `gcs`, `dropbox`, `sftp`, `http`. |
| `access_key_id` | no | — | S3 access key id (pass a secret). |
| `secret_access_key` | no | — | S3 secret access key (pass a secret). |
| `account` | no | — | Azure Blob storage account name. |
| `key` | no | — | Azure Blob shared key (pass a secret). |
| `token` | no | — | OAuth token JSON for GCS/Dropbox (pass a secret). |
| `flags` | no | — | Extra rclone flags (whitespace-split), incl. SFTP/HTTP connection details. |

## Outputs

None. The task writes the copied files to the destination (typically a
`/mnt/workspace/…` subpath) for downstream tasks to read; it emits no output
keys.

## Example

Download an S3 prefix into the workspace so later tasks can process it:

```yaml
tasks:
  fetch_dataset:
    name: Fetch dataset
    uses: swaleio/rclone-copy@1-0-0
    args:
      remote_type: s3
      source: remote:my-bucket/datasets/train
      dest: /mnt/workspace/data
      access_key_id: ${{secrets.aws_access_key_id}}
      secret_access_key: ${{secrets.aws_secret_access_key}}
      flags: "--s3-region eu-west-1 --transfers 8"
```

To upload instead, swap `source` and `dest` — e.g. `source: /mnt/workspace/out`
and `dest: remote:my-bucket/results`.
