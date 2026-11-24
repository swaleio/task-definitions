FROM axolotlai/axolotl:0.21.1-py3.12-cu130-2.13.0@sha256:ef2d9fb57a684c8f8c052b6f7e8fe3adafe9028762c5539aad670bb2deb19b0b

# The official image installs its Python with uv under /root, which is mode
# 700, and its virtualenv links there, so any user but root gets "Permission
# denied" before Axolotl starts. Opening /root to traversal lets the platform's
# non-root user reach that interpreter; nothing else under /root is readable
# that was not already. Ubuntu 24.04 bases ship a default `ubuntu` user at uid
# 1000; replace it with the non-root `swale` user the container runs as.
RUN chmod 755 /root \
 && (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN /workspace/axolotl-venv/bin/python -c "import importlib.metadata as m; print(m.version('axolotl').split('+')[0])" > /usr/share/swale-image-version

# The base starts in /workspace/axolotl, which is read-only on the platform, and
# Axolotl writes relative paths such as its prepared-dataset cache into the
# working directory. Its entrypoint, which sets up CUDA and runs the task's
# exec.args, stays as it is.
USER swale
WORKDIR /mnt/workspace

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="Axolotl"
LABEL org.opencontainers.image.description="Axolotl fine-tuning for Swale GPU tasks. Backs the axolotl-train and axolotl-merge-lora tasks."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/axolotl/README.md"
LABEL org.opencontainers.image.licenses="Apache-2.0"
