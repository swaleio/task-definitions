# Base: python:3.13-slim (pin the digest; tag kept for humans)
FROM python@sha256:eb43ff125d8d58d7449dcba7d336c23bcac412f526d861db493b9994d8010280

RUN pip install --no-cache-dir "huggingface_hub[cli,hf_xet]" \
 && useradd --create-home --uid 1000 swale

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# The Hub cache stays at its default under the home directory, which the
# platform mounts writable and per-task. Downloaded models go wherever the
# caller's `dest` points, so nothing another task needs lives in the cache.

USER swale
WORKDIR /mnt/workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="Hugging Face CLI"
LABEL org.opencontainers.image.description="Hugging Face Hub CLI for Swale workflows. Backs the hf-download and hf-upload tasks."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/hf-cli/README.md"
LABEL org.opencontainers.image.licenses="Apache-2.0"
