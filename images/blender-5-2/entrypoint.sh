#!/bin/sh
set -eu

# Every value arrives as an INPUT_* variable (a fixed-form task). The order the
# arguments are assembled in below is load-bearing: Blender applies each
# argument as it reads it, so the engine, output path and format must precede
# the -a/-f that starts the render, and the Cycles device follows the "--"
# that hands the rest of the line to the add-on.

scene="${INPUT_SCENE:-}"
output="${INPUT_OUTPUT:-}"
if [ -z "$scene" ] || [ -z "$output" ]; then
  echo "blender-render: the scene and output inputs are required" >&2
  exit 1
fi
if [ ! -f "$scene" ]; then
  echo "blender-render: scene file not found: $scene" >&2
  exit 1
fi

# Blender creates the frame files but not the directory they go in.
out_dir=$(dirname "$output")
mkdir -p "$out_dir"

set -- -b "$scene" -noaudio -E "${INPUT_ENGINE:-CYCLES}" -o "$output"

if [ -n "${INPUT_FORMAT:-}" ]; then
  set -- "$@" -F "$INPUT_FORMAT"
fi

# Which frames: "START-END" renders that inclusive range, a single number
# renders one frame, and nothing at all renders the scene's own frame range.
frames="${INPUT_FRAMES:-}"
case "$frames" in
  "")  set -- "$@" -a ;;
  *-*) set -- "$@" -s "${frames%-*}" -e "${frames#*-}" -a ;;
  *)   set -- "$@" -f "$frames" ;;
esac

# The Cycles device is an add-on option and lives after the "--". CPU is
# Blender's own default, so it is only ever passed when something else is asked
# for; on a GPU compute type, OPTIX or CUDA moves the render onto the device.
device="${INPUT_DEVICE:-CPU}"
if [ "$device" != "CPU" ]; then
  set -- "$@" -- --cycles-device "$device"
fi

# With `set -e`, a non-zero exit stops the script before the output below is
# emitted.
blender "$@"

# Publish the directory the frames landed in so a downstream task (an encoder,
# a push) can pick them up without restating the pattern.
if [ -n "${WORKFLOW_TASK_OUTPUT:-}" ]; then
  printf 'path=%s\n' "$out_dir" >> "$WORKFLOW_TASK_OUTPUT"
fi
