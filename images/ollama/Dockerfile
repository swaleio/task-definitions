FROM ollama/ollama:0.40.18@sha256:1cabd20e1762a7a8444bf4a7110b346d923cd77ab6c97c984434140638c913ec

RUN (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Bind all interfaces on the expected port regardless of base-image defaults,
# so consumer tasks can reach the API at the runner pod's address
# (${{tasks.<id>.ip-address}}:11434). The entrypoint honors this value.
ENV OLLAMA_HOST=0.0.0.0:11434

# Pulled models land under the home directory, which the platform mounts
# writable and per-task. That suits a runner exactly: the models are needed for
# the pod's lifetime and nothing outside it reads them.

# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN /bin/ollama --version 2>&1 | tail -n 1 | awk '{print $NF}' > /usr/share/swale-image-version
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
