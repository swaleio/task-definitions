#!/usr/bin/env bash
# Points an additional tag at an image that is already published, without
# rebuilding it:
#
#   eng/scripts/retag-image.sh swaleio/git 1-0-0 1.0.0
#
# A single-source `imagetools create` over an image index is a carbon copy, so
# the digest does not move and any definition pinning it stays valid. That is
# asserted rather than assumed: if the digest changes, the image was rebuilt
# and the run fails.
set -euo pipefail

repo="${1:?repository, e.g. swaleio/git}"
source_tag="${2:?tag to copy from}"
target_tag="${3:?tag to create}"

digest_of() {
  docker buildx imagetools inspect "$1" --format '{{.Manifest.Digest}}'
}

before=$(digest_of "$repo:$source_tag")
docker buildx imagetools create --tag "$repo:$target_tag" "$repo:$source_tag"
after=$(digest_of "$repo:$target_tag")

if [ "$before" != "$after" ]; then
  echo "::error::$repo digest moved copying $source_tag to $target_tag: $before -> $after"
  exit 1
fi

echo "$repo:$target_tag -> $after (identical to $source_tag)"
