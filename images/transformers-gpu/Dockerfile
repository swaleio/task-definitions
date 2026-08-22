# Base: pytorch/pytorch:2.13.0-cuda13.0-cudnn9-runtime (pin the digest; tag kept for humans)
FROM pytorch/pytorch@sha256:db80a41f8428644cebcb3d75b0b62df334ab6c0e75785951eb25f48bfbd42407

# The Hugging Face training stack, version-pinned so the image is reproducible.
# torch/CUDA come from the base image and are not reinstalled here.
RUN pip install --no-cache-dir \
      transformers==4.57.1 \
      accelerate==1.11.0 \
      datasets==4.4.1 \
      trl==0.24.0 \
      peft==0.18.0 \
      sentencepiece==0.2.1 \
      "huggingface_hub[hf_xet]==0.36.0" \
 && useradd --create-home --uid 1000 swale

# The Hub cache stays at its default under the user's home; the image does not
# force a location.

# No ENTRYPOINT: the PyTorch base leaves it unset, so a task definition's
# exec.args are the full command line (e.g. `trl sft --config <path>` or
# `bash -lc <script>` — bash, trl, and python are all on PATH).
USER swale
WORKDIR /mnt/workspace

# Per-image OCI metadata, and the single source of truth for it. The publish
# workflow reads the title and description out of this file and feeds them to
# docker/metadata-action, because a build --label always overrides a Dockerfile
# LABEL - without that the generated repository-wide description would win.
# The description also becomes the Docker Hub short description, which the
# registry does not read from labels at all.
LABEL org.opencontainers.image.title="Transformers GPU"
LABEL org.opencontainers.image.description="PyTorch CUDA with the Hugging Face training stack for Swale GPU tasks."
LABEL org.opencontainers.image.source="https://github.com/swaleio/task-definitions"
LABEL org.opencontainers.image.documentation="https://github.com/swaleio/task-definitions/blob/main/images/transformers-gpu/README.md"
LABEL org.opencontainers.image.licenses="MIT"
