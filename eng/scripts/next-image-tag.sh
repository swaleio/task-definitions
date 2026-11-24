#!/usr/bin/env bash
# Prints the tag an image publishes under: the version of the tool it packages,
# or that version with -r1, -r2, ... added once the version is published. Run it
# directly to see what a publish would pick (needs curl and jq):
#
#   eng/scripts/next-image-tag.sh swaleio/git 2.54.0
set -euo pipefail

repository="${1:-}"
version="${2:-}"

fail() {
  echo "::error::$1" >&2
  exit 1
}

[ -n "$repository" ] && [ -n "$version" ] \
  || fail "Usage: next-image-tag.sh <namespace>/<image> <version>"

# The version is whatever the image's Dockerfile recorded from the tool itself,
# so a tool whose output changed shape surfaces here rather than as a tag.
printf '%s' "$version" | grep -Eq '^[0-9]+(\.[0-9]+){1,3}$' \
  || fail "$repository recorded version '$version'; expected one like 1.2.3"

# Docker Hub's tag search matches substrings, so read every page of matches and
# keep the exact ones: <version> and <version>-r<N>.
taken=""
url="https://hub.docker.com/v2/repositories/$repository/tags?page_size=100&name=$version"
while [ -n "$url" ]; do
  response=$(curl -sS -w '\n%{http_code}' "$url")
  code="${response##*$'\n'}"
  body="${response%$'\n'*}"
  case "$code" in
    200) ;;
    # No repository yet: this is the image's first publish.
    404) break ;;
    # Anything else could hide a tag that is already taken, and pushing over a
    # published tag is the one thing this must never do.
    *) fail "Docker Hub answered $code listing the tags of $repository" ;;
  esac
  taken+="$(printf '%s' "$body" | jq -r '.results[].name')"$'\n'
  url="$(printf '%s' "$body" | jq -r '.next // empty')"
done

# awk rather than grep, which exits 1 on no match and would end the script.
highest=$(printf '%s' "$taken" | awk -v v="$version" '
  $0 == v { n = (n == "" ? 0 : n) }
  index($0, v "-r") == 1 {
    r = substr($0, length(v) + 3)
    if (r ~ /^[0-9]+$/ && (n == "" || r + 0 > n)) n = r + 0
  }
  END { print n }')

if [ -z "$highest" ]; then
  echo "$version"
else
  echo "$version-r$((highest + 1))"
fi
