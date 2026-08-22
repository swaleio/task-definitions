# Base: ollama/ollama:0.31.2 (digest-pinned; tag kept for humans)
FROM ollama/ollama@sha256:509fdf54e23bd50d87af646cb51c0a7a203d6a83cc4d6695b3b08c5be1c62c0a

RUN (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Bind all interfaces on the expected port regardless of base-image defaults,
# so consumer tasks can reach the API at the runner pod's address
# (${{tasks.<id>.ip-address}}:11434). The entrypoint honors this value.
ENV OLLAMA_HOST=0.0.0.0:11434

# Pulled models land under the user's home on container-local disk, which is
# fine for the runner's lifetime — nothing needs to outlive the pod.
# OLLAMA_MODELS could be pointed elsewhere (e.g. a mounted path) in a later
# image revision if models ever need to be shared or persisted.

USER swale
WORKDIR /mnt/workspace
EXPOSE 11434

# The base image's ENTRYPOINT is /bin/ollama (CMD "serve"); reset it to the
# wrapper so the server starts in the background, the requested model is
# pulled, and the container stays in the foreground as a runner.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="Ollama"
LABEL org.opencontainers.image.description="Ollama server that pulls a model then serves it, for Swale runner tasks. Backs ollama-serve."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/ollama/README.md"
LABEL org.opencontainers.image.licenses="MIT"
