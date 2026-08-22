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
 && (userdel --remove ubuntu || true) && useradd --create-home --uid 1000 swale

# The Hub cache stays at its default under the user's home; the image does not
# force a location.

# No ENTRYPOINT: the PyTorch base leaves it unset, so a task definition's
# exec.args are the full command line (e.g. `trl sft --config <path>` or
# `bash -lc <script>` — bash, trl, and python are all on PATH).
USER swale
WORKDIR /mnt/workspace
