#!/bin/sh
set -e

# The Swale CLI authenticates from environment variables. The task passes the
# account name as INPUT_ACCOUNT and the token as INPUT_TOKEN (injected by the
# platform from the `account` and `token` inputs); re-export them under the
# names the CLI expects: SWALE_ACCOUNT_NAME and SWALE_ACCOUNT_TOKEN.
if [ -n "$INPUT_ACCOUNT" ]; then
  export SWALE_ACCOUNT_NAME="$INPUT_ACCOUNT"
fi
if [ -n "$INPUT_TOKEN" ]; then
  export SWALE_ACCOUNT_TOKEN="$INPUT_TOKEN"
fi

# Run the requested swale subcommand. args come from the task definition's
# exec.args (e.g. ["pull", ...] for swale-pull, ["push", ...] for swale-push).
exec swale "$@"
