# Base: vllm/vllm-openai:v0.25.0-cu129-ubuntu2404 (pin the digest; tag kept for humans)
FROM vllm/vllm-openai@sha256:45fb56697a60265776fde7aed64f09b1368987d1d1cfdd1f6692a493548fa5ee

# The base image ships the vLLM engine and CLI (`vllm run-batch`); add the
# EleutherAI evaluation harness on top so one image backs both batch inference
# and evaluation tasks.
RUN pip install --no-cache-dir "lm-eval==0.4.12"

# Ubuntu 24.04 bases ship a default `ubuntu` user at uid 1000; replace it with
# the non-root `swale` user the container runs as.
RUN (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

# The base image's ENTRYPOINT launches the OpenAI-compatible API server. Reset
# it to empty so a task definition's exec.args form the full command line
# (e.g. `vllm run-batch ...` or `lm_eval ...`).
USER swale
WORKDIR /mnt/workspace
ENTRYPOINT []

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="vLLM tools"
LABEL org.opencontainers.image.description="vLLM plus lm-evaluation-harness for Swale GPU tasks. Backs vllm-batch and lm-eval."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/vllm-tools/README.md"
LABEL org.opencontainers.image.licenses="MIT"
