#!/bin/sh
set -e

# The Swale CLI reads its credential from an environment variable. The task
# passes it as INPUT_TOKEN (injected by the platform from the `token` input);
# re-export it under the name the CLI expects.
# TODO: confirm the credential env var name against the installed CLI —
# SWALE_TOKEN is a placeholder and must be updated here if the CLI differs.
if [ -n "$INPUT_TOKEN" ]; then
  export SWALE_TOKEN="$INPUT_TOKEN"
fi

# Run the requested swale subcommand. args come from the task definition's
# exec.args (e.g. ["pull", ...] for swale-pull, ["push", ...] for swale-push).
exec swale "$@"
