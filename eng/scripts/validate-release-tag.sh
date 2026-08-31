#!/usr/bin/env bash
# Validates a release tag of the form <task-name>/<version> and resolves it to
# the definition it releases. Run it directly to check a tag before pushing:
#
#   eng/scripts/validate-release-tag.sh git-clone/1.0.0
#
# The rules mirror the platform's own, which rejects a version at import time:
# names take no dots, versions do but must begin and end alphanumeric, never
# contain '..', and never be 'latest'.
set -euo pipefail

NAME_PATTERN='^[A-Za-z0-9_-]{1,100}$'
VERSION_PATTERN='^[A-Za-z0-9]([A-Za-z0-9._-]{0,98}[A-Za-z0-9])?$'

fail() {
  echo "::error::$1" >&2
  exit 1
}

tag="${1:-}"
[ -n "$tag" ] || fail "Usage: validate-release-tag.sh <task-name>/<version>"

name="${tag%%/*}"
version="${tag#*/}"
if [ -z "$name" ] || [ -z "$version" ] || [ "$name/$version" != "$tag" ]; then
  fail "Tag '$tag' must be '<task-name>/<version>'"
fi

printf '%s' "$name" | grep -Eq "$NAME_PATTERN" \
  || fail "Task name '$name' must match $NAME_PATTERN"

printf '%s' "$version" | grep -Eq "$VERSION_PATTERN" \
  || fail "Version '$version' must match $VERSION_PATTERN"

case "$version" in
  *..*) fail "Version '$version' cannot contain '..'" ;;
esac

if [ "$(printf '%s' "$version" | tr '[:upper:]' '[:lower:]')" = "latest" ]; then
  fail "Version '$version' is reserved by the platform"
fi

# Resolved from the script's own location so the check holds wherever it runs.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
definition="$repo_root/tasks/$name/task.md"
[ -f "$definition" ] || fail "tasks/$name/task.md does not exist at tag '$tag'"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "name=$name"
    echo "version=$version"
  } >> "$GITHUB_OUTPUT"
else
  echo "name=$name"
  echo "version=$version"
fi
