#!/usr/bin/env bash
# Decides which images a run must build and whose Docker Hub description it must
# refresh. Run it directly to see what a push would do:
#
#   eng/scripts/discover-images.sh "" <before-sha> <head-sha>
#
# For a pull request, <before-sha> is the base it targets.
#
# The two are independent concerns. A README is not part of the build, so
# changing one must not rebuild gigabytes; a Dockerfile change does not touch
# the description. A commit doing both gets both, the description once the
# build is done.
set -euo pipefail

requested="${1:-}"
before="${2:-}"
head_sha="${3:-}"

# A deleted image still shows up in the diff, but has no directory left to
# build from or describe. Without this it reaches the matrix and the build
# fails on a context that is not there -- which is what removing an image
# looks like, not a mistake worth failing a run over.
existing() {
  while read -r name; do
    if [ -n "$name" ] && [ -d "images/$name" ]; then
      printf '%s\n' "$name"
    fi
  done
}

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
  # Named explicitly, so say plainly that it is not there rather than
  # handing docker a context that does not exist.
  if [ ! -d "images/$requested" ]; then
    echo "::error::No image directory images/$requested" >&2
    exit 1
  fi
  build="$requested"
  sync="$requested"
else
  # workflow_dispatch carries no "before" commit, so fall back to the previous
  # commit for the documented changed-since-last-push behaviour. Three dots diff
  # from where the two meet, so a pull request whose base has moved on sees only
  # its own changes.
  [ -n "$before" ] || before=$(git rev-parse HEAD^)
  changed=$(git diff --name-only "$before...$head_sha" -- images/)
  # A comment changes nothing an image runs, so a file whose changes are all
  # comment lines rebuilds nothing; publishing it would only mint an -rN of the
  # same image. Two lines look like comments but are not: an entrypoint's `#!`,
  # which the pattern leaves out, and a Dockerfile parser directive (`# syntax=`,
  # `# escape=`, `# check=`), which steers the build, so a changed one counts.
  # git reads -I as a basic regex, with no alternation: one pattern for a
  # comment with text, one for a bare `#` line. Each file is checked on its
  # own because some git versions list a file under --name-only even when -I
  # leaves nothing of its change; --quiet's exit code honours -I in all of them.
  built=""
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if ! git diff --quiet -I '^[[:space:]]*#[^!]' -I '^[[:space:]]*#$' "$before...$head_sha" -- "$file"; then
      built+="$file"$'\n'
    fi
  done <<< "$changed"
  directives=$(git diff -U0 "$before...$head_sha" -- images/ | awk '
    /^\+\+\+ b\// { file = substr($0, 7) }
    tolower($0) ~ /^[-+]#[[:space:]]*(syntax|escape|check)[[:space:]]*=/ { print file }')
  build=$(printf '%s\n%s\n' "$built" "$directives" | awk -F/ 'NF > 1 && $NF != "README.md" { print $2 }' | sort -u | existing)
  sync=$(printf '%s\n' "$changed" | awk -F/ 'NF > 1 && $NF == "README.md" { print $2 }' | sort -u | existing)
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
