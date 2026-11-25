FROM vllm/vllm-openai:v0.32.0-cu129-ubuntu2404@sha256:9fea04bb6f2deb71db19b7cff586cefb56731a26884aa1cec60690d4e6463cf2

# Ubuntu 24.04 bases ship a default `ubuntu` user at uid 1000; replace it with
# the non-root `swale` user the container runs as.
RUN (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN python3 -c "import importlib.metadata as m; print(m.version('vllm').split('+')[0])" > /usr/share/swale-image-version

# The base image's ENTRYPOINT launches the OpenAI-compatible API server. Reset
# it to empty so a task definition's exec.args form the full command line
# (`vllm run-batch ...`).
USER swale
WORKDIR /mnt/workspace
ENTRYPOINT []

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="vLLM"
LABEL org.opencontainers.image.description="vLLM offline batch inference for Swale GPU tasks. Backs the vllm-batch task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/vllm/README.md"
LABEL org.opencontainers.image.licenses="Apache-2.0"
