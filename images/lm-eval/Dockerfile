FROM vllm/vllm-openai:v0.34.0@sha256:20fdb089454afbb324efa4110a2c025ff7b27cc1a086e07aa580b18df8ad1ce1

# The base image ships the vLLM engine; add the EleutherAI evaluation harness,
# pinned in requirements.txt, which drives that engine as its inference backend.
# Its dependencies are not pinned, so the install is held to the versions vLLM
# ships with: left free, it upgraded huggingface_hub past what Transformers
# accepts.
COPY requirements.txt /tmp/requirements.txt
RUN python3 -c "import importlib.metadata as m; print('\n'.join(f'{n}=={m.version(n)}' for n in ('vllm', 'torch', 'transformers', 'huggingface_hub', 'tokenizers')))" > /tmp/base-constraints.txt \
 && pip install --no-cache-dir -c /tmp/base-constraints.txt -r /tmp/requirements.txt \
 && rm /tmp/requirements.txt /tmp/base-constraints.txt

# Ubuntu 24.04 bases ship a default `ubuntu` user at uid 1000; replace it with
# the non-root `swale` user the container runs as.
RUN (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

# The base image's ENTRYPOINT launches the OpenAI-compatible API server. Reset
# it to empty so a task definition's exec.args form the full command line
# (`lm_eval ...`).
# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN python3 -c "import importlib.metadata as m; print(m.version('lm_eval').split('+')[0])" > /usr/share/swale-image-version
USER swale
WORKDIR /mnt/workspace
ENTRYPOINT []

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="lm-eval"
LABEL org.opencontainers.image.description="EleutherAI lm-evaluation-harness on vLLM for Swale GPU tasks. Backs the lm-eval task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/lm-eval/README.md"
LABEL org.opencontainers.image.licenses="MIT AND Apache-2.0"
