#!/usr/bin/env bash
# Decides which images a publish run must rebuild and which only need their
# Docker Hub description refreshed. Run it directly to see what a push would do:
#
#   eng/scripts/discover-images.sh "" <before-sha> <head-sha>
#
# A README is not part of the build context that matters: changing one leaves
# the published digest identical, so rebuilding gigabytes to refresh a
# description is waste. Such images go to the sync list instead.
set -euo pipefail

requested="${1:-}"
before="${2:-}"
head_sha="${3:-}"

# Emptiness is filtered inside awk rather than with grep, because grep exits 1
# when it matches nothing and would take the whole script down under pipefail.
to_json='BEGIN { ORS = ""; print "[" }
         NF { printf "%s\"%s\"", (n++ ? "," : ""), $0 }
         END { print "]" }'

if [ "$requested" = "all" ]; then
  build=$(find images -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
  sync=""
elif [ -n "$requested" ]; then
  build="$requested"
  sync=""
else
  # workflow_dispatch carries no "before" commit, so fall back to the previous
  # commit for the documented changed-since-last-push behaviour.
  [ -n "$before" ] || before=$(git rev-parse HEAD^)
  changed=$(git diff --name-only "$before" "$head_sha" -- images/)
  touched=$(printf '%s\n' "$changed" | awk -F/ 'NF > 1 { print $2 }' | sort -u)
  build=$(printf '%s\n' "$changed" | awk -F/ 'NF > 1 && $NF != "README.md" { print $2 }' | sort -u)
  sync=$(comm -23 <(printf '%s\n' "$touched" | awk 'NF') <(printf '%s\n' "$build" | awk 'NF'))
fi

build_json=$(printf '%s\n' "$build" | awk "$to_json")
sync_json=$(printf '%s\n' "$sync" | awk "$to_json")

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "build=$build_json"
    echo "sync=$sync_json"
  } >> "$GITHUB_OUTPUT"
else
  echo "build=$build_json"
  echo "sync=$sync_json"
fi
