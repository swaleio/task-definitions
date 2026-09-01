#!/usr/bin/env bash
# Decides which images a run must build and whose Docker Hub description it must
# refresh. Run it directly to see what a push would do:
#
#   eng/scripts/discover-images.sh "" <before-sha> <head-sha>
#
# The two are independent concerns. A README is not part of the build, so
# changing one must not rebuild gigabytes; a Dockerfile change does not touch
# the description. A commit doing both gets both, in parallel.
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
  # A release republishes every image and refreshes every description, which is
  # also how a newly added image gets its page for the first time.
  build=$(find images -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
  sync="$build"
elif [ -n "$requested" ]; then
  build="$requested"
  sync="$requested"
else
  # workflow_dispatch carries no "before" commit, so fall back to the previous
  # commit for the documented changed-since-last-push behaviour.
  [ -n "$before" ] || before=$(git rev-parse HEAD^)
  changed=$(git diff --name-only "$before" "$head_sha" -- images/)
  build=$(printf '%s\n' "$changed" | awk -F/ 'NF > 1 && $NF != "README.md" { print $2 }' | sort -u)
  sync=$(printf '%s\n' "$changed" | awk -F/ 'NF > 1 && $NF == "README.md" { print $2 }' | sort -u)
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
