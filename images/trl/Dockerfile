FROM pytorch/pytorch:2.14.1-cuda13.0-cudnn9-runtime@sha256:3c0b174a1339193a5bcc4b37d737c9f5ca3c4782a2293d3888e4271367eddf44

# TRL with the Hugging Face training stack it drives, version-pinned in
# requirements.txt. torch/CUDA come from the base image and are not reinstalled
# here. The base marks its system Python externally managed (PEP 668), so pip
# refuses to install without this. The container is the environment here, so
# there is no separate virtualenv to protect.
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --break-system-packages -r /tmp/requirements.txt \
 && rm /tmp/requirements.txt \
 && (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

# The Hub cache stays at its default under the user's home; the image does not
# force a location.

# TRL reports every training run to huggingface.co unless this is set.
ENV HF_HUB_DISABLE_TELEMETRY=1

# No ENTRYPOINT: the PyTorch base leaves it unset, so a task definition's
# exec.args are the full command line (`trl sft --config <path>`).

# The version of the tool this image is built around. Publishing tags the image
# with it, adding -r1, -r2, ... when that version is already published.
RUN python3 -c "import importlib.metadata as m; print(m.version('trl').split('+')[0])" > /usr/share/swale-image-version
USER swale
WORKDIR /mnt/workspace

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="TRL"
LABEL org.opencontainers.image.description="Hugging Face TRL on PyTorch CUDA for Swale GPU tasks. Backs the trl-sft task."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/trl/README.md"
LABEL org.opencontainers.image.licenses="Apache-2.0"
